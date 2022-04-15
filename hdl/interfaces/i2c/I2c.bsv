// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2c;

import BuildVector::*;
import Connectable::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import Strobe::*;

import I2cCoreRegs::*;

interface Pins;
    method Bit#(1) scl_o;
    method Bit#(1) scl_o_en;
    method Action scl_i(Bit#(1) val);
    method Bit#(1) sda_o;
    method Bit#(1) sda_o_en;
    method Action sda_i(Bit#(1) val);
endinterface

// Using a Vector of Maybe#(Bit#(1)) is a convenient way to not have to track
// where we are in the shift in/out of a byte, but is a little expensive...
typedef Vector#(8, Maybe#(Bit#(1))) ShiftBits;
ShiftBits reset_value = vec(tagged Valid 1, tagged Invalid, tagged Invalid, tagged Invalid,
                            tagged Invalid, tagged Invalid, tagged Invalid, tagged Invalid);
// Creating a variant fromMaybe to for use with map() on the ShiftBits type
function bit_from_maybe(b) = fromMaybe(0, b);

typedef union tagged {
    void Start;
    void Stop;
    void Ack;
    void Nack;
    Bit#(8) Write;
    void Read;
    Bit#(8) ReadData;
} Event deriving (Bits, Eq, FShow);

typedef enum {
    AwaitStart      = 0,
    TransmitStart   = 1,
    AwaitCommand    = 2,
    TransmitByte    = 3,
    ReceiveAck      = 4,
    ReceiveByte     = 5,
    TransmitStop    = 6,
    TransmitNack    = 7
} State deriving (Eq, Bits, FShow);

interface BitControl;
    interface Pins pins;
    interface Put#(Event) send;
    interface Get#(Event) receive;
    method Bool error();
    method Action clear();
endinterface

module mkBitControl #(Integer core_clk_freq, Integer i2c_scl_freq) (BitControl);
    // generate strobe to toggle scl at a desired period
    // ex: 50MHz / 100KHz / 2 = 250
    Integer scl_half_period_limit = core_clk_freq / i2c_scl_freq / 2;

    // Counts to scl_half_period_limit and then pulses
    Strobe#(8) scl_toggle_strobe    <- mkLimitStrobe(1, scl_half_period_limit, 0);

    // Counts the number of core_clk periods between the scl/sda transitions for
    // START and STOP conditions
    Strobe#(5) delay_strobe <- mkLimitStrobe(1, 20, 0);

    // Buffers for Events
    FIFO#(Event) incoming_events   <- mkFIFO1();
    FIFO#(Event) outgoing_events    <- mkFIFO1();

    Reg#(Bit#(1))   scl_out         <- mkReg(1);
    Reg#(Bit#(1))   scl_out_next    <- mkReg(1);
    PulseWire       scl_redge       <- mkPulseWire();

    Reg#(Bit#(1))   sda_out     <- mkReg(1);
    Reg#(Bit#(1))   sda_out_en  <- mkReg(1);
    Wire#(Bit#(1))  sda_in      <- mkWire();

    Reg#(State) state           <- mkReg(AwaitStart);
    Reg#(Bool) scl_active       <- mkReg(False);
    Reg#(ShiftBits) shift_bits  <- mkReg(reset_value);

    (* fire_when_enabled *)
    rule do_tick_scl_toggle(scl_active);
        scl_toggle_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_scl_toggle(scl_toggle_strobe);
        scl_out_next    <= ~scl_out;
        scl_out         <= scl_out_next;

        if (scl_out_next == 1 && scl_out == 0) begin
            scl_redge.send();
        end
    endrule

    rule do_next;
        // Poll fifo for an event. If nothing is there, the rule will not fire.
        let e = incoming_events.first;

        // Handle events given the state
        case (tuple2(state, e)) matches
            {AwaitStart, tagged Start}: begin
                state <= TransmitStart;
                incoming_events.deq();
            end

            {TransmitStart, .*}: begin
                sda_out_en  <= 1;
                sda_out     <= 0;
                scl_active  <= True;
                state       <= AwaitCommand;
            end

            {AwaitCommand, tagged Write .byte_}: begin
                shift_bits <= map(tagged Valid, unpack(byte_));
                state   <= TransmitByte;
            end

            {TransmitByte, tagged Write .byte_}: begin
                if (scl_redge) begin
                    case (head(shift_bits)) matches
                        tagged Valid .bit_: begin
                            sda_out <= bit_;
                            shift_bits <= shiftOutFrom0(tagged Invalid, shift_bits, 1);
                        end

                        tagged Invalid: begin
                            state   <= ReceiveAck;
                        end
                    endcase
                end
            end

            {ReceiveAck, tagged Write .byte_}: begin
                sda_out_en  <= 0;
                if (scl_redge) begin
                    state   <= AwaitCommand;
                    incoming_events.deq();
                    if (sda_in == 0) begin
                        outgoing_events.enq(tagged Ack);
                    end else begin
                        outgoing_events.enq(tagged Nack);
                    end
                end
            end

            {AwaitCommand, tagged Read}: begin
                sda_out_en  <= 0;
                shift_bits  <= reset_value;
                state   <= ReceiveByte;
            end

            {ReceiveByte, tagged Read}: begin
                if (scl_redge) begin
                    case (last(shift_bits)) matches
                        tagged Valid .bit_: begin
                            state   <= TransmitNack;
                            outgoing_events.enq(tagged ReadData pack(map(bit_from_maybe, shift_bits)));
                        end

                        tagged Invalid: begin
                            shift_bits <= shiftInAt0(shift_bits, tagged Valid sda_in);
                        end
                    endcase
                end
            end

            {TransmitNack, tagged Read}: begin
                sda_out_en  <= 1;
                sda_out     <= 1;
                state       <= AwaitCommand;
            end

            {AwaitCommand, tagged Stop}: begin
                if (scl_redge) begin
                    scl_active  <= False;
                    state       <= TransmitStop;
                end
            end

            {TransmitStop, tagged Stop}: begin
                sda_out_en  <= 1;
                sda_out     <= 1;
                state       <= AwaitStart;
                incoming_events.deq();
            end
        endcase
    endrule

    interface Pins pins;
        method scl_o    = scl_out;
        method scl_o_en = 1;
        method sda_o    = sda_out;
        method sda_o_en = sda_out_en;
        method sda_i    = sda_in._write;
    endinterface

    interface Put send;
        method put = incoming_events.enq;
    endinterface
    interface Get receive = toGet(outgoing_events);

endmodule

// Simulation Interface for a basic I2C peripheral
// Since Bluesim does not support tri-states/inouts, take the output_en
// from the controller and use it to gate the peripheral output
interface I2CPeripheralModel;
    method Action scl_i(Bit#(1) val);
    method Bit#(1) sda_o;
    method Action sda_i_en(Bit#(1) sda_i_en);
    method Action sda_i(Bit#(1) val);

    interface Put#(Event) send;
    interface Get#(Event) receive;
    method Action nack_next();
endinterface

module mkI2CPeripheralModel(I2CPeripheralModel);
    Reg#(Bit#(1)) sda_out       <- mkReg(0);
    Reg#(Bit#(1)) sda_in        <- mkReg(0);
    Wire#(Bit#(1)) sda_in_en    <- mkWire();
    Wire#(Bit#(1)) scl_in       <- mkWire();


    method Action scl_i(Bit#(1) val) = scl_in._write(val);
    method Action sda_i(Bit#(1) val) = sda_in._write(val);
    method Action sda_i_en(Bit#(1) val) = sda_in_en._write(val);
    method sda_o = sda_out;

endmodule

endpackage: I2c
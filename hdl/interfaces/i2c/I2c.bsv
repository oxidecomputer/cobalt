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
ShiftBits shift_bits_reset = vec(tagged Invalid, tagged Invalid, tagged Invalid, tagged Invalid,
                            tagged Invalid, tagged Invalid, tagged Invalid, tagged Invalid);
// Creating a variant fromMaybe to for use with map() on the ShiftBits type
function Bit#(1) bit_from_maybe(Maybe#(Bit#(1)) b) = fromMaybe(0, b);

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

// I2C Bit Controller
// This initial implementation is very rigid and naive, be some details:
// START condition to first rising edge of SCL is 1/2 SCL period
// SDA switches to next value at falling edge of SCL
module mkBitControl #(Integer core_clk_freq, Integer i2c_scl_freq) (BitControl);
    // generate strobe to toggle scl at a desired period
    // ex: 50MHz / 100KHz / 2 = 250
    Integer scl_half_period_limit = core_clk_freq / i2c_scl_freq / 2;

    // Counts to scl_half_period_limit and then pulses
    Strobe#(8) scl_toggle_strobe    <- mkLimitStrobe(1, scl_half_period_limit, 0);

    // Counts the number of core_clk periods between the scl/sda transitions for
    // START and STOP conditions.
    // Hardcoded to 250 (5us / 20ns), where 20ns is assuming a 50MHz clock
    // For standard speed (100KHz) the minimum setup delay is 4us
    Strobe#(8) setup_strobe <- mkLimitStrobe(1, 250, 0);

    // Buffers for Events
    FIFO#(Event) incoming_events   <- mkFIFO1();
    FIFO#(Event) outgoing_events    <- mkFIFO1();

    Reg#(Bit#(1))   scl_out         <- mkReg(1);
    Reg#(Bit#(1))   scl_out_next    <- mkReg(1);
    PulseWire       scl_redge       <- mkPulseWire();
    PulseWire       scl_fedge       <- mkPulseWire();

    Reg#(Bit#(1))   sda_out     <- mkReg(1);
    Reg#(Bit#(1))   sda_out_en  <- mkReg(1);
    Wire#(Bit#(1))  sda_in      <- mkWire();

    Reg#(State) state           <- mkReg(AwaitStart);
    Reg#(Bool) scl_active       <- mkReg(False);
    Reg#(ShiftBits) shift_bits  <- mkReg(shift_bits_reset);

    (* fire_when_enabled *)
    rule do_setup_delay(state == TransmitStart || state == TransmitStop);
        setup_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_tick_scl_toggle(scl_active);
        scl_toggle_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_scl_toggle(scl_toggle_strobe || setup_strobe);
        scl_out_next    <= ~scl_out;
        scl_out         <= scl_out_next;

        if (scl_out_next == 1 && scl_out == 0) begin
            scl_redge.send();
        end

        if (scl_out_next == 0 && scl_out == 1) begin
            scl_fedge.send();
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
                if (setup_strobe) begin
                    scl_active  <= True;
                    state       <= AwaitCommand;
                end
            end

            {AwaitCommand, tagged Write .byte_}: begin
                shift_bits <= map(tagged Valid, unpack(byte_));
                state   <= TransmitByte;
            end

            {TransmitByte, .*}: begin
                if (scl_fedge) begin
                    case (last(shift_bits)) matches
                        tagged Valid .bit_: begin
                            sda_out <= bit_;
                            shift_bits <= shiftOutFromN(tagged Invalid, shift_bits, 1);
                        end

                        tagged Invalid: begin
                            state   <= ReceiveAck;
                        end
                    endcase
                end
            end

            {ReceiveAck, .*}: begin
                if (scl_redge) begin
                    sda_out_en  <= 1;
                    state       <= AwaitCommand;
                    incoming_events.deq();

                    if (sda_in == 0) begin
                        outgoing_events.enq(tagged Ack);
                    end else begin
                        outgoing_events.enq(tagged Nack);
                    end
                end else begin
                    sda_out_en  <= 0;
                end
            end

            {AwaitCommand, tagged Read}: begin
                sda_out_en  <= 0;
                shift_bits  <= shift_bits_reset;
                state   <= ReceiveByte;
            end

            {ReceiveByte, .*}: begin
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

            {TransmitNack, .*}: begin
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

            {TransmitStop, .*}: begin
                if (setup_strobe) begin
                    sda_out_en  <= 1;
                    sda_out     <= 1;
                    state   <= AwaitStart;
                    incoming_events.deq();
                end
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
    method Action scl_i(Bit#(1) scl_i_next);
    method Bit#(1) sda_o;
    method Action sda_i_en(Bit#(1) sda_i_en);
    method Action sda_i(Bit#(1) sda_i_next);

    interface Put#(ModelEvent) send;
    interface Get#(ModelEvent) receive;
    method Action nack_next();
endinterface

typedef union tagged {
    void ReceivedStart;
    void ReceivedStop;
    void AddressMatch;
    void AddressMismatch;
    Bit#(8) TransmitData;
    Bit#(8) ReceivedData;
} ModelEvent deriving (Bits, Eq, FShow);

typedef enum {
    AwaitStart      = 0,
    ReceiveAddress  = 1,
    ReceiveByte     = 2,
    TransmitRead    = 3,
    ReceiveWrite    = 4,
    TransmitAck     = 5
} ModelState deriving (Eq, Bits, FShow);

module mkI2CPeripheralModel #(Bit#(7) i2c_address) (I2CPeripheralModel);
    // Buffers for Events
    FIFO#(ModelEvent) incoming_events    <- mkFIFO1();
    FIFO#(ModelEvent) outgoing_events    <- mkFIFO1();

    Strobe#(8) detect_stop_strobe <- mkLimitStrobe(1, 250, 0);

    Reg#(Bit#(7)) address   <- mkReg(i2c_address);

    Reg#(Bit#(1)) sda_out       <- mkReg(1);
    Reg#(Bit#(1)) sda_in        <- mkReg(0);
    Reg#(Bit#(1)) sda_in_en    <- mkReg(1);
    Reg#(Bit#(1)) scl_in       <- mkReg(0);

    Reg#(ModelState) state  <- mkReg(AwaitStart);
    PulseWire scl_redge     <- mkPulseWire();
    Reg#(ShiftBits) shift_bits  <- mkReg(shift_bits_reset);
    Reg#(Bool) do_read      <- mkReg(False);
    Reg#(Bool) do_nack      <- mkReg(False);

    (* fire_when_enabled *)
    rule do_await_start (state == AwaitStart);
        if (sda_in == 0 && scl_in == 1) begin
            state <= ReceiveAddress;
            outgoing_events.enq(tagged ReceivedStart);
        end
    endrule

    (* fire_when_enabled *)
    rule do_receive_command (state == ReceiveAddress);
        if (scl_redge) begin
            case (last(shift_bits)) matches
                tagged Invalid: begin
                    shift_bits <= shiftInAt0(shift_bits, tagged Valid sda_in);
                end
            endcase
        end
        case (last(shift_bits)) matches
            tagged Valid .bit_: begin
                shift_bits  <= shift_bits_reset;
                let bits = pack(map(bit_from_maybe, shift_bits));
                if (bits[7:1] == address) begin
                    do_read <= bit_ == 1;
                    state   <= TransmitAck;
                    outgoing_events.enq(tagged AddressMatch);
                end else begin
                    state   <= AwaitStart;
                    outgoing_events.enq(tagged AddressMismatch);
                end
            end
        endcase
    endrule

    // (* fire_when_enabled *)
    // rule do_receive_byte (state == ReceiveByte);
    //     detect_stop_strobe.send();

    //     if (scl_redge) begin
    //         case (last(shift_bits)) matches
    //             tagged Invalid: begin
    //                 shift_bits <= shiftInAt0(shift_bits, tagged Valid sda_in);
    //             end
    //         endcase
    //     end

    //     if (detect_stop_strobe) begin
    //         state <= AwaitStart;
    //         outgoing_events.enq(tagged ReceivedStop);
    //     end else begin
    //         case (last(shift_bits)) matches
    //             tagged Valid .bit_: begin
    //                 shift_bits  <= shift_bits_reset;
    //                 detect_stop_strobe._write(0);
    //                 state       <= TransmitAck;
    //                 outgoing_events.enq(tagged ReceivedData pack(map(bit_from_maybe, shift_bits)));
    //             end
    //         endcase
    //     end
    // endrule

    // (* fire_when_enabled *)
    // rule do_transmit_ack (state == TransmitAck);
    //     sda_out <= pack(do_nack);
    //     do_nack <= False;
    //     if (scl_redge) begin
    //         state   <= ReceiveByte;
    //     end
    // endrule

    method Action scl_i(Bit#(1) scl_i_next);
        scl_in._write(scl_i_next);
        if (scl_i_next == 1 && scl_in == 0) begin
            scl_redge.send();
        end
    endmethod

    method Action sda_i(Bit#(1) sda_i_next) = sda_in._write(sda_i_next);

    method Action sda_i_en(Bit#(1) sda_i_en) = sda_in_en._write(sda_i_en);

    method Bit#(1) sda_o();
        return sda_out & ~sda_in_en;
    endmethod

    method Action nack_next();
        do_nack <= True;
    endmethod

    interface Put send;
        method put = incoming_events.enq;
    endinterface
    interface Get receive = toGet(outgoing_events);

endmodule

endpackage: I2c
// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package UART;

export Serializer(..), mkSerializer;
export Deserializer(..), mkDeserializer;
export Serial(..);
export SamplingTransceiver(..), mkSamplingTransceiver;

import Assert::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import BitSampling::*;
import Strobe::*;
import TestUtils::*;


interface Deserializer;
    interface Put#(Bit#(1)) in;
    interface Get#(Bit#(8)) out;
    method Bool waiting_for_start();
    method Bool error();
endinterface

interface Serializer;
    interface Put#(Bit#(8)) in;
    interface Get#(Bit#(1)) out;
endinterface

interface Serial;
    (* prefix = "" *)
    method Action rx((* port = "rx" *) Bit#(1) val);
    method Bit#(1) tx;
endinterface

typedef enum {
    Idle = 0,
    Start,
    Bit0,
    Bit1,
    Bit2,
    Bit3,
    Bit4,
    Bit5,
    Bit6,
    Bit7,
    Stop
} State deriving (Bits, Eq, FShow);

function State next_state(State s) = s == Stop ? Idle : unpack(pack(s) + 1);

module mkSerializer (Serializer);
    Reg#(State) state <- mkRegA(Idle);

    Reg#(Maybe#(Bit#(8))) i <- mkRegA(tagged Invalid);
    RWire#(Bit#(8)) i_next <- mkRWire();

    PulseWire shift_out_bit <- mkPulseWire();
    Reg#(Bit#(1)) o <- mkRegA(1);

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_serialize;
        let i_ = isValid(i_next.wget()) ? i_next.wget() : i;

        if (shift_out_bit) begin
            // Split (remainder of) input byte.
            let head = lsb(fromMaybe(?, i_));
            let tail = bitconcat(0, fromMaybe(?, i_)[7:1]);

            // Possible next states.
            let start_or_idle = isValid(i_) ?
                  tuple3(Start, i_, 0)
                : tuple3(Idle, tagged Invalid, 1);
            let stop = tuple3(Stop, tagged Invalid, 1);
            let dissipate_bit = tuple3(next_state(state), tagged Valid (tail), head);

            // Select and commit next state.
            match {.state_next, .i_next, .o_next} =
                case (state)
                    Idle: start_or_idle;
                    Bit7: stop;
                    Stop: start_or_idle;
                    default: dissipate_bit;
                endcase;

            state <= state_next;
            i <= i_next;
            o <= o_next;
        end else begin
            i <= i_;
        end
    endrule

    interface Get out;
        method ActionValue#(Bit#(1)) get();
            shift_out_bit.send();
            return o;
        endmethod
    endinterface

    interface Put in;
        method put if (!isValid(i)) = i_next.wset;
    endinterface

endmodule : mkSerializer

(* synthesize *)
module mkSerializerTest (Empty);
    Serializer ser <- mkSerializer();

    mkAutoFSM(seq
        assert_get(ser.out, 1, "expected idle bit");
        assert_get(ser.out, 1, "expected idle bit");
        action
            ser.in.put('h7f);
            assert_get(ser.out, 1, "expected idle bit");
        endaction
        assert_get(ser.out, 0, "expected start bit");
        repeat(7) assert_get(ser.out, 1, "expected high bit");
        assert_get(ser.out, 0, "expected low msb");
        assert_get(ser.out, 1, "expected stop bit");
        assert_get(ser.out, 1, "expected idle bit");
    endseq);

    mkTestWatchdog(15);
endmodule

module mkDeserializer (Deserializer);
    Reg#(State) state <- mkRegA(Idle);

    RWire#(Bit#(1)) i_next <- mkRWire();

    PulseWire deq <- mkPulseWire();
    Reg#(Maybe#(Bit#(8))) o <- mkRegA(tagged Invalid);

    PulseWire error_ <- mkPulseWire();

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_deserialize;
        let o_ = deq ? tagged Invalid : o;

        if (i_next.wget() matches tagged Valid .b) begin
            // Possible next states.
            let idle = tuple2(Idle, o_);
            let start = tuple2(Start, tagged Valid 0);
            let stop = tuple2(Stop, o_);
            let error = tuple2(Idle, tagged Invalid);
            let accumulate_bit =
                tuple2(
                    next_state(state),
                    tagged Valid bitconcat(b, fromMaybe(?, o_)[7:1]));

            // Select and commit next state based on incoming bit.
            match {.state_next, .o_next} =
                case (tuple2(state, b)) matches
                    {Idle, 0}: start;
                    {Idle, 1}: idle;
                    {Bit7, 0}: error;
                    {Bit7, 1}: stop;
                    {Stop, 0}: start;
                    {Stop, 1}: idle;
                    default: accumulate_bit;
                endcase;

            state <= state_next;
            o <= o_next;

            // Inform upstream if an error occured.
            if (state == Bit7 && b == 0) begin
                error_.send();
            end
        end else begin
            o <= o_;
        end
    endrule

    interface Put in = toPut(i_next);
    interface Get out;
        method ActionValue#(Bit#(8)) get() if (isValid(o) && (state == Stop || state == Idle));
            deq.send();
            return fromMaybe(?, o);
        endmethod
    endinterface

    method error = error_._read;
    method waiting_for_start = (state == Idle || state == Stop);
endmodule : mkDeserializer

(* synthesize *)
module mkSerDesTest (Empty);
    // 10 bit cycles + 2 cycles to latch input/ouput bytes + 1 cycle to assert output.
    mkTestWatchdog(10 + 2 + 1);

    Serializer ser <- mkSerializer();
    Deserializer des <- mkDeserializer();

    mkConnection(ser, des);

    mkAutoFSM(seq
        ser.in.put(8'h55);
        assert_get(des.out, 8'h55, "expected 'h55");
    endseq);
endmodule

interface SamplingTransceiver #(numeric type bit_period);
    interface Serial serial;
    interface Put#(Bit#(8)) send;
    interface Get#(Bit#(8)) receive;
    method Bool receive_error();
    method Bool tx_strobe();
endinterface

module mkSamplingTransceiver
        #(Strobe#(any_sz) sample_strobe)
        (SamplingTransceiver#(bit_period))
        provisos (
            Add#(__a, 1, bit_period),         // bit_period > 0.
            Log#(bit_period, bit_period_sz)); // Make bit_period a power of two
    staticAssert(
        2 ** valueof(bit_period_sz) == valueof(bit_period),
        "bit_period should be a power of two");
    staticAssert(valueof(bit_period) > 1, "bit_period should be at least two clock cycles");

    Serializer ser <- mkSerializer();
    Strobe#(bit_period_sz) tx_strobe_ <- mkStrobe(1, 0);

    Deserializer des <- mkDeserializer();
    Strobe#(bit_period_sz) rx_strobe <- mkStrobe(1, 0);
    AsyncBitSampler#(bit_period) rx_sampler <- mkAsyncBitSampler(rx_strobe, NegativePolarity);

    mkConnection(rx_sampler, des);

    (* fire_when_enabled *)
    rule do_tick (sample_strobe);
        rx_strobe.send();
        tx_strobe_.send();
    endrule

    (* fire_when_enabled *)
    rule do_get_next_tx_bit (tx_strobe_);
        let b <- ser.out.get();
    endrule

    interface Serial serial;
        method rx = rx_sampler.in.put;
        method tx = peekGet(ser.out);
    endinterface

    interface Put send = ser.in;
    interface Get receive = des.out;

    method receive_error = des.error;
    method tx_strobe = tx_strobe_._read;
endmodule

// Make Serializer/Deserializer connectable, because we can.
instance Connectable#(Serializer, Deserializer);
    module mkConnection#(Serializer ser, Deserializer des) (Empty);
        mkConnection(ser.out, des.in);
    endmodule
endinstance

instance Connectable#(AsyncBitSampler#(bit_period), Deserializer);
    module mkConnection#(AsyncBitSampler#(bit_period) sampler, Deserializer des) (Empty);
        mkConnection(sampler.out, des.in);

        (* no_implicit_conditions, fire_when_enabled *)
        rule do_search_for_start_bit;
            if (des.waiting_for_start()) begin
                sampler.search_for_bit_edge();
            end
        endrule
    endmodule
endinstance

endpackage : UART

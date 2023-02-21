// Copyright 2023 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Debouncer;

export Debouncer(..);
export mkDebouncer;

// BSV Library
import Connectable::*;
import StmtFSM::*;

// Cobalt
import TestUtils::*;

//
// `Debouncer(..)` is meant to stabilize a potentially "bouncy" input signal.
// `_write` to it with bouncy input and the signal `_read` out will only change
// if the input has been stable for `assertion_duration` number of calls to the
// `send` method upon input assertion and `deassertion_duration` for input
// deassertion. Assertion is defined as input being not equal to the
// `reset_value` supplied at module instantiation. The intention is for `send`
// to be wired up to a regular pulse (such as every microsend or millisecond).
// Either assertion or deassertion duration can be set to zero to get a fast
// transition, but not both.
//
// It is worth noting that a single cycle where the input signal changes will
// reset the debouncing counter, making this not an ideal block for signals that
// may experience any spurious noise. The `SchmittReg` package is a configurable
// filter that may be a better choice in that case, perhaps used on its own or
// as an input glitch filter to this block.
//
interface Debouncer#(
        numeric type assert_duration,
        numeric type deassert_duration,
        type one_bit_type);
    method one_bit_type _read();
    method Action _write(one_bit_type val);
    method Action send();
endinterface

module mkDebouncer#(
            one_bit_type reset_value
        ) (
            Debouncer#(assert_duration, deassert_duration, one_bit_type)
        ) provisos (
            Bits#(one_bit_type, 1),
            Eq#(one_bit_type)
        );

    Wire#(one_bit_type) input_raw <- mkWire();
    Reg#(one_bit_type) input_last <- mkReg(reset_value);
    Reg#(one_bit_type) output_r <- mkReg(reset_value);

    Reg#(Bool) assertion_edge <- mkReg(False);
    Reg#(Bool) deassertion_edge <- mkReg(False);

    Reg#(UInt#(TLog#(TMax#(assert_duration, deassert_duration)))) counter
        <- mkReg(0);
    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_register_input;
        input_last <= input_raw;
    endrule

    (* fire_when_enabled *)
    rule do_edge_type;
        assertion_edge <= input_raw != reset_value;
        deassertion_edge <= input_raw == reset_value;
    endrule

    (* fire_when_enabled *)
    rule do_debounce;
        if (input_raw != input_last) begin
            counter <= 0;
        end else if ((assertion_edge &&
                    counter == fromInteger(valueOf(assert_duration))) ||
                    (deassertion_edge &&
                    counter == fromInteger(valueOf(deassert_duration)))) begin
            output_r <= input_last;
            counter <= 0;
        end else if (tick) begin
            counter <= counter + 1;
        end
    endrule

    method _read = output_r;
    method _write = input_raw._write;
    method send = tick.send();
endmodule

// Implementing connecting a PulseWire to a Debouncer as a convenience.
instance Connectable#(PulseWire, Debouncer#(assert_duration,
                                            deassert_duration,
                                            one_bit_type));
    module mkConnection#(PulseWire w,
                        Debouncer#(assert_duration,
                                    deassert_duration,
                                    one_bit_type) debouncer)
                        (Empty);
        (* fire_when_enabled *)
        rule do_send (w);
            debouncer.send();
        endrule
    endmodule
endinstance

// mkDebouncerTest
//
// This is a basic test suite which validates that the output does not follow
// the instability of the input.
module mkDebouncerTest (Empty);
    Reg#(Bit#(1)) in <- mkReg(0);
    Debouncer#(5, 2, Bit#(1)) dut <- mkDebouncer(0);

    mkConnection(dut._write, in._read);

    mkAutoFSM(seq
        assert_eq(dut, 0, "Output should match reset value at t=0");

        // start a transition
        in <= 1;
        repeat(4) action
            assert_not_set(dut,
                "Output should not be set until debounce duration has elapsed");
            dut.send();
        endaction

        // bounce input, resetting debounce counter
        in <= 0; 
        repeat(10) action
            assert_not_set(dut,
                "Output should not be set because input is not set.");
            dut.send();
        endaction

        // transition for real this time
        in <= 1;
        // Repeat 7 clocks: 1 for input edge detection, 5 for debounce duration,
        // and a final one since the output is registered.
        repeat(7) action
            assert_not_set(dut,
                "Output should not be set until debounce duration has elapsed");
            dut.send();
        endaction
        assert_set(dut,
            "Output should be set after debounce duration has elapsed");

        // debounce the reverse transition
        in <= 0;
        // Repeat 4 clocks: 1 for input edge detection, 2 for debounce duration,
        // and a final one since the output is registered.
        repeat(4) action
            assert_set(dut,
                "Output should be set until debounce duration has elapsed");
            dut.send();
        endaction
        assert_not_set(dut,
            "Output should not be set after debounce duration has elapsed");
    endseq);
endmodule

// mkDebounceFastAssertTest
//
// This test makes sure that as soon as the input asserts that the Debouncer
// also asserts the output.
module mkDebounceFastAssertTest (Empty);
    Reg#(Bit#(1)) in <- mkReg(0);
    Debouncer#(0, 5, Bit#(1)) dut <- mkDebouncer(0);

    mkConnection(dut._write, in._read);

    mkAutoFSM(seq
        assert_eq(dut, 0, "Output should match reset value at t=0");

        // fast transition on the assertion
        in <= 1;
        assert_not_set(dut,
            "Output should not be set while counter is cleared.");
        assert_not_set(dut,
            "Output should not be set while output register is set.");
        assert_set(dut,
            "Output should be set even without calling send");

        in <= 0;
        // Repeat 7 clocks: 1 for input edge detection, 5 for debounce duration,
        // and a final one since the output is registered.
        repeat(7) action
            assert_set(dut,
                "Output should be set until debounce duration has elapsed");
            dut.send();
        endaction
        assert_not_set(dut,
            "Output should not be set after debounce duration has elapsed");
    endseq);
endmodule

// mkDebounceFastDeassertTest
//
// This test makes sure that as soon as the input deasserts that the Debouncer
// also deasserts the output.
module mkDebounceFastDeassertTest (Empty);
    Reg#(Bit#(1)) in <- mkReg(0);
    Debouncer#(5, 0, Bit#(1)) dut <- mkDebouncer(0);

    mkConnection(dut._write, in._read);

    mkAutoFSM(seq
        assert_eq(dut, 0, "Output should match reset value at t=0");

        // start a transition
        in <= 1;
        // Repeat 7 clocks: 1 for input edge detection, 5 for debounce duration,
        // and a final one since the output is registered.
        repeat(7) action
            assert_not_set(dut,
                "Output should not be set until debounce duration has elapsed");
            dut.send();
        endaction
        assert_set(dut,
            "Output should be set after debounce duration has elapsed");

        // fast transition on the deassertion
        in <= 0;
        assert_set(dut,
            "Output should be set for a cycle while counter is reset");
        assert_set(dut,
            "Output should be set for a cycle output register is cleared");
        assert_not_set(dut,
            "Output should very quickly not be set even without calling send");
    endseq);
endmodule

endpackage

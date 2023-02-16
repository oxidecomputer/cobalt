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
// if the input has been stable for `duration` number of calls to the `send`
// method. The intention is for `send` to be wired up to a regular pulse (such
// as every microsend or millisecond).
//
interface Debouncer #(numeric type duration);
    method Bit#(1) _read();
    method Action _write(Bit#(1) val);
    method Action send();
endinterface

module mkDebouncer#(Bit#(1) reset_value) (Debouncer#(duration));
    Wire#(Bit#(1)) input_raw <- mkWire();
    Reg#(Bit#(1)) input_last <- mkReg(reset_value);
    Reg#(Bit#(1)) output_r <- mkReg(reset_value);

    Reg#(UInt#(TLog#(duration))) counter <- mkReg(0);
    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_register_input;
        input_last <= input_raw;
    endrule

    (* fire_when_enabled *)
    rule do_debounce;
        if (input_raw != input_last) begin
            counter <= 0;
        end else if (counter == fromInteger(valueOf(duration))) begin
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
instance Connectable#(PulseWire, Debouncer#(duration));
    module mkConnection#(PulseWire w, Debouncer#(duration) debouncer) (Empty);
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
    Debouncer#(5) dut <- mkDebouncer(0);

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
        repeat(7) action
            assert_set(dut,
                "Output should be set until debounce duration has elapsed");
            dut.send();
        endaction
        assert_not_set(dut,
            "Output should not be set after debounce duration has elapsed");
    endseq);
endmodule

endpackage

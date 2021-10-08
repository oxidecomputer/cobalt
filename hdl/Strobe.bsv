// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Strobe;

export Strobe(..);
export mkStrobe, mkFractionalStrobe;

import Assert::*;
import Connectable::*;
import StmtFSM::*;


//
// Strobe(..) is an interface loosly mimicking PulseWire(..) but for periodic pulses. It is intended
// to be implemented by modules which generate divided versions of the clock driving it, useful for
// example for sampling incoming data from external interfaces. Note that the _write(..) function
// allows for strobes which are not periodic at all.
//
interface Strobe#(numeric type sz);
    method Bool _read();
    method Action _write(UInt#(sz) val);
    method Action send();
    (* always_enabled *)
    method Integer step();
endinterface

//
// mkStrobe returns an integer divided strobe of the clock driving it.
//
module mkStrobe #(Integer step_, UInt#(sz) init) (Strobe#(sz))
        provisos (Add#(sz, 1, sz_overflow));
    Reg#(UInt#(sz)) count <- mkRegA(init);
    Reg#(Bool) q <- mkRegA(False);

    RWire#(UInt#(sz)) count_next <- mkRWire();
    Wire#(Bool) q_next <- mkDWire(False);
    PulseWire tick <- mkPulseWire();

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set_count (count_next.wget matches tagged Valid .value);
        count <= value;
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick (tick && !isValid(count_next.wget()));
        UInt#(sz_overflow) sum = extend(count) + fromInteger(step_);

        count <= truncate(sum);
        q_next <= unpack(msb(sum));
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_pulse;
        q <= q_next;
    endrule

    method _read = q._read;
    method _write = count_next.wset;
    method send = tick.send;
    method step = step_;
endmodule: mkStrobe

//
// mkFractionalStrobe implements a fractional divided strobe. The jitter of this strobe is
// determined by the number of bits used to represent the fraction, but a larger number of bits
// means a longer carry chain for the counter.
//
module mkFractionalStrobe #(Integer fraction, UInt#(sz) init) (Strobe#(sz));
    let step = fraction < 1 ? error("fraction < 1") : 2 ** valueof(sz) / fraction;
    let _s <- mkStrobe(step, init);
    return _s;
endmodule

// Allow one strobe to divide another.
instance Connectable#(Strobe#(a), Strobe#(b));
    module mkConnection #(Strobe#(a) s1, Strobe#(b) s2) (Empty);
        (* fire_when_enabled *)
        rule do_tick (s1);
            s2.send();
        endrule
    endmodule
endinstance

(* synthesize *)
module mkFractionalStrobeTest (Empty);
    Strobe#(16) s <- mkFractionalStrobe(1000 / 96, 0); // expect a pulse every ~11th cycle.

    mkAutoFSM(seq
        repeat(11) action
            s.send();
            dynamicAssert(!s, "did not expect pulse");
        endaction
        dynamicAssert(s, "expected pulse");
        $display("Done");
    endseq);
endmodule

endpackage: Strobe

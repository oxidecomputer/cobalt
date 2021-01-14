// Copyright 2020 Oxide Computer Company
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


interface Strobe#(numeric type sz);
    method Bool _read();
    method Action _write(UInt#(sz) val);
    method Action send();
    method Integer step();
endinterface : Strobe

module mkStrobe #(Integer step_, UInt#(sz) init) (Strobe#(sz))
        provisos (Add#(sz, 1, sz_overflow));
    Reg#(UInt#(sz)) count <- mkRegA(init);
    Reg#(Bool) _pulse <- mkRegA(False);

    RWire#(UInt#(sz)) set <- mkRWire();
    Wire#(Bool) pulse_next <- mkDWire(False);
    PulseWire tick <- mkPulseWire();

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set (set.wget matches tagged Valid .value);
        count <= value;
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick (tick && !isValid(set.wget()));
        UInt#(sz_overflow) sum = extend(count) + fromInteger(step_);

        count <= truncate(sum);
        pulse_next <= unpack(msb(sum));
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_pulse;
        _pulse <= pulse_next;
    endrule

    method _read = _pulse._read;
    method _write = set.wset;
    method send = tick.send;
    method step = step_;
endmodule : mkStrobe

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
    Strobe#(16) s <- mkFractionalStrobe(100_000 / 9600, 0);

    mkAutoFSM(seq
        repeat(11) action
            s.send();
            dynamicAssert(!s, "did not expect pulse");
        endaction
        dynamicAssert(s, "expected pulse");
        $finish;
    endseq);
endmodule

endpackage : Strobe

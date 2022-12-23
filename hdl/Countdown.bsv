// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Countdown;

import Assert::*;
import Connectable::*;
import DReg::*;
import StmtFSM::*;

//
// `Countdown(..)` mimics and is a complement to `Strobe(..)`, counting down
// from a set value and pulsing for one cycle once the count hits zero. It is
// intended to be use to implement delays, generate timeout events, etc.
//
interface Countdown #(numeric type sz);
    method Bool _read();
    method Action _write(UInt#(sz) val);
    method UInt#(sz) count();
    method Action send();
endinterface

module mkCountdown #(Integer step) (Countdown#(sz));
    Reg#(UInt#(sz)) count_r <- mkRegU();
    RWire#(UInt#(sz)) count_next <- mkRWire();

    Reg#(Bool) q <- mkDReg(False);
    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_set_count (count_next.wget matches tagged Valid .value);
        count_r <= value;
    endrule

    (* fire_when_enabled *)
    rule do_tick (tick && !isValid(count_next.wget));
        count_r <= satMinus(Sat_Zero, count_r, fromInteger(step));
        q <= (count_r == 1);
    endrule

    method _read = q;
    method _write = count_next.wset;
    method count = count_r;
    method send = tick.send;
endmodule

module mkCountdownBy1 (Countdown#(sz));
    (* hide *) Countdown#(sz) _c <- mkCountdown(1);
    return _c;
endmodule

instance Connectable#(PulseWire, Countdown#(sz));
    module mkConnection #(PulseWire w, Countdown#(sz) countdown) (Empty);
        (* fire_when_enabled *)
        rule do_tick (w);
            countdown.send();
        endrule
    endmodule
endinstance

module mkCountdownTest (Empty);
    Countdown#(2) c <- mkCountdownBy1();

    mkAutoFSM(seq
        c <= unpack('1);

        // Expect no strobe during countdown.
        repeat(3) action
            dynamicAssert(!c, "Expected no strobe");
            c.send();
        endaction

        // Expect strobe once zero.
        action
            dynamicAssert(c.count == 0, "Expected count == 0");
            dynamicAssert(c, "Expected strobe");
        endaction
        dynamicAssert(!c, "Expected pulse to last for one cycle");

        // Expect tick to be no-op once zero.
        repeat(3) action
            dynamicAssert(c.count == 0, "Expected count to remain 0");
            dynamicAssert(!c, "Expected no strobe once count 0");
            c.send();
        endaction
    endseq);
endmodule

endpackage

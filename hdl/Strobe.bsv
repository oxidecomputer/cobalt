// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Strobe;

export Strobe(..);
export mkPowerTwoStrobe;
export mkFractionalStrobe;
export mkLimitStrobe;
export mkFreeRunningStrobe, asPulseWire;

export TickFunc, mkStrobeWithTickFunc;

import Assert::*;
import Connectable::*;
import StmtFSM::*;


//
// `Strobe(..)` is an interface loosly mimicking `PulseWire(..)` but for
// periodic pulses. It is intended to be implemented by modules which generate
// divided versions of the clock driving it, useful for example for sampling
// incoming data from external interfaces. Do note that the `_write(..)`
// function allows for strobes which are not periodic at all.
//
interface Strobe#(numeric type sz);
    method Bool _read();
    method Action _write(UInt#(sz) val);
    method Action send();
    (* always_enabled *) method Integer step();
endinterface

//
// Typedef for a function handling a tick event, which occurs whenever
// `Strobe.send()` is called. The function is then free to update a counter and
// determine whether or not a strobe event is to occur.
//
typedef (function Action f(Reg#(UInt#(sz)) count, Reg#(Bool) q))
    TickFunc#(type sz);

//
// `mkStrobeWithTickFunc` is a template module providing the skeleton of a
// Strobe(..) but can be instantiated with a custom tick handler. This module is
// the basis for the remaining `Strobe(..)` implementations in this module.
//
module mkStrobeWithTickFunc #(Integer step_, UInt#(sz) init, TickFunc#(sz) f) (Strobe#(sz))
        provisos (Add#(sz, 1, sz_overflow));
    Reg#(UInt#(sz)) count <- mkRegA(init);
    Reg#(Bool) q <- mkRegA(False);

    RWire#(UInt#(sz)) count_next <- mkRWire();
    Wire#(Bool) q_next <- mkDWire(False);
    PulseWire tick <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_set_count (count_next.wget matches tagged Valid .value);
        count <= value;
    endrule

    (* fire_when_enabled *)
    rule do_tick (tick && !isValid(count_next.wget()));
        f(count, q_next);
    endrule

    (* fire_when_enabled *)
    rule do_pulse;
        q <= q_next;
    endrule

    method _read = q._read;
    method _write = count_next.wset;
    method send = tick.send;
    method step = step_;
endmodule: mkStrobeWithTickFunc

//
// `mkPowerTwoStrobe` returns a power of two divided strobe of the clock driving
// it, by generating a pulse any time the underlying counter rolls over. If
// these properties fit the usecase it is the most likely the most efficient
// implementation of `Strobe(..)` as it does not contain any comparisons, only
// an addition carry chain.
//
// Note that this module can also be used as a count down counter by priming it
// using the `_write(..)` function to a suitable value and calling `send()`
// until the strobe occurs. Taken further this even allows for a periodic strobe
// without a comparison if the caller is able to call `_write(..)` again
// whenever a strobe event occurs.
//
module mkPowerTwoStrobe #(Integer step_, UInt#(sz) init) (Strobe#(sz))
        provisos (Add#(sz, 1, sz_overflow));
    if (step_ == 0) error("step is 0, Strobe would never generate a pulse");

    function Action do_tick(Reg#(UInt#(sz)) count, Reg#(Bool) q) =
        action
            UInt#(sz_overflow) sum = extend(count) + fromInteger(step_);

            count <= truncate(sum);
            q <= unpack(msb(sum));
        endaction;

    (* hide *) let _s <- mkStrobeWithTickFunc(step_, init, do_tick);
    return _s;
endmodule

//
// `mkFractionalStrobe` implements a fractional divided strobe. This
// `Strobe(..)` allows greater flexibility when subdividing a clock, allowing
// more or less arbitrary divisions while maintaining a bounded carry-chain and
// without the use of comparisons, but at the expense of some amount of jitter.
//
// The jitter of this strobe is determined by the number of bits used to
// represent the fraction, with more bits resulting in less jitter, but
// resulting in a longer carry-chain for the internal counter.
//
module mkFractionalStrobe #(Integer fraction, UInt#(sz) init) (Strobe#(sz));
    let step = fraction < 1 ? error("fraction < 1") : 2 ** valueof(sz) / fraction;
    if (step == 0) error("step is 0, Strobe would never generate a pulse");

    (* hide *) let _s <- mkPowerTwoStrobe(step, init);
    return _s;
endmodule

//
// mkLimitStrobe implements a precise strobe by couting up or down to the given
// limit using the given step amount. The lack of jitter of this `Strobe(..)`
// compared to `mkFractionalStrobe` for odd values comes at an increase in logic
// required to explicitly compare against the given limit.
//
// See the descriptino of `mkPowerTwoStrobe` if no jitter or comparisions are
// desired.
//
module mkLimitStrobe #(Integer step_, Integer limit, UInt#(sz) init) (Strobe#(sz));
    if (step_ == 0) error("step is 0, Strobe would never generate a pulse");
    if (limit > 2 ** valueof(sz)) error("limit exceeds Strobe bit width");

    function Action do_tick(Reg#(UInt#(sz)) count, Reg#(Bool) q) =
        action
            let sum = count + fromInteger(step_);
            let limit_reached = (count >= fromInteger(limit - 1));

            q <= limit_reached;
            count <= (limit_reached ? 0 : sum);
        endaction;

    (* hide *) let _s <- mkStrobeWithTickFunc(step_, init, do_tick);
    return _s;
endmodule

//
// Make the given strobe freerunning by calling `send()` on each clock tick.
//
module mkFreeRunningStrobe #(Strobe#(sz) s) (Empty);
    (* fire_when_enabled *)
    rule do_tick_strobe;
        s.send();
    endrule
endmodule

//
// The `_write(..)` function of `Strobe(..)` requires the width of the
// underlying counter, to be exposed in the interface. Many `Strobe(..)`
// consumers however do not need this specific type information and require only
// something shaped like a `PulseWire(..)`.
//
// `asPulseWire(..)` allows converting a given `Strobe(..)` as `PulseWire` which
// can then be passed into a module hierarchy which does not need to know the
// specific implementation of the `Strobe(..)`.
//
function PulseWire asPulseWire(Strobe#(sz) s);
    return interface PulseWire;
        method _read = s._read;
        method send = s.send;
    endinterface;
endfunction

// Allow one strobe to divide another.
instance Connectable#(Strobe#(a), Strobe#(b));
    module mkConnection #(Strobe#(a) s1, Strobe#(b) s2) (Empty);
        (* fire_when_enabled *)
        rule do_tick (s1);
            s2.send();
        endrule
    endmodule
endinstance

// Make Strobes and PulseWires connectable.
instance Connectable#(Strobe#(a), PulseWire);
    module mkConnection #(Strobe#(a) s, PulseWire w) (Empty);
        (* fire_when_enabled *)
        rule do_tick (s);
            w.send();
        endrule
    endmodule
endinstance

instance Connectable#(PulseWire, Strobe#(a));
    module mkConnection #(PulseWire w, Strobe#(a) s) (Empty);
        (* fire_when_enabled *)
        rule do_tick (w);
            s.send();
        endrule
    endmodule
endinstance

// Make Strobes and Actions connectable.
instance Connectable#(Strobe#(a), Action);
    module mkConnection #(Strobe#(a) s, Action a) (Empty);
        (* fire_when_enabled *)
        rule do_a (s);
            a();
        endrule
    endmodule
endinstance

// Make Strobes and ActionValues connectable. Note that this does silently
// discard the returned value.
instance Connectable#(Strobe#(a), ActionValue#(b));
    module mkConnection #(Strobe#(a) s, ActionValue#(b) av) (Empty);
        (* fire_when_enabled *)
        rule do_av (s);
            let _ <- av();
        endrule
    endmodule
endinstance

// Make ActionValues and Strobes connectable. This is mostly here for
// completeness, but could for example be used to feed Bools through a `Get`
// interface which are then used to determine when to tick the strobe.
instance Connectable#(ActionValue#(Bool), Strobe#(a));
    module mkConnection #(ActionValue#(Bool) av, Strobe#(a) s) (Empty);
        (* fire_when_enabled *)
        rule do_tick;
            let tick <- av();
            if (tick) s.send();
        endrule
    endmodule
endinstance

function Action tick_while_assert(
        Strobe#(sz) s,
        Bool pulse_expected,
        String msg) =
    action
        s.send();
        dynamicAssert(s == pulse_expected, msg);
    endaction;

module mkPowerTwoStrobeTest (Empty);
    // Expect a pulse 4th time `send()` is called.
    Strobe#(2) s <- mkPowerTwoStrobe(1, 0);

    mkAutoFSM(seq
        // Tick once..
        tick_while_assert(asIfc(s), False, "no pulse expected on start");
        repeat(3) seq
            // Assert three more times no pulse while ticking..
            repeat(3) tick_while_assert(asIfc(s), False, "no pulse expected");
            // The previous tick will have caused a pulse
            dynamicAssert(s, "pulse expected");
            tick_while_assert(asIfc(s), False, "no pulse expected");
        endseq
    endseq);
endmodule

module mkPowerTwoStrobeAsCountDownTest (Empty);
    // Expect a pulse after two ticks.
    Strobe#(2) s <- mkPowerTwoStrobe(1, 0);

    mkAutoFSM(seq
        s <= 2;
        tick_while_assert(asIfc(s), False, "no pulse expected");
        tick_while_assert(asIfc(s), False, "no pulse expected");
        dynamicAssert(s, "pulse expected");
    endseq);
endmodule

module mkFractionalStrobeTest (Empty);
    // Expect a pulse every ~10th tick, with an occasional 11th tick.
    Strobe#(16) s <- mkFractionalStrobe(1000 / 96, 0);

    mkAutoFSM(seq
        tick_while_assert(asIfc(s), False, "no pulse expected");

        // Assert ten more times no pulse while ticking. As demonstrated this
        // pulse requires 11 ticks because of introduced jitter.
        repeat(10) tick_while_assert(asIfc(s), False, "no pulse expected");
        dynamicAssert(s, "pulse expected");
        tick_while_assert(asIfc(s), False, "no pulse expected");

        // The next pulse arrives in the expected 10 ticks.
        repeat(9) tick_while_assert(asIfc(s), False, "no pulse expected");
        dynamicAssert(s, "pulse expected");
        tick_while_assert(asIfc(s), False, "no pulse expected");

        // The third pulse again requires 10 ticks.
        repeat(9) tick_while_assert(asIfc(s), False, "no pulse expected");
        dynamicAssert(s, "pulse expected");
        tick_while_assert(asIfc(s), False, "no pulse expected");
    endseq);
endmodule

module mkLimitStrobeStrobeTest (Empty);
    // Expect a pulse 3rd time `send()` is called.
    Strobe#(2) s <- mkLimitStrobe(1, 3, 0);

    mkAutoFSM(seq
        // Tick once..
        tick_while_assert(asIfc(s), False, "no pulse expected on start");
        repeat(3) seq
            // Assert three more times no pulse while ticking..
            repeat(2) tick_while_assert(asIfc(s), False, "no pulse expected");
            // The previous tick will have caused a pulse.
            dynamicAssert(s, "pulse expected");
            tick_while_assert(asIfc(s), False, "no pulse expected");
        endseq
    endseq);
endmodule

endpackage: Strobe

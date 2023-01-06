// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.

package IOSync;

export InputReg(..);
export mkInputSync;
export mkInputSyncFor;
export mkOutputSyncFor;
export mkOutputRegSyncFor;
export mkOutputWithEnableSyncFor;
export mkOutputRegWithEnableSyncFor;
export mkBidirectionRegSyncFor;
export sync;
export sync_inverted;

import Clocks::*;
import ConfigReg::*;
import Connectable::*;
import TriState::*;
import Vector::*;

import Bidirection::*;
import WriteOnlyTriState::*;


//
// `InputReg(..)` represents an input synchonizer with a configurable number of
// chained synchronizer flip flops.
//
// Note that there are no significant restrictions on the type it can hold but
// the primitives in this package only aim to guard against metastability of
// individual bits and do not provide synchronization across bits for types with
// a bit size larger than one.
//
interface InputReg#(type t, numeric type n);
    method t _read();
    method Action _write(t val);
endinterface

//
// `mkInputSync` is a synchronizer for asynchronous input signals with a
// configurable number of flops. By design it has no reset value, allowing the
// output to be used in clock or reset domains other than the default clock or
// reset, without explicit domain crossing. Downstream logic is expected to
// discard the first few undetermined values when reading from the synchronizer
// or be kept in reset the given number of synchronization cycles.
//
// This primitive is intended for generic input signals only. For high
// performance interfaces such as DDR memories or SerDes I/O you will most
// likely need more specific primitives. For other instances of clock or reset
// domain crossing more appropriate primitives should be used.
//
module mkInputSync (InputReg#(bits_type, sync_cycles))
        provisos (Bits#(bits_type, sz));
    (* hide *) ConfigReg#(Vector#(sync_cycles, bits_type))
        _sync <- mkConfigRegU();

    method _read = _sync[0];
    method Action _write(bits_type val);
        _sync <= shiftInAtN(_sync, val);
    endmethod
endmodule

//
// `mkInputSyncFor` is syntactic sugar for `mkInputSync`, connecting the
// `_read()` method to the given action method. This allows the synchronized
// input to be forwarded to downstream modules in a single statement, shortening
// this common usecase in top modules.
//
module mkInputSyncFor #(function Action f(bits_type val))
        (InputReg#(bits_type, sync_cycles))
            provisos (Bits#(bits_type, sz));
    (* hide *) let _sync <- mkInputSync();
    mkConnection(_sync, f);

    return _sync;
endmodule

//
// `mkOutputSyncFor` acts like a wire, connecting a module output to a top level
// interface, ignoring any difference in reset context between the module and
// the interface.
//
// This primitive works around the compiler generated warnings when an external
// (async) reset is synchronized in a top module, implicitly creating a new
// reset domain, before being used to reset downstream modules. Outputs from
// these modules connected to methods in the top interface would otherwise
// correctly be flagged for crossing a reset domain.
//
// Note that this should only be used for output signals connecting to external
// pins without any additional logic in the middle. In all other cases the
// resulting behavior is likely not what is intended and more thorough
// synchronisation primitives should be used.
//
module mkOutputSyncFor #(bits_type val) (ReadOnly#(bits_type))
        provisos (Bits#(bits_type, sz));
    Clock c <- exposeCurrentClock();
    (* hide *) ReadOnly#(bits_type) _sync <- mkNullCrossingWire(c, val);

    return _sync;
endmodule

//
// `mkOuputSyncRegFor` is similar to `mkOutputSyncFor`, except that an
// additional register is inserted between the connected value and the output
// pin. This may be useful to improve setup/hold times or meet external timing
// requirements.
//
// The implicit expectation for this module is that synthesis tools will map
// this register on the flip-flop often found in the output structure of IO
// tiles.
//
module mkOutputRegSyncFor #(bits_type val) (ReadOnly#(bits_type))
        provisos (Bits#(bits_type, sz));
    (* hide *) CrossingReg#(bits_type) _sync <- mkNullCrossingRegU(noClock);

    (* fire_when_enabled *)
    rule do_sync;
        _sync <= val;
    endrule

    method _read = _sync.crossed;
endmodule

//
// `mkOutputWithEnableSyncFor` takes a value and enable predicate and turns them
// into an `Inout` which can be directly connected to a top level interface.
// This primitive can be used to implement an output driver such as the SO
// signal in a SPI interface which can be selectively enabled.
//
module mkOutputWithEnableSyncFor #(bits_type d_, Bool en_) (Inout#(bits_type))
        provisos (Bits#(bits_type, sz));
    (* hide *) WriteOnlyTriState#(bits_type) _pad <-
        mkNullCrossingWriteOnlyTriState(en_, d_);

    return _pad.o;
endmodule

//
// `mkOutputRegWithEnableSyncFor` is similar to `mkOutputWithEnableSyncFor` but
// registers both the value and enable signal.
//
// The implicit expectation for this module is that synthesis tools will map
// this register on the flip-flop often found in the output structure of IO
// tiles.
//
module mkOutputRegWithEnableSyncFor #(
        bits_type d,
        Bool en_)
            (Inout#(bits_type))
                provisos (Bits#(bits_type, sz));
    ReadOnly#(Bool) en <- mkOutputRegSyncFor(en_);
    ReadOnly#(bits_type) q <- mkOutputRegSyncFor(d);

    (* hide *) WriteOnlyTriState#(bits_type) _pad <-
        mkNullCrossingWriteOnlyTriState(en, q);

    return _pad.o;
endmodule

//
// `mkBidirectionSyncFor` is a wrapper providing input/output synchronization
// for a `Bidirection` value. The wrapper exposes the `Bidirection` as an
// `Inout` which can be connected directly to a top level interface. The input
// signal goes through a two cycle synchronizer and both the output and enable
// signals are registered.
//
// The implicit expectation for this module is that synthesis tools will map
// these registers on the flip-flops often found in the output structure of IO
// tiles.
//
module mkBidirectionRegSyncFor #(Bidirection#(bit_type) bidir) (Inout#(bit_type))
        provisos (Bits#(bit_type, sz));
    ReadOnly#(Bool) q_en <- mkOutputRegSyncFor(bidir.out_en);
    ReadOnly#(bit_type) q <- mkOutputRegSyncFor(bidir.out);
    InputReg#(bit_type, 2) d <- mkInputSyncFor(bidir.in);

    (* hide *) TriState#(bit_type) _pad <- mkTriState(q_en, q);

    // Synchronize the input.
    mkConnection(_pad, sync(d));

    return _pad.io;
endmodule

//
// `sync(..)` is syntactic sugar which can be used to connect an input
// synchronizer to top interface methods, expressing that this signal is
// synchronized before being passed further into the design.
//
function (function Action f(bits_type val))
    sync(InputReg#(bits_type, sync_cycles) _sync) = _sync._write;

//
// `sync_inverted(..)` similarly can be used to connect an input synchronizer to
// a top module method, but as the name implies the incoming value is bitwise
// inverted before being synchronized.
//
// Performing the inversion where the synchronizer is connected to the top
// interface method expresses the intent that the signal is inverted before
// being consumed by the design. In addition some synthesis tools may be able to
// map the bit inversion on logic provided by the IO tile.
//
function (function Action f(bits_type val))
    sync_inverted(InputReg#(bits_type, sync_cycles) _sync)
        provisos (Bits#(bits_type, sz));
    function Action f(bits_type val) = _sync._write(unpack(~pack(val)));
    return f;
endfunction

endpackage

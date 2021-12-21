// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package SyncBits;

export SyncBitsIfc(..);
export mkSyncBits, mkSyncBitsFromCC, mkSyncBitsToCC;

import Clocks::*;
import Vector::*;


//
// SyncBitsIfc is a multiple bit variant of the SyncBitIfc found in the standard
// library. The purpose of this interface is to provide a slightly more
// convenient way to move a group of signals which do not have a timing
// relationship across clock domains. An example of this would be several async
// signals such as interrupts, grouped together as a struct to simplify an
// interface, or multiple bit values received from input pins.
//
// For high performance interfaces such as DDR memories or SerDes I/O you will
// most likely need more specific primitives.
//
// Do not use this for clock domain crossings of multiple bit values which have
// a timing relationship/need to be consistent across clock domains. Use the
// word synchronizers provided by the standard library for this.
//
interface SyncBitsIfc #(type bits_type);
    method Action send(bits_type data);
    method bits_type read();
endinterface

module mkSyncBits #(Clock sClkIn, Reset sRst, Clock dClkIn) (SyncBitsIfc#(bits_type))
        provisos (Bits#(bits_type, sz));
    // Vector of SyncBitIfc instances holding the bits.
    Vector#(sz, SyncBitIfc#(Bit#(1))) bits;
    for (Integer i = 0; i < valueOf(sz); i = i + 1)
        bits[i] <- mkSyncBit(sClkIn, sRst, dClkIn);

    // Helper to read bit values using the map(..) function, similar to readReg.
    function Bit#(1) readSyncBitIfc(SyncBitIfc#(Bit#(1)) b) = b.read;

    method Action send(bits_type data);
        for (Integer i = 0; i < valueOf(sz); i = i + 1)
            bits[i].send(pack(data)[i]);
    endmethod

    method bits_type read();
        return unpack(pack(map(readSyncBitIfc, bits)));
    endmethod
endmodule

module mkSyncBitsFromCC #(Clock dClkIn) (SyncBitsIfc#(bits_type))
        provisos (Bits#(bits_type, sz));
    Clock sClk <- exposeCurrentClock();
    Reset sRst <- exposeCurrentReset();
    (* hide *) SyncBitsIfc#(bits_type) _ifc <- mkSyncBits(sClk, sRst, dClkIn);

    return _ifc;
endmodule

module mkSyncBitsToCC #(Clock sClkIn, Reset sRstIn) (SyncBitsIfc#(bits_type))
        provisos (Bits#(bits_type, sz));
    Clock dClk <- exposeCurrentClock();
    (* hide *) SyncBitsIfc#(bits_type) _ifc <- mkSyncBits(sClkIn, sRstIn, dClk);

    return _ifc;
endmodule

endpackage: SyncBits

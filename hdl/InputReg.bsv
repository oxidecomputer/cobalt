// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package InputReg;

export mkInputReg, mkInputRegA, mkInputRegU;

//
// InputReg is a primitive used to synchronize external signals with the current clock domain and
// avoid meta unstable input. In addition it can be used to convince BSC that reset information for
// these inputs can be ignored for designs which synthesize a reset as part of their design top.
//
// For high performance interfaces such as DDR memories or SerDes I/O you will most likely need more
// specific primitives.
//

module mkInputReg #(a_type init) (Reg#(a_type))
        provisos (Bits#(a_type, sz));
    Reg#(a_type) r0 <- mkRegU();
    Reg#(a_type) r1 <- mkReg(init);

    (* fire_when_enabled *)
    rule do_sync;
        r1 <= r0;
    endrule

    method _read = r1._read;
    method _write = r0._write;
endmodule

module mkInputRegA #(a_type init) (Reg#(a_type))
        provisos (Bits#(a_type, sz));
    Reg#(a_type) r0 <- mkRegU();
    Reg#(a_type) r1 <- mkRegA(init);

    (* fire_when_enabled *)
    rule do_sync;
        r1 <= r0;
    endrule

    method _read = r1._read;
    method _write = r0._write;
endmodule

module mkInputRegU (Reg#(a_type))
        provisos (Bits#(a_type, sz));
    Reg#(a_type) r0 <- mkRegU();
    Reg#(a_type) r1 <- mkRegU();

    (* fire_when_enabled *)
    rule do_sync;
        r1 <= r0;
    endrule

    method _read = r1._read;
    method _write = r0._write;
endmodule

endpackage: InputReg

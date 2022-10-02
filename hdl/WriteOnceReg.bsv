// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package WriteOnceReg;

//
// `mkWriteOnceReg` is a thin wrapper around a `Reg#(t)`, allowing it to be
// written only once. Subsequent writes to the register are silently ignored.
// This can for example be used to implement write once soft fuses.
//
module mkWriteOnceReg #(module#(Reg#(t)) m) (Reg#(t));
    (* hide *) Reg#(t) _r <- m;
    Reg#(Bool) written <- mkReg(False);

    method t _read = _r._read;
    method Action _write(t val);
        if (!written) begin
            _r <= val;
            written <= True;
        end
    endmethod
endmodule

//
// `mkWriteOnceRegA` is a thin wrapper around a `Reg#(t)`, allowing it to be
// written only once. Subsequent writes to the register are silently ignored.
// This can for example be used to implement write once soft fuses.
//
module mkWriteOnceRegA #(module#(Reg#(t)) m) (Reg#(t));
    (* hide *) Reg#(t) _r <- m;
    Reg#(Bool) written <- mkRegA(False);

    method t _read = _r._read;
    method Action _write(t val);
        if (!written) begin
            _r <= val;
            written <= True;
        end
    endmethod
endmodule

endpackage

// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package WriteOnceReg;

export asWriteOnceReg;
export asWriteOnceRegA;

export mkWriteOnceReg;
export mkWriteOnceRegA;
export mkWriteOnceRegU;
export mkWriteOnceConfigReg;
export mkWriteOnceConfigRegA;
export mkWriteOnceConfigRegU;

import ConfigReg::*;


//
// `mkWriteOnceReg` is a thin wrapper around a `Reg#(t)`, allowing it to be
// written only once. Subsequent writes to the register are silently ignored
// which can for example be used to implement write once soft fuses.
//
module asWriteOnceReg #(module#(Reg#(t)) m) (Reg#(t));
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
// `asWriteOnceRegA` is a thin wrapper around a `Reg#(t)`, allowing it to be
// written only once. Subsequent writes to the register are silently ignored
// which can for example be used to implement write once soft fuses. The state
// for this wrapper is reset asynchronously.
//
module asWriteOnceRegA #(module#(Reg#(t)) m) (Reg#(t));
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

// Create a WriteOnce Reg with synchronous reset to the given init value.
function module#(Reg#(t)) mkWriteOnceReg(t init)
    provisos (Bits#(t, t_sz)) =
        asWriteOnceReg(mkReg(init));

// Create a WriteOnce Reg with asynchronous reset to the given init value.
function module#(Reg#(t)) mkWriteOnceRegA(t init)
    provisos (Bits#(t, t_sz)) =
        asWriteOnceRegA(mkRegA(init));

// Create a WriteOnce Reg without an explicit reset.
function module#(Reg#(t)) mkWriteOnceRegU()
    provisos (Bits#(t, t_sz)) =
        asWriteOnceReg(mkRegU());

// Create a WriteOnce ConfigReg with synchronous reset to the given init value.
function module#(Reg#(t)) mkWriteOnceConfigReg(t init)
    provisos (Bits#(t, t_sz)) =
        asWriteOnceReg(mkConfigReg(init));

// Create a WriteOnce ConfigReg with asynchronous reset to the given init value.
function module#(Reg#(t)) mkWriteOnceConfigRegA(t init)
    provisos (Bits#(t, t_sz)) =
        asWriteOnceRegA(mkConfigRegA(init));

// Create a WriteOnce ConfigReg without an explicit reset.
function module#(Reg#(t)) mkWriteOnceConfigRegU()
    provisos (Bits#(t, t_sz)) =
        asWriteOnceReg(mkConfigRegU());

endpackage

// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Serializer8b10b;

export Serializer(..);
export mkSerializer;

import GetPut::*;
import Vector::*;

import Encoding8b10b::*;


//
// Serializer
//

interface Serializer;
    interface Put#(Character) character;
    interface Get#(Bit#(1)) serial;
endinterface

module mkSerializer (Serializer);
    // Shift buffer containing the bits to be shifted out.
    Reg#(Vector#(SizeOf#(Character), Bit#(1))) buffer <- mkRegU();
    // Bitmap indicating which bits in the buffer are valid (and still to be
    // shifted out).
    Reg#(Vector#(SizeOf#(Character), Bool)) bit_valid <- mkRegU();

    // Events
    RWire#(Character) character_next <- mkRWire();
    PulseWire shift <- mkPulseWire();

    let empty = !head(bit_valid);
    let last_bit = !bit_valid[1];

    (* fire_when_enabled *)
    rule do_update_buffer;
        if (character_next.wget matches tagged Valid .c) begin
            buffer <= unpack(pack(c));
            bit_valid <= replicate(True);
        end else if (shift) begin
            buffer <= shiftOutFrom0(?, buffer, 1);
            bit_valid <= shiftInAtN(bit_valid, False);
        end
    endrule

    interface Put character;
        method Action put(Character c) if (empty || (last_bit && shift));
            character_next.wset(c);
        endmethod
    endinterface

    interface Get serial;
        method ActionValue#(Bit#(1)) get() if (!empty);
            shift.send();
            return head(buffer);
        endmethod
    endinterface
endmodule

endpackage

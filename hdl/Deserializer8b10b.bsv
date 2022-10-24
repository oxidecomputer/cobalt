// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Deserializer8b10b;

export DeserializedCharacter(..);
export Deserializer(..);
export mkDeserializer;

import GetPut::*;
import FIFO::*;
import FIFOF::*;
import Vector::*;

import Encoding8b10b::*;


typedef struct {
    // Flag indicating the character is shaped like a comma character (meaning
    // it contains five consecutive 0's or 1's).
    Bool comma;
    Character c;
} DeserializedCharacter deriving (Bits, Eq, FShow);

interface Deserializer;
    // Use a `GetS` interface in order to allow downstream logic to determine
    // when it is ready for the next character.
    interface GetS#(DeserializedCharacter) character;
    interface Put#(Bit#(1)) serial;

    // Slip incoming bits until a comma pattern is detected in the bit stream.
    method Action search_for_comma();

    // Bit invert any characters returned, allowing any polarity inversion of
    // incoming bits to be undone.
    method Action invert_polarity();
endinterface

// A minimal implementation of the `Deserializer` interface. This module expects
// downstream logic to dequeue received characters before the next character has
// been completely received. Failure to do so will mean the previous character
// is dropped in order to stay in sync with the transmitter.
module mkDeserializer (Deserializer);
    // Use a FIFO with unguarded enq, allowing the currently queued character to
    // be overwritten if downstream logic is not keeping up.
    FIFOF#(DeserializedCharacter) out <- mkGLFIFOF(True, False);

    Reg#(Vector#(SizeOf#(Character), Bit#(1))) buffer <- mkRegU();
    Reg#(Vector#(SizeOf#(Character), Bool)) bit_valid <- mkRegU();

    // Events
    Reg#(Bool) buffer_valid <- mkReg(False);
    Reg#(Bool) comma <- mkReg(False);
    PulseWire search_for_comma_ <- mkPulseWire();
    PulseWire invert_polarity_ <- mkPulseWire();

    interface GetS character = fifoToGetS(fifofToFifo(out));

    interface Put serial;
        method Action put(Bit#(1) b);
            // Enqueue a character when searching for a comma and a comma has
            // been determine to be in the buffer or when (the next) ten bits
            // have been shifted into the buffer.
            let enq_character =
                (search_for_comma_ && comma) ||
                (!search_for_comma_ && buffer_valid);

            // Always shift the next bit into the buffer.
            buffer <= shiftInAtN(buffer, b);
            // Reset the buffer valid bits when the buffer is enqueued,
            // otherwise track the buffer state by marking the MSB valid.
            bit_valid <= enq_character ?
                unpack(10'b1000000000) :
                shiftInAtN(bit_valid, True);

            // The shift buffer is valid if all bits in the buffer are valid or
            // if a comma has been detected. These flags are determined one bit
            // early and therefor take from a vector offset 1.
            comma <=
                takeAt(1, buffer) == unpack(7'b1111100) ||
                takeAt(1, buffer) == unpack(7'b0000011);
            buffer_valid <=
                bit_valid == unpack(10'b1111111110);

            // Finally, enqueue the buffer if it was determined it holds a
            // character.
            if (enq_character) begin
                out.enq(DeserializedCharacter {
                    comma: comma,
                    c: Character {x: invert_polarity_ ?
                        ~pack(buffer) :
                        pack(buffer)}});
            end
        endmethod
    endinterface

    method search_for_comma = search_for_comma_.send;
    method invert_polarity = invert_polarity_.send;
endmodule

endpackage

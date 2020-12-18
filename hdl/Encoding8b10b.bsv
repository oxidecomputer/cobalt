// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Encoding8b10b;

export Value(..), value_bits, mk_d, mk_k, is_d, is_k;
export Character, mk_c;
export Result(..), ValueResult(..), CharacterResult(..);
export result_valid, value_result_bits, character_result_bits;
export RunningDisparity(..), Encoder(..), Decoder(..);
export fmt_character;

import GetPut::*;


//
// Value
//
// A union type representing an 8-bit Dx.y or Kx.y value. Note: while a K value with the full 8 bit
// range can be constructed, only 16 values are valid characters in this encoding.
//
typedef union tagged {
    Bit#(8) D;
    Bit#(8) K;
} Value deriving (Bits, Eq);

// Return the actual value bits.
function Bit#(8) value_bits(Value v) = pack(v)[7:0];

// Constructors, allowing for expressions which match the Dx.y/Kx.y format often used in protocol
// documentation.
function Value mk_d(Bit#(5) x, Bit#(3) y) = tagged D({y, x});
function Value mk_k(Bit#(5) x, Bit#(3) y) = tagged K({y, x});

// Tests to determine whether or not a given Value is of type K or D respectively.
function Bool is_d(Value v) =
    case (v) matches
        tagged D .*: True;
        default: False;
    endcase;
function Bool is_k(Value v) = !is_d(v);

//
// Character
//
// A type alias representing a 10 bit encoded value, often referred to as a character. Note: while
// not enforced in any way, these characters are often MSB first.
//
typedef Bit#(10) Character;

// Construct a Character from the given 10 bit value. The input is reversed such that the resulting
// Character is MSB first.
function Character mk_c(Bit#(10) c) = reverseBits(c);

//
// Result
//
// Result is a generic union type used to capture the output from an encoding/decoding step. This
// is expected to be used with the Value/Character types (see type specializations below).
//
typedef union tagged {
    Bit#(n) Invalid;
    t Valid;
} Result#(numeric type n, type t) deriving (Bits, Eq, FShow);

// Test whether or not the result is valid.
function Bool result_valid(Result#(n, t) r) =
    case (r) matches
        tagged Valid .*: True;
        default: False;
    endcase;

// Type specializations for Value and Character results. These represent either a valid Value or
// Character (as their appropriate types) or the invalid bit value.
typedef Result#(8, Value) ValueResult;
typedef Result#(10, Character) CharacterResult;

// Return the value bits for a ValueResult.
function Bit#(8) value_result_bits(ValueResult v) = pack(v)[7:0];

// Return the bits for a CharacterResult.
function Character character_result_bits(CharacterResult c) = pack(c)[9:0];

typedef enum {
    RunningNegative,
    RunningPositive
} RunningDisparity deriving (Bits, Eq);

//
// Encoder interface.
//
// An interface to allow for encoding of Values to Characters using GetPut primitives.
//
interface Encoder;
    interface Put#(Value) value;
    interface Get#(CharacterResult) character;

    (* always_ready, always_enabled *)
    method RunningDisparity running_disparity();
endinterface

//
// Decoder interface.
//
// An interface to allow for decoding of Characters to Values using GetPut primitives.
//
interface Decoder;
    interface Put#(Character) character;
    interface Get#(ValueResult) value;

    (* always_ready, always_enabled *)
    method Maybe#(RunningDisparity) running_disparity();
endinterface

//
// Format helpers.
//

// Format the bits of a value in the x.y notation.
function Fmt fmt_value_bits(Bit#(8) v) = $format("%d.%d", v[4:0], v[7:5]);

// Format a Value.
instance FShow#(Value);
    function Fmt fshow(Value v) =
        case (v) matches
            tagged K ._v: $format("K", fmt_value_bits(_v));
            tagged D ._v: $format("D", fmt_value_bits(_v));
        endcase;
endinstance

// Format a Character in the yyyyyy_xxxx notation seen in "paper" encoding tables.
function Fmt fmt_character(Character _c);
    let c = mk_c(_c); // reverse bits such that Character is printed left to right.
    return $format("%b_%b", c[9:4], c[3:0]);
endfunction

// Generic formatter for Result, used to implement the FShow type class.
function Fmt fmt_result(
        Result#(n, t) r,
        function Fmt fmt_invalid(Bit#(n) v),
        function Fmt fmt_valid(t v)) =
    case (r) matches
        tagged Invalid .v: $format("\x1b\x5b\x33\x31\x6d ", fmt_invalid(v), "\x1b\x5b\x6d");
        tagged Valid .v: $format(" ", fmt_valid(v));
    endcase;

instance FShow#(ValueResult);
    function fshow(r) = fmt_result(r, fmt_value_bits, fshow);
endinstance

instance FShow#(CharacterResult);
    function fshow(r) = fmt_result(r, fmt_character, fmt_character);
endinstance

instance FShow#(RunningDisparity);
    function Fmt fshow(RunningDisparity d) =
        case (d)
            RunningNegative: $format("-");
            RunningPositive: $format("+");
        endcase;
endinstance

endpackage: Encoding8b10b

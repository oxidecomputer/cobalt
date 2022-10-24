// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public License,
// v. 2.0. If a copy of the MPL was not distributed with this file, You can
// obtain one at https://mozilla.org/MPL/2.0/.
//
// Different copyright applies to the encode(..) and decode(..) functions below.
// See their comments for more details.

package Encoding8b10b;

export Value(..);
export value_bits;
export mk_d;
export mk_k;
export is_d;
export is_k;

export Character(..);
export mk_c;
export invert_character;

export Result(..);
export ValueResult(..);
export CharacterResult(..);
export result_valid;
export result_bits;

export RunningDisparity(..);

export EncodeResult(..);
export encode;
export Encoder(..);
export mkEncoder;

export DecodeResult(..);
export decode;

import GetPut::*;
import FIFO::*;


//
// `Value`
//
// A union type representing an 8-bit Dx.y or Kx.y value. Note: while a K value
// with the full 8 bit range can be constructed, only 16 values are valid
// characters in this encoding.
//
typedef union tagged {
    Bit#(8) D;
    Bit#(8) K;
} Value deriving (Bits, Eq);

// Return the actual value bits.
function Bit#(8) value_bits(Value v) = pack(v)[7:0];

// Constructors, allowing for expressions which match the Dx.y/Kx.y format often
// used in protocol documentation.
function Value mk_d(Bit#(5) x, Bit#(3) y) = tagged D({y, x});
function Value mk_k(Bit#(5) x, Bit#(3) y) = tagged K({y, x});

// Tests to determine whether or not a given Value is of type K or D
// respectively.
function Bool is_d(Value v) =
    case (v) matches
        tagged D .*: True;
        default: False;
    endcase;
function Bool is_k(Value v) = !is_d(v);

//
// `Character`
//
// A type representing a 10 bit encoded value, sometimes referred to as a
// character. Note: while not enforced in any way, these characters are expected
// to be in jhgf_iedcba bit order allowing them to be shifted out lsb first
// during transmission. Most (all?) "paper" encoding tables show these in
// abcdei_fghj order, so keep this in mind when debugging.
//
typedef struct {
    Bit#(10) x;
} Character deriving (Literal, Bits, Eq);

// Construct a Character from the given 10 bit value. The input is reversed such
// that the resulting Character is in jhgf_iedcba bit order.
function Character mk_c(Bit#(10) c) = Character {x: reverseBits(c)};

// Bit-invert the given Character c.
function Character invert_character(Character c) = Character {x: ~c.x};

//
// Result
//
// Result is a generic union type used to capture the output from an
// encoding/decoding step. This is expected to be used with the Value/Character
// types (see type specializations below).
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

// Type specializations for `Value` and `Character` results. These represent
// either a valid Value or Character (as their appropriate types) or the invalid
// bit value.
typedef Result#(8, Value) ValueResult;
typedef Result#(10, Character) CharacterResult;

function Bit#(n) result_bits(Result#(n, t) result)
        provisos (
            Bits#(t, t_sz),
            Add#(n, 0, t_sz));
    return pack(result)[valueOf(TSub#(n, 1)):0];
endfunction

//
// `RunningDisparity`
//
// A type representing the running disparity of an encoder/decoder.
//
typedef enum {
    RunningNegative,
    RunningPositive
} RunningDisparity deriving (Bits, Eq);

// Implement `Bitwise` for `RunningDisparity`. Practically only the invert
// operation will be used, but it doesn't hurt to add some of the others.
instance Bitwise#(RunningDisparity);
    function RunningDisparity \& (
        RunningDisparity rd1,
        RunningDisparity rd2) =
            unpack(pack(rd1) & pack(rd1));
    function RunningDisparity \| (
        RunningDisparity rd1,
        RunningDisparity rd2) =
            unpack(pack(rd1) | pack(rd2));
    function RunningDisparity \^ (
        RunningDisparity rd1,
        RunningDisparity rd2) =
            unpack(pack(rd1) ^ pack(rd2));
    function RunningDisparity \~^ (
        RunningDisparity rd1,
        RunningDisparity rd2) =
            unpack(pack(rd1) ~^ pack(rd2));
    function RunningDisparity \^~ (
        RunningDisparity rd1,
        RunningDisparity rd2) =
            unpack(pack(rd1) ^~ pack(rd2));
    function RunningDisparity invert (RunningDisparity rd) =
        unpack(invert(pack(rd)));
    function RunningDisparity \<< (RunningDisparity rd, t x) =
        error("Left shift operation is not supported with type RunningDisparity");
    function RunningDisparity \>> (RunningDisparity rd, t x) =
        error("Right shift operation is not supported with type RunningDisparity");
    function Bit#(1) msb (RunningDisparity rd) = pack(rd);
    function Bit#(1) lsb (RunningDisparity rd) = pack(rd);
endinstance

//
// Encode
//

typedef struct {
    CharacterResult character;
    RunningDisparity rd;
} EncodeResult deriving (Bits, Eq, FShow);

//
// The `encode(..)` function is a Bluespec port of the encode function by Chuck
// Benz. These are taken with permission as per the notice which follows, see
// http://asics.chuckbenz.com/, http://asics.chuckbenz.com/encode.v. The
// comments in the function are mostly left verbatim.
//
// Chuck Benz, Hollis, NH   Copyright (c)2002
//
// The information and description contained herein is the property of Chuck
// Benz.
//
// Permission is granted for any reuse of this information and description as
// long as this copyright notice is preserved.  Modifications may be made as
// long as this notice is preserved.
//
// per Widmer and Franaszek
//
function EncodeResult encode(Value v, RunningDisparity rd);
    let ai = pack(v)[0];
    let bi = pack(v)[1];
    let ci = pack(v)[2];
    let di = pack(v)[3];
    let ei = pack(v)[4];
    let fi = pack(v)[5];
    let gi = pack(v)[6];
    let hi = pack(v)[7];
    let ki = pack(v)[8];
    let rd_ = pack(rd);

    let is_k = Bool'(unpack(ki));
    let rd_positive = Bool'(unpack(rd_));

    let aeqb = (ai & bi) | (~ai & ~bi);
    let ceqd = (ci & di) | (~ci & ~di);
    let l22 =
        (ai & bi & ~ci & ~di) |
        (ci & di & ~ai & ~bi) |
        (~aeqb & ~ceqd);
    let l40 = ai & bi & ci & di;
    let l04 = ~ai & ~bi & ~ci & ~di;
    let l13 =
        (~aeqb & ~ci & ~di) |
        (~ceqd & ~ai & ~bi);
    let l31 =
        (~aeqb & ci & di) |
        (~ceqd & ai & bi);

    // The 5B/6B encoding
    let ao = ai;
    let bo = (bi & ~l40) | l04;
    let co = l04 | ci | (ei & di & ~ci & ~bi & ~ai);
    let do_ = di & ~(ai & bi & ci);
    let eo = (ei | l13) & ~(ei & di & ~ci & ~bi & ~ai);
    let io = (l22 & ~ei) |
          (ei & ~di & ~ci & ~(ai & bi)) |   // D16, D17, D18
          (ei & l40) |
          (ki & ei & di & ci & ~bi & ~ai) | // K.28
          (ei & ~di & ci & ~bi & ~ai);

    // pds16 indicates cases where d-1 is assumed positive to get our encoded
    // value
    let pd1s6 = (ei & di & ~ci & ~bi & ~ai) | (~ei & ~l22 & ~l31);
    // nds16 indicates cases where d-1 is assumed negative to get our encoded
    // value
    let nd1s6 = ki | (ei & ~l22 & ~l13) | (~ei & ~di & ci & bi & ai);

    // ndos6 is pds16 cases where d-1 is positive, yields negative rd for all
    // cases.
    let ndos6 = pd1s6 ;
    // pdos6 is nds16 cases where d-1 is negative, yields positive rd for all
    // but one case.
    let pdos6 = ki | (ei & ~l22 & ~l13);

    // Some Dx.7 and all Kx.7 cases result in run length of 5 case unless an
    // alternate coding is used (referred to as Dx.A7, normal is Dx.P7)
    // specifically, D11, D13, D14, D17, D18, D19.
    let alt7 = fi & gi & hi &
            (ki | (rd_positive ? (~ei & di & l31) : (ei & ~di & l13)));

    let fo = fi & ~alt7;
    let go = gi | (~fi & ~gi & ~hi);
    let ho = hi;
    let jo = (~hi & (gi ^ fi)) | alt7;

    // nd1s4 is cases where d-1 is assumed - to get our encoded value
    let nd1s4 = fi & gi;
    // pd1s4 is cases where d-1 is assumed + to get our encoded value
    let pd1s4 = (~fi & ~gi) | (ki & ((fi & ~gi) | (~fi & gi)));

    // ndos4 is pd1s4 cases where d-1 is + yields - disp out - just some
    let ndos4 = (~fi & ~gi);
    // pdos4 is nd1s4 cases where d-1 is - yields + disp out
    let pdos4 = fi & gi & hi;

    // Only legal K codes are K28.0-7, K23/27/29/30.7:
    //	K28.0->7 is ei=di=ci=1,bi=ai=0
    //	K23 is 10111
    //	K27 is 11011
    //	K29 is 11101
    //	K30 is 11110 - so K23/27/29/30 are ei & l31
    let invalid_k = unpack(ki &
            (ai | bi | ~ci | ~di | ~ei) &       // not K28.0-7
            (~fi | ~gi | ~hi | ~ei | ~l31));    // not K23/27/29/30.7

    // now determine whether to do the complementing
    // complement if prev disp is - and pd1s6 is set, or + and nd1s6 is set
    let compls6 = (pd1s6 & ~rd_) | (nd1s6 & rd_);

    // rd_next of 5b/6b is rd with pdso6 and ndso6
    // pds16 indicates cases where d-1 is assumed positive to get our encoded value
    // ndos6 is cases where d-1 is positive, yields negative rd_next
    // nds16 indicates cases where d-1 is assumed negative to get our encoded value
    // pdos6 is cases where d-1 is - yields a positive rd_next
    // rd_next toggles in all ndis16 cases, and all but that 1 nds16 case

    let rd6 = rd_ ^ (ndos6 | pdos6);
    let rd_next = rd6 ^ (ndos4 | pdos4);
    let compls4 = (pd1s4 & ~rd6) | (nd1s4 & rd6);

    let c = {
        (jo ^ compls4), (ho ^ compls4),
        (go ^ compls4), (fo ^ compls4),
        (io ^ compls6), (eo ^ compls6),
        (do_ ^ compls6), (co ^ compls6),
        (bo ^ compls6), (ao ^ compls6)};

    return EncodeResult {
        character: is_k && invalid_k ?
            tagged Invalid c :
            tagged Valid Character {x: c},
        rd: unpack(rd_next)};
endfunction

interface Encoder;
    interface Put#(Value) value;
    interface Get#(CharacterResult) character;
    method Action clear();
endinterface

module mkEncoder #(RunningDisparity init) (Encoder);
    FIFO#(CharacterResult) out <- mkLFIFO();
    Reg#(RunningDisparity) rd <- mkReg(init);

    interface Put value;
        method Action put(Value v);
            let result = encode(v, rd);
            out.enq(result.character);
            rd <= result.rd;
        endmethod
    endinterface

    interface Get character = fifoToGet(out);

    method Action clear();
        out.clear();
        rd <= init;
    endmethod
endmodule

//
// Decode
//

typedef struct {
    ValueResult value;
    Maybe#(RunningDisparity) rd;
} DecodeResult deriving (Bits, Eq, FShow);

//
// The `decode(..)` function is a Bluespec port of the decode function by Chuck
// Benz. These are taken with permission as per the notice which follows, see
// http://asics.chuckbenz.com/, http://asics.chuckbenz.com/decode.v. The
// comments in the function are mostly left verbatim.
//
// Chuck Benz, Hollis, NH   Copyright (c)2002
//
// The information and description contained herein is the property of Chuck
// Benz.
//
// Permission is granted for any reuse of this information and description as
// long as this copyright notice is preserved.  Modifications may be made as
// long as this notice is preserved.
//
// per Widmer and Franaszek
//
function DecodeResult decode(Character c, RunningDisparity rd_);
    let ai = c.x[0];
    let bi = c.x[1];
    let ci = c.x[2];
    let di = c.x[3];
    let ei = c.x[4];
    let ii = c.x[5];
    let fi = c.x[6];
    let gi = c.x[7];
    let hi = c.x[8];
    let ji = c.x[9];

    let rd = pack(rd_);

    let aeqb = (ai & bi) | (~ai & ~bi);
    let ceqd = (ci & di) | (~ci & ~di);
    let p22 = (ai & bi & ~ci & ~di) |
            (ci & di & ~ai & ~bi) |
            (~aeqb & ~ceqd);
    let p13 = (~aeqb & ~ci & ~di) |
            (~ceqd & ~ai & ~bi);
    let p31 = (~aeqb & ci & di) |
            (~ceqd & ai & bi);

    let p40 = ai & bi & ci & di;
    let p04 = ~ai & ~bi & ~ci & ~di;

    let rd6a = p31 | (p22 & rd);    // pos rd if p22 and was pos, or p31.
    let rd6a2 = p31 & rd;           // rd is ++ after 4 bits
    let rd6a0 = p13 & ~rd;          // -- rd after 4 bits

    let rd6b = (((ei & ii & ~rd6a0) | (rd6a & (ei | ii)) | rd6a2 |
            (ei & ii & di)) & (ei | ii | di));

    // The 5B/6B decoding special cases where ABCDE ~= abcde

    let p22bceeqi = p22 & bi & ci & pack(ei == ii);
    let p22bncneeqi = p22 & ~bi & ~ci & pack(ei == ii);
    let p13in = p13 & ~ii;
    let p31i = p31 & ii;
    let p13dei = p13 & di & ei & ii;
    let p22aceeqi = p22 & ai & ci & pack(ei == ii);
    let p22ancneeqi = p22 & ~ai & ~ci & pack(ei == ii);
    let p13en = p13 & ~ei;
    let anbnenin = ~ai & ~bi & ~ei & ~ii;
    let abei = ai & bi & ei & ii;
    let cdei = ci & di & ei & ii;
    let cndnenin = ~ci & ~di & ~ei & ~ii;

    // non-zero disparity cases:
    let p22enin = p22 & ~ei & ~ii;
    let p22ei = p22 & ei & ii;
    //let p13in = p12 & ~ii ;
    //let p31i = p31 & ii ;
    let p31dnenin = p31 & ~di & ~ei & ~ii;
    //let p13dei = p13 & di & ei & ii ;
    let p31e = p31 & ei;

    let compa = p22bncneeqi | p31i | p13dei | p22ancneeqi |
        p13en | abei | cndnenin;
    let compb = p22bceeqi | p31i | p13dei | p22aceeqi |
        p13en | abei | cndnenin;
    let compc = p22bceeqi | p31i | p13dei | p22ancneeqi |
        p13en | anbnenin | cndnenin;
    let compd = p22bncneeqi | p31i | p13dei | p22aceeqi |
        p13en | abei | cndnenin;
    let compe = p22bncneeqi | p13in | p13dei | p22ancneeqi |
        p13en | anbnenin | cndnenin;

    let ao = ai ^ compa;
    let bo = bi ^ compb;
    let co = ci ^ compc;
    let do_ = di ^ compd;
    let eo = ei ^ compe;

    let feqg = (fi & gi) | (~fi & ~gi);
    let heqj = (hi & ji) | (~hi & ~ji);
    let fghj22 = (fi & gi & ~hi & ~ji) |
        (~fi & ~gi & hi & ji) |
        ( ~feqg & ~heqj) ;
    let fghjp13 = ( ~feqg & ~hi & ~ji) |
            ( ~heqj & ~fi & ~gi) ;
    let fghjp31 = ( (~feqg) & hi & ji) |
            ( ~heqj & fi & gi) ;

    let rd_next = unpack((fghjp31 | (rd6b & fghj22) | (hi & ji)) & (hi | ji));

    let ko = ( (ci & di & ei & ii) | ( ~ci & ~di & ~ei & ~ii) |
        (p13 & ~ei & ii & gi & hi & ji) |
        (p31 & ei & ~ii & ~gi & ~hi & ~ji));

    let alt7 =
        (fi & ~gi & ~hi &   // 1000 cases, where rd6b is 1
            ((rd & ci & di & ~ei & ~ii) | ko |
            (rd & ~ci & di & ~ei & ~ii))) |
        (~fi & gi & hi &    // 0111 cases, where rd6b is 0
            (( ~rd & ~ci & ~di & ei & ii) | ko |
            (~rd & ci & ~di & ei & ii)));

    let k28 = (ci & di & ei & ii) | ~ (ci | di | ei | ii) ;
    // k28 with positive rd into fghi - .1, .2, .5, and .6 special cases
    let k28p = ~ (ci | di | ei | ii);
    let fo = (ji & ~fi & (hi | ~gi | k28p)) |
        (fi & ~ji & (~hi | gi | ~k28p)) |
        (k28p & gi & hi) |
        (~k28p & ~gi & ~hi);
    let go = (ji & ~fi & (hi | ~gi | ~k28p)) |
        (fi & ~ji & (~hi | gi |k28p)) |
        (~k28p & gi & hi) |
        (k28p & ~gi & ~hi);
    let ho = ((ji ^ hi) &
            ~((~fi & gi & ~hi & ji & ~k28p) |
            (~fi & gi & hi & ~ji & k28p) |
            (fi & ~gi & ~hi & ji & ~k28p) |
            (fi & ~gi & hi & ~ji & k28p))) |
        (~fi & gi & hi & ji) |
        (fi & ~gi & ~hi & ~ji);

    let rd6p = (p31 & (ei | ii)) | (p22 & ei & ii);
    let rd6n = (p13 & ~ (ei & ii)) | (p22 & ~ei & ~ii);
    let rd4p = fghjp31;
    let rd4n = fghjp13;

    let character_invalid =
        unpack(p40 | p04 | (fi & gi & hi & ji) | (~fi & ~gi & ~hi & ~ji) |
            (p13 & ~ei & ~ii) | (p31 & ei & ii) |
            (ei & ii & fi & gi & hi) | (~ei & ~ii & ~fi & ~gi & ~hi) |
            (ei & ~ii & gi & hi & ji) | (~ei & ii & ~gi & ~hi & ~ji) |
            (~p31 & ei & ~ii & ~gi & ~hi & ~ji) |
            (~p13 & ~ei & ii & gi & hi & ji) |
            (((ei & ii & ~gi & ~hi & ~ji) |
                (~ei & ~ii & gi & hi & ji)) &
                ~ ((ci & di & ei) | (~ci & ~di & ~ei))) |
            (rd6p & rd4p) | (rd6n & rd4n) |
            (ai & bi & ci & ~ei & ~ii & ((~fi & ~gi) | fghjp13)) |
            (~ai & ~bi & ~ci & ei & ii & ((fi & gi) | fghjp31)) |
            (fi & gi & ~hi & ~ji & rd6p) |
            (~fi & ~gi & hi & ji & rd6n) |
            (ci & di & ei & ii & ~fi & ~gi & ~hi) |
            (~ci & ~di & ~ei & ~ii & fi & gi & hi));

    let value = unpack({ko, ho, go, fo, eo, do_, co, bo, ao});

    // rd err fires for any legal codes that violate disparity, may fire for
    // illegal codes
    let rd_invalid =
        unpack((rd & rd6p) | (rd6n & ~rd) |
            (rd & ~rd6n & fi & gi) |
            (rd & ai & bi & ci) |
            (rd & ~rd6n & rd4p) |
            (~rd & ~rd6p & ~fi & ~gi) |
            (~rd & ~ai & ~bi & ~ci) |
            (~rd & ~rd6p & rd4n) |
            (rd6p & rd4p) | (rd6n & rd4n));

    return DecodeResult {
        value: character_invalid ?
            tagged Invalid value[7:0] :
            tagged Valid value,
        rd: rd_invalid ?
            tagged Invalid :
            tagged Valid rd_next};
endfunction

interface Decoder;
    interface Put#(Character) character;
    interface Get#(DecodeResult) result;
    method Action clear();
    method Action set_rd(RunningDisparity rd);
endinterface

module mkDecoder #(RunningDisparity init) (Decoder);
    FIFO#(DecodeResult) out <- mkLFIFO();
    Reg#(RunningDisparity) rd <- mkReg(init);

    interface Put character;
        method Action put(Character c);
            let result = decode(c, rd);

            out.enq(result);
            // Use the next RD if it is valid. If the next RD is not valid it
            // means the previous RD was invalid, but it is a guess as to what
            // it should be now so keep the current value.
            rd <= fromMaybe(rd, result.rd);
        endmethod
    endinterface

    interface Get result = fifoToGet(out);

    method Action clear();
        out.clear();
        rd <= init;
    endmethod

    method set_rd = rd._write;
endmodule

//
// Format helpers.
//

// Format the bits of a value in the x.y notation.
function Fmt fmt_value_bits(Bit#(8) v) = $format("%d.%d", v[4:0], v[7:5]);

// Format a `Value`.
instance FShow#(Value);
    function Fmt fshow(Value v) =
        case (v) matches
            tagged K ._v: $format("K", fmt_value_bits(_v));
            tagged D ._v: $format("D", fmt_value_bits(_v));
        endcase;
endinstance

// Format a `Character` in the yyyyyy_xxxx notation seen in "paper" encoding
// tables. This function assumes the given character is in MSB order.
function Fmt fmt_character_bits(Bit#(10) c) = $format("%b_%b", c[9:4], c[3:0]);

instance FShow#(Character);
    function Fmt fshow(Character c);
        return fmt_character_bits(c.x);
    endfunction
endinstance

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
    function fshow(r) = fmt_result(r, fmt_character_bits, fshow);
endinstance

instance FShow#(RunningDisparity);
    function Fmt fshow(RunningDisparity d) =
        case (d)
            RunningNegative: $format("-");
            RunningPositive: $format("+");
        endcase;
endinstance

endpackage: Encoding8b10b

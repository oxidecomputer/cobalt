// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Encoder8b10b;

export mkEncoder, mkSerializer;

import Assert::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;
import SpecialFIFOs::*;

import Encoding8b10b::*;
import TestUtils::*;


typedef struct {
    Bool pair;
    Bool neutral;
    Bit#(t) value;
} Block#(numeric type t) deriving (Bits);

typedef struct {
    Block#(4) y;
    Block#(6) x;
} Blocks deriving (Bits);

typedef struct {
    Bool valid;
    Bool k;
    Maybe#(RunningDisparity) override;
    Blocks blocks;
} LookupResult deriving (Bits);

//
// Encoding tables for a negative disparity. For blocks marked as a pair, the positive disparity
// value is found by inverting the value.
//
// Note: the values in the tables read bit-reversed from the tables found in the original paper or
// spec documents, such that when a character is produced by the encoder the bits are in the
// expected LSB to MSB order of "abcdei fghj".
//
function LookupResult lookup_blocks(Value v);
    let x = value_bits(v)[4:0];
    let y = value_bits(v)[7:5];

    //
    // D blocks lookup.
    //

    let d_blocks = Blocks{
        x: case (x)
            0:  Block{value: 'b111001, neutral: False, pair: True};
            1:  Block{value: 'b101110, neutral: False, pair: True};
            2:  Block{value: 'b101101, neutral: False, pair: True};
            3:  Block{value: 'b100011, neutral: True,  pair: False};
            4:  Block{value: 'b101011, neutral: False, pair: True};
            5:  Block{value: 'b100101, neutral: True,  pair: False};
            6:  Block{value: 'b100110, neutral: True,  pair: False};
            7:  Block{value: 'b000111, neutral: True,  pair: True};
            8:  Block{value: 'b100111, neutral: False, pair: True};
            9:  Block{value: 'b101001, neutral: True,  pair: False};
            10: Block{value: 'b101010, neutral: True,  pair: False};
            11: Block{value: 'b001011, neutral: True,  pair: False};
            12: Block{value: 'b101100, neutral: True,  pair: False};
            13: Block{value: 'b001101, neutral: True,  pair: False};
            14: Block{value: 'b001110, neutral: True,  pair: False};
            15: Block{value: 'b111010, neutral: False, pair: True};
            16: Block{value: 'b110110, neutral: False, pair: True};
            17: Block{value: 'b110001, neutral: True,  pair: False};
            18: Block{value: 'b110010, neutral: True,  pair: False};
            19: Block{value: 'b010011, neutral: True,  pair: False};
            20: Block{value: 'b110100, neutral: True,  pair: False};
            21: Block{value: 'b010101, neutral: True,  pair: False};
            22: Block{value: 'b010110, neutral: True,  pair: False};
            23: Block{value: 'b010111, neutral: False, pair: True};
            24: Block{value: 'b110011, neutral: False, pair: True};
            25: Block{value: 'b011001, neutral: True,  pair: False};
            26: Block{value: 'b011010, neutral: True,  pair: False};
            27: Block{value: 'b011011, neutral: False, pair: True};
            28: Block{value: 'b011100, neutral: True,  pair: False};
            29: Block{value: 'b011101, neutral: False, pair: True};
            30: Block{value: 'b011110, neutral: False, pair: True};
            31: Block{value: 'b110101, neutral: False, pair: True};
        endcase,
        y: case (y)
            0:  Block{value: 'b0010, neutral: False, pair: True};
            1:  Block{value: 'b1001, neutral: True,  pair: False};
            2:  Block{value: 'b1010, neutral: True,  pair: False};
            3:  Block{value: 'b1100, neutral: True,  pair: True};
            4:  Block{value: 'b0100, neutral: False, pair: True};
            5:  Block{value: 'b0101, neutral: True,  pair: False};
            6:  Block{value: 'b0110, neutral: True,  pair: False};
            7:  Block{value: 'b1000, neutral: False, pair: True};
        endcase};

    // Determine if the 4b block should be forced to one of the special case values in order to
    // avoid a characters with a run length of 5.
    Maybe#(RunningDisparity) override =
        (begin
            if (y == 7)
                case (x)
                    11: tagged Valid RunningPositive;
                    13: tagged Valid RunningPositive;
                    14: tagged Valid RunningPositive;
                    17: tagged Valid RunningNegative;
                    18: tagged Valid RunningNegative;
                    20: tagged Valid RunningNegative;
                    default: tagged Invalid;
                endcase
            else
                tagged Invalid;
        end);

    //
    // K blocks lookup.
    //

    let k28y = Block{value: 'b111100, neutral: False, pair: True};
    let k23y = Block{value: 'b010111, neutral: False, pair: True};
    let k27y = Block{value: 'b011011, neutral: False, pair: True};
    let k29y = Block{value: 'b011101, neutral: False, pair: True};
    let k30y = Block{value: 'b011110, neutral: False, pair: True};

    let kx0 =  Block{value: 'b0010, neutral: False, pair: True};
    let kx1 =  Block{value: 'b1001, neutral: True,  pair: True};
    let kx2 =  Block{value: 'b1010, neutral: True,  pair: True};
    let kx3 =  Block{value: 'b1100, neutral: True,  pair: True};
    let kx4 =  Block{value: 'b0100, neutral: False, pair: True};
    let kx5 =  Block{value: 'b0101, neutral: True,  pair: True};
    let kx6 =  Block{value: 'b0110, neutral: True,  pair: True};
    let kx7 =  Block{value: 'b0001, neutral: False, pair: True};

    Maybe#(Blocks) maybe_k_blocks =
        case (value_bits(v))
            'h1c: tagged Valid Blocks{x: k28y, y: kx0}; // K28.0
            'h3c: tagged Valid Blocks{x: k28y, y: kx1}; // K28.1
            'h5c: tagged Valid Blocks{x: k28y, y: kx2}; // K28.2
            'h7c: tagged Valid Blocks{x: k28y, y: kx3}; // K28.3
            'h9c: tagged Valid Blocks{x: k28y, y: kx4}; // K28.4
            'hbc: tagged Valid Blocks{x: k28y, y: kx5}; // K28.5
            'hdc: tagged Valid Blocks{x: k28y, y: kx6}; // K28.6
            'hfc: tagged Valid Blocks{x: k28y, y: kx7}; // K28.7
            'hf7: tagged Valid Blocks{x: k23y, y: kx7}; // K23.7
            'hfb: tagged Valid Blocks{x: k27y, y: kx7}; // K27.7
            'hfd: tagged Valid Blocks{x: k29y, y: kx7}; // K29.7
            'hfe: tagged Valid Blocks{x: k30y, y: kx7}; // K30.7
            default: tagged Invalid;
        endcase;

    // Select the blocks based on whether the input is an (invalid) K or D value.
    return (begin
        if (v matches tagged D .*)
            LookupResult{
                valid: True,
                k: False,
                override: override,
                blocks: d_blocks};
        else
            if (maybe_k_blocks matches tagged Valid .k_blocks)
                LookupResult{
                    valid: True,
                    k: True,
                    override: tagged Invalid,
                    blocks: k_blocks};
            else
                // Continue as data in an attempt to keep the encoder/line state valid.
                LookupResult{
                    valid: False,
                    k: False,
                    override: override,
                    blocks: d_blocks};
    end);
endfunction

module mkEncoder(Encoder);
    Reg#(RunningDisparity) rd <- mkRegA(RunningNegative);
    FIFO#(LookupResult) lookup_result <- mkPipelineFIFO();
    FIFO#(CharacterResult) character_result <- mkPipelineFIFO();

    (* fire_when_enabled *)
    rule do_select_character;
        let lookup = lookup_result.first();
        lookup_result.deq();

        // Determine the character for a D (or invalid K) value if the running disparity is
        // negative.
        let d_6b_rdn = lookup.blocks.x.value;
        let d_4b_rdn =
            (begin
                if (lookup.override == tagged Valid RunningNegative)
                    'b1110;
                else if (lookup.blocks.x.neutral && lookup.blocks.y.pair)
                    ~lookup.blocks.y.value;
                else
                    lookup.blocks.y.value;
            end);

        // Determine the character for a D (or invalid K) value if the running disparity is
        // positive.
        let d_6b_rdp = lookup.blocks.x.pair ? ~lookup.blocks.x.value : lookup.blocks.x.value;
        let d_4b_rdp =
            (begin
                if (lookup.override == tagged Valid RunningPositive)
                    'b0001;
                else if (!lookup.blocks.x.neutral && lookup.blocks.y.pair)
                    ~lookup.blocks.y.value;
                else
                    lookup.blocks.y.value;
            end);

        // Determine the characters for D or K depending on the running disparity.
        let d =
            case (rd)
                RunningNegative: {d_4b_rdn, d_6b_rdn};
                RunningPositive: {d_4b_rdp, d_6b_rdp};
            endcase;

        let k =
            case (rd)
                RunningNegative: {lookup.blocks.y.value, lookup.blocks.x.value};
                RunningPositive: {~lookup.blocks.y.value, ~lookup.blocks.x.value};
            endcase;

        let c = lookup.k ? k : d;

        // Determine if the current character changes the running disparity, which happens when one
        // of the blocks is not neutral. If both are either neutral or not neutral the running
        // disparity remains unchanged.
        //
        // Note: Bluespec does not have a logic XOR operation, so use a bitwise XOR instead.
        let flip_rd = unpack(pack(lookup.blocks.x.neutral) ^ pack(lookup.blocks.y.neutral));

        rd <= flip_rd ? unpack(~pack(rd)) : rd;
        character_result.enq(lookup.valid ? tagged Valid(c) : tagged Invalid(c));
    endrule

    interface Put value;
        method Action put(Value v);
            lookup_result.enq(lookup_blocks(v));
        endmethod
    endinterface

    interface Get character = toGet(character_result);
    method running_disparity = rd._read;

endmodule: mkEncoder

module mkSerializer (Serializer);
    Encoder encoder <- mkEncoder();

    Reg#(Character) buffer <- mkRegU();
    Reg#(UInt#(4)) bits_in_buffer <- mkRegA(0);

    Reg#(Bool) encoding_error_ <- mkRegA(False);
    Reg#(Bool) last_call_ <- mkRegA(True);

    PulseWire shift_buffer <- mkPulseWire();
    PulseWire invalid_result <- mkPulseWire();
    PulseWire set_last_call <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_get_character (bits_in_buffer == 0 || (bits_in_buffer == 1 && shift_buffer));
        let c <- encoder.character.get();

        buffer <= character_result_bits(c);
        bits_in_buffer <= 10;

        if (!result_valid(c)) begin
            invalid_result.send();
        end
    endrule

    (* descending_urgency = "do_get_character, do_shift_out" *)
    rule do_shift_out (bits_in_buffer != 0 && shift_buffer);
        buffer <= {1'b0, buffer[9:1]};
        bits_in_buffer <= bits_in_buffer == 0 ? 0 : bits_in_buffer - 1;

        if (bits_in_buffer == 4) begin
            set_last_call.send();
        end
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set_encoding_error;
        encoding_error_ <= invalid_result;
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set_last_call;
        last_call_ <= set_last_call;
    endrule

    interface Put in = encoder.value;

    interface Get out;
        method ActionValue#(Bit#(1)) get() if (bits_in_buffer != 0);
            shift_buffer.send();
            return buffer[0];
        endmethod
    endinterface

    method encoding_error = encoding_error_._read;
    method last_call = last_call_._read;
endmodule: mkSerializer

endpackage: Encoder8b10b

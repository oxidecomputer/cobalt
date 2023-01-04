// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package TMDS;

export Character, Input(..);
export Encoder(..), mkEncoder, mkFasterEncoder;

import GetPut::*;
import StmtFSM::*;
import Vector::*;

import TestUtils::*;


typedef union tagged {
    Bit#(2) Control;
    Bit#(4) Data;
    Bit#(8) Pixel;
    Character Guard;
} Input deriving (Bits, FShow);

typedef Bit#(10) Character;

interface Encoder;
    interface Put#(Input) data;
    interface Get#(Character) character;
    method Action clear();
endinterface

typedef union tagged {
    Character Character;
    pixel_result Pixel;
} Result#(type pixel_result) deriving (Bits, FShow);

function Character encode_ctl(Bit#(2) val) =
    case (val)
        'b00: 'b11010_10100;
        'b01: 'b00101_01011;
        'b10: 'b01010_10100;
        'b11: 'b10101_01011;
    endcase;

function Character encode_data(Bit#(4) val) =
    case (val)
        'b0000: 'b10100_11100;
        'b0001: 'b10011_00011;
        'b0010: 'b10111_00100;
        'b0011: 'b10111_00010;
        'b0100: 'b01011_10001;
        'b0101: 'b01000_11110;
        'b0110: 'b01100_01110;
        'b0111: 'b01001_11100;
        'b1000: 'b10110_01100;
        'b1001: 'b01001_11001;
        'b1010: 'b01100_11100;
        'b1011: 'b10110_00110;
        'b1100: 'b10100_01110;
        'b1101: 'b10011_10001;
        'b1110: 'b01011_00011;
        'b1111: 'b10110_00011;
    endcase;

function Bit#(9) xor_xnor(Bit#(8) d, Bool do_xnor);
    let q0 = d[0];
    let q1 = do_xnor? ~(q0 ^ d[1]) : (q0 ^ d[1]);
    let q2 = do_xnor? ~(q1 ^ d[2]) : (q1 ^ d[2]);
    let q3 = do_xnor? ~(q2 ^ d[3]) : (q2 ^ d[3]);
    let q4 = do_xnor? ~(q3 ^ d[4]) : (q3 ^ d[4]);
    let q5 = do_xnor? ~(q4 ^ d[5]) : (q4 ^ d[5]);
    let q6 = do_xnor? ~(q5 ^ d[6]) : (q5 ^ d[6]);
    let q7 = do_xnor? ~(q6 ^ d[7]) : (q6 ^ d[7]);
    return {do_xnor? 0 : 1, q7, q6, q5, q4, q3, q2, q1, q1};
endfunction

module mkEncoder (Encoder);
    Reg#(Int#(5)) cnt <- mkRegU();

    // Input data.
    Wire#(Input) d <- mkWire();

    Reg#(Result#(Bit#(9))) q_m <- mkRegU();
    Reg#(Character) q_out <- mkRegU();

    // Valid bit for each stage. A bit at index 0 indicates a valid character.
    Reg#(Vector#(2, Bool)) stage_valid <- mkReg(replicate(False));

    // Pulse between Get and Put interfaces, indicating a character was dequeued and a new data
    // item can be shifted in.
    PulseWire deq <- mkPulseWire();

    PulseWire should_clear <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_encode;
        stage_valid <= shiftInAtN(stage_valid, True);

        q_m <= case (d) matches
            tagged Control .val: tagged Character encode_ctl(val);
            tagged Data .val: tagged Character encode_data(val);
            tagged Guard .val: tagged Character val;

            tagged Pixel .val: begin
                let ones = countOnes(val);

                if ((ones > 4) || (ones == 4 && val[0] == 0)) begin
                    tagged Pixel xor_xnor(val, True);
                end else begin
                    tagged Pixel xor_xnor(val, False);
                end
            end
        endcase;

        case (q_m) matches
            tagged Character .c: begin
                q_out <= c;
                cnt <= 0;
            end

            tagged Pixel .q_m: begin
                Int#(5) zeros = unpack(pack(extend(countZerosLSB(q_m[7:0]))));
                Int#(5) ones = unpack(pack(extend(countOnes(q_m[7:0]))));

                Int#(5) ones_minus_zeros = ones - zeros;
                Int#(5) zeros_minus_ones = zeros - ones;

                let ones_gt_zeros = msb(zeros_minus_ones) == 1;
                let ones_eq_zeros = ones == 0;
                let ones_lt_zeros = msb(ones_minus_zeros) == 1;

                if (cnt == 0 || ones_eq_zeros) begin
                    if (q_m[8] == 0) begin
                        q_out <= {2'b10, ~q_m[7:0]};
                        cnt <= cnt + ones_minus_zeros;
                    end else begin
                        q_out <= {2'b01, q_m[7:0]};
                        cnt <= cnt + zeros_minus_ones;
                    end
                end else begin
                    if ((cnt > 0 && ones_gt_zeros) || (cnt < 0 && ones_lt_zeros)) begin
                        q_out <= {1, q_m[8], ~q_m[7:0]};
                        cnt <= cnt + (q_m[8] == 1? 2 : 0) + zeros_minus_ones;
                    end else begin
                        q_out <= {0, q_m[8], q_m[7:0]};
                        cnt <= cnt - (q_m[8] == 1? 0 : 2) + ones_minus_zeros;
                    end
                end
            end
        endcase
    endrule

    interface Put data;
        method put if (deq || !stage_valid[0]) = d._write;
    endinterface

    interface Get character;
        method ActionValue#(Character) get() if (stage_valid[0]);
            deq.send();
            return q_out;
        endmethod
    endinterface

    method Action clear();
        stage_valid <= replicate(False);
    endmethod
endmodule: mkEncoder

module mkEncoderTest (Empty);
    Encoder e <- mkEncoder();

    mkAutoFSM(seq
        e.data.put(tagged Control 'b00);
        e.data.put(tagged Data 'b0000);
        e.data.put(tagged Guard 'b1011001100);
        e.data.put(tagged Pixel 'd235);
        e.data.put(tagged Control 'b01);
        e.data.put(tagged Control 'b11);
    endseq);

    mkAutoFSM(seq
        assert_get_eq_display(e.character, 'b11010_10100, "Expected control character");
        assert_get_eq_display(e.character, 'b10100_11100, "Expected TERC4 character");
        assert_get_eq_display(e.character, 'b10110_01100, "Expected guard band character");
        assert_get_eq_display(e.character, 'b10000_01100, "Expected pixel character");
    endseq);
endmodule: mkEncoderTest

//
// A faster TMDS encoder targeting >165M pixels/s on a Lattice ECP5 FPGA. This comes at the expense
// of requiring five cycles to encode incoming pixel data.
//
module mkFasterEncoder (Encoder);
    Reg#(Int#(5)) cnt <- mkRegU();

    // Input data.
    Wire#(Input) d <- mkWire();

    // Intermediate result stages.
    Reg#(Result#(Tuple3#(UInt#(4), Bit#(9), Bit#(9)))) q_m_pre <- mkRegU();
    Reg#(Result#(Bit#(9))) q_m <- mkRegU();
    Reg#(Result#(Tuple3#(Int#(5), Int#(5), Bit#(9)))) q_out_pre1 <- mkRegU();
    Reg#(Result#(Tuple4#(Int#(5), Int#(5), Bool, Bit#(9)))) q_out_pre2 <- mkRegU();

    // Resulting character.
    Reg#(Character) q_out <- mkRegU();

    // Valid bit for each stage. A bit at index 0 indicates a valid character.
    Reg#(Vector#(5, Bool)) stage_valid <- mkReg(replicate(False));

    // Pulse between Get and Put interfaces, indicating a character was dequeued and a new data
    // item can be shifted in.
    PulseWire deq <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_encode;
        stage_valid <= shiftInAtN(stage_valid, True);

        // Step 1
        q_m_pre <= case (d) matches
            tagged Control .val: tagged Character encode_ctl(val);
            tagged Data .val: tagged Character encode_data(val);
            tagged Pixel .val:
                // Calculate the number of ones in D, as well as the XOR/XNOR values.
                tagged Pixel tuple3(countOnes(val), xor_xnor(val, True), xor_xnor(val, False));
            tagged Guard .val: tagged Character val;
        endcase;

        // Step 2
        q_m <= case (q_m_pre) matches
            tagged Character .c: tagged Character c;

            // Determine q_m.
            tagged Pixel {.ones, .xnored, .xored}: begin
                if ((ones > 4) || (ones == 4 && xored[0] == 0)) begin
                    tagged Pixel xnored;
                end else begin
                    tagged Pixel xored;
                end
            end
        endcase;

        // Step 3
        q_out_pre1 <= case (q_m) matches
            tagged Character .c: tagged Character c;

            // Determine the number of ones and zeros in q_m.
            tagged Pixel .q_m: begin
                let zeros = unpack(pack(extend(countZerosLSB(q_m[7:0]))));
                let ones = unpack(pack(extend(countOnes(q_m[7:0]))));
                tagged Pixel tuple3(ones, zeros, q_m);
            end
        endcase;

        // Step 4
        q_out_pre2 <= case (q_out_pre1) matches
            tagged Character .c: tagged Character c;

            // Determine the differences in ones and zeros in q_m.
            tagged Pixel {.ones, .zeros, .q_m}:
                tagged Pixel tuple4(ones - zeros, zeros - ones, ones == zeros, q_m);
        endcase;

        // Step 5
        case (q_out_pre2) matches
            tagged Character .c: begin
                cnt <= 0;
                q_out <= c;
            end

            // Determine q_out, update cnt.
            tagged Pixel {.ones_minus_zeros, .zeros_minus_ones, .ones_eq_zeros, .q_m}: begin
                let ones_gt_zeros = msb(zeros_minus_ones) == 1;
                let ones_lt_zeros = msb(ones_minus_zeros) == 1;

                if (cnt == 0 || ones_eq_zeros) begin
                    if (q_m[8] == 0) begin
                        q_out <= {2'b10, ~q_m[7:0]};
                        cnt <= cnt + ones_minus_zeros;
                    end else begin
                        q_out <= {2'b01, q_m[7:0]};
                        cnt <= cnt + zeros_minus_ones;
                    end
                end else begin
                    if ((cnt > 0 && ones_gt_zeros) || (cnt < 0 && ones_lt_zeros)) begin
                        q_out <= {1, q_m[8], ~q_m[7:0]};
                        cnt <= cnt + (q_m[8] == 1? 2 : 0) + zeros_minus_ones;
                    end else begin
                        q_out <= {0, q_m[8], q_m[7:0]};
                        cnt <= cnt - (q_m[8] == 1? 0 : 2) + ones_minus_zeros;
                    end
                end
            end
        endcase
    endrule

    interface Put data;
        method put if (deq || !stage_valid[0]) = d._write;
    endinterface

    interface Get character;
        method ActionValue#(Character) get() if (stage_valid[0]);
            deq.send();
            return q_out;
        endmethod
    endinterface

    method Action clear();
        stage_valid <= replicate(False);
    endmethod
endmodule: mkFasterEncoder

endpackage: TMDS

// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Encoding8b10bTests;

import StmtFSM::*;

import Encoding8b10b::*;
import Encoding8b10bReference::*;
import TestUtils::*;


// Encode all valid Values using the `encode(..)` functions from both packages,
// comparing their results.
module mkEncodeTest (Empty);
    Reg#(Bit#(9)) i <- mkReg(0);
    Wire#(Value) value <- mkWire();
    Wire#(RunningDisparity) rd <- mkWire();

    // The results between the two encode functions may differ for invalid K
    // characters. So only test/compare the results for valid values.
    (* fire_when_enabled *)
    rule do_encode_and_compare (is_d(value) || valid_k(value));
        let expected = Encoding8b10bReference::encode(value, rd);
        let actual = Encoding8b10b::encode(value, rd);

        $display(fshow(value), " ", fshow(expected), " ", fshow(actual));
        assert_eq(actual, expected, "expected results to be equal");
    endrule

    function Action test_value(Value value_, RunningDisparity rd_) =
        action
            value <= value_;
            rd <= rd_;
        endaction;

    // For all possible values and running disparity, compare their encoding
    // result with the reference table.
    mkAutoFSM(seq
        for (i <= 0; i < 256; i <= i + 1) test_value(tagged D truncate(i), RunningNegative);
        for (i <= 0; i < 255; i <= i + 1) test_value(tagged D truncate(i), RunningPositive);
        for (i <= 0; i < 255; i <= i + 1) test_value(tagged K truncate(i), RunningNegative);
        for (i <= 0; i < 255; i <= i + 1) test_value(tagged K truncate(i), RunningPositive);
    endseq);
endmodule

// Encode all valid values using the reference encoder and decode the result
// using the `decode(..)` function. The decoded value and running disparity
// should match the `encode(..)` inputs. This is no guarantee the `decode(..)`
// function will always return correct results, but it demonstrates it will
// correctly decode the results of a valid encoder.
module mkEncodeDecodeTest (Empty);
    Reg#(Bit#(9)) i <- mkReg(0);
    Wire#(Value) value <- mkWire();
    Wire#(RunningDisparity) rd <- mkWire();

    (* fire_when_enabled *)
    rule d_encode_decode_and_compare (is_d(value) || valid_k(value));
        let encode_result = Encoding8b10bReference::encode(value, rd);

        case (encode_result.character) matches
            tagged Invalid .*: assert_fail("expected character valid");
            tagged Valid .c: begin
                let decode_result = decode(c, rd);

                $display(
                    fshow(value), " ",
                    fshow(rd), " ",
                    fshow(encode_result), " ",
                    fshow(decode_result));

                case (decode_result.value) matches
                    tagged Invalid .*: assert_fail("expected value valid");
                    tagged Valid .decoded_value:
                        assert_eq(
                            decoded_value,
                            value,
                            "expected orginal value and decoded value to be equal");
                endcase

                case (decode_result.rd) matches
                    tagged Invalid:
                        assert_fail("expected running disparity valid");
                    tagged Valid .decoded_rd:
                        assert_eq(
                            decoded_rd,
                            encode_result.rd,
                            "expected disparity of decoder to follow encoder");
                endcase
            end
        endcase
    endrule

    function Action test_value(Value value_, RunningDisparity rd_) =
        action
            value <= value_;
            rd <= rd_;
        endaction;

    // For all possible values and running disparity, compare the encode/decode
    // results.
    mkAutoFSM(seq
        for (i <= 0; i < 256; i <= i + 1) test_value(tagged D truncate(i), RunningNegative);
        for (i <= 0; i < 255; i <= i + 1) test_value(tagged D truncate(i), RunningPositive);
        for (i <= 0; i < 255; i <= i + 1) test_value(tagged K truncate(i), RunningNegative);
        for (i <= 0; i < 255; i <= i + 1) test_value(tagged K truncate(i), RunningPositive);
    endseq);
endmodule

endpackage

// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Decoder8b10b;

export mkDecoder;
export Idle(..), mkDeserializer;

import FIFO::*;
import GetPut::*;
import Probe::*;
import SpecialFIFOs::*;

import Encoding8b10b::*;


typedef enum {
    Neutral = 0,
    Positive,
    Negative
} Disparity deriving (Bits, Eq, FShow);

typedef struct {
    Disparity disparity;
    Bit#(t) value;
} BlockValue#(numeric type t) deriving (Bits, FShow);

typedef struct {
    Bool is_k;
    Maybe#(RunningDisparity) expected_rd;
    Maybe#(BlockValue#(5)) x;
    Maybe#(BlockValue#(3)) y;
} LookupResult deriving (Bits, FShow);

function Maybe#(BlockValue#(5)) lookup_x(Character c) =
    case (c[5:0])
        'b111001: tagged Valid BlockValue{value: 0,  disparity: Positive};
        'b000110: tagged Valid BlockValue{value: 0,  disparity: Negative};
        'b101110: tagged Valid BlockValue{value: 1,  disparity: Positive};
        'b010001: tagged Valid BlockValue{value: 1,  disparity: Negative};
        'b101101: tagged Valid BlockValue{value: 2,  disparity: Positive};
        'b010010: tagged Valid BlockValue{value: 2,  disparity: Negative};
        'b100011: tagged Valid BlockValue{value: 3,  disparity: Neutral};
        'b101011: tagged Valid BlockValue{value: 4,  disparity: Positive};
        'b010100: tagged Valid BlockValue{value: 4,  disparity: Negative};
        'b100101: tagged Valid BlockValue{value: 5,  disparity: Neutral};
        'b100110: tagged Valid BlockValue{value: 6,  disparity: Neutral};
        'b000111: tagged Valid BlockValue{value: 7,  disparity: Neutral};
        'b111000: tagged Valid BlockValue{value: 7,  disparity: Neutral};
        'b100111: tagged Valid BlockValue{value: 8,  disparity: Positive};
        'b011000: tagged Valid BlockValue{value: 8,  disparity: Negative};
        'b101001: tagged Valid BlockValue{value: 9,  disparity: Neutral};
        'b101010: tagged Valid BlockValue{value: 10, disparity: Neutral};
        'b001011: tagged Valid BlockValue{value: 11, disparity: Neutral};
        'b101100: tagged Valid BlockValue{value: 12, disparity: Neutral};
        'b001101: tagged Valid BlockValue{value: 13, disparity: Neutral};
        'b001110: tagged Valid BlockValue{value: 14, disparity: Neutral};
        'b111010: tagged Valid BlockValue{value: 15, disparity: Positive};
        'b000101: tagged Valid BlockValue{value: 15, disparity: Negative};
        'b110110: tagged Valid BlockValue{value: 16, disparity: Positive};
        'b001001: tagged Valid BlockValue{value: 16, disparity: Negative};
        'b110001: tagged Valid BlockValue{value: 17, disparity: Neutral};
        'b110010: tagged Valid BlockValue{value: 18, disparity: Neutral};
        'b010011: tagged Valid BlockValue{value: 19, disparity: Neutral};
        'b110100: tagged Valid BlockValue{value: 20, disparity: Neutral};
        'b010101: tagged Valid BlockValue{value: 21, disparity: Neutral};
        'b010110: tagged Valid BlockValue{value: 22, disparity: Neutral};
        'b010111: tagged Valid BlockValue{value: 23, disparity: Positive};
        'b101000: tagged Valid BlockValue{value: 23, disparity: Negative};
        'b110011: tagged Valid BlockValue{value: 24, disparity: Positive};
        'b001100: tagged Valid BlockValue{value: 24, disparity: Negative};
        'b011001: tagged Valid BlockValue{value: 25, disparity: Neutral};
        'b011010: tagged Valid BlockValue{value: 26, disparity: Neutral};
        'b011011: tagged Valid BlockValue{value: 27, disparity: Positive};
        'b100100: tagged Valid BlockValue{value: 27, disparity: Negative};
        'b011100: tagged Valid BlockValue{value: 28, disparity: Neutral};
        'b111100: tagged Valid BlockValue{value: 28, disparity: Positive};
        'b000011: tagged Valid BlockValue{value: 28, disparity: Negative};
        'b011101: tagged Valid BlockValue{value: 29, disparity: Positive};
        'b100010: tagged Valid BlockValue{value: 29, disparity: Negative};
        'b011110: tagged Valid BlockValue{value: 30, disparity: Positive};
        'b100001: tagged Valid BlockValue{value: 30, disparity: Negative};
        'b110101: tagged Valid BlockValue{value: 31, disparity: Positive};
        'b001010: tagged Valid BlockValue{value: 31, disparity: Negative};
        default: tagged Invalid;
    endcase;

function Maybe#(BlockValue#(3)) lookup_dy(Character c) =
    case (c[9:6])
        'b0010: tagged Valid BlockValue{value: 0, disparity: Negative};
        'b1101: tagged Valid BlockValue{value: 0, disparity: Positive};
        'b1001: tagged Valid BlockValue{value: 1, disparity: Neutral};
        'b1010: tagged Valid BlockValue{value: 2, disparity: Neutral};
        'b1100: tagged Valid BlockValue{value: 3, disparity: Neutral};
        'b0011: tagged Valid BlockValue{value: 3, disparity: Neutral};
        'b0100: tagged Valid BlockValue{value: 4, disparity: Negative};
        'b1011: tagged Valid BlockValue{value: 4, disparity: Positive};
        'b0101: tagged Valid BlockValue{value: 5, disparity: Neutral};
        'b0110: tagged Valid BlockValue{value: 6, disparity: Neutral};
        'b1000: tagged Valid BlockValue{value: 7, disparity: Negative};
        'b0111: tagged Valid BlockValue{value: 7, disparity: Positive};
        'b0001: tagged Valid BlockValue{value: 7, disparity: Negative};
        'b1110: tagged Valid BlockValue{value: 7, disparity: Positive};
        default: tagged Invalid;
    endcase;

function Maybe#(BlockValue#(3)) lookup_ky(Character c, Bool k28y_rdn) =
    case (c[9:6])
        'b0010: tagged Valid BlockValue{value: 0, disparity: Negative};
        'b1101: tagged Valid BlockValue{value: 0, disparity: Positive};
        'b1001: (k28y_rdn ?
                tagged Valid BlockValue{value: 1, disparity: Neutral} :
                tagged Valid BlockValue{value: 6, disparity: Neutral});
        'b0110: (k28y_rdn ?
                tagged Valid BlockValue{value: 6, disparity: Neutral} :
                tagged Valid BlockValue{value: 1, disparity: Neutral});
        'b1010: (k28y_rdn ?
                tagged Valid BlockValue{value: 2, disparity: Neutral} :
                tagged Valid BlockValue{value: 5, disparity: Neutral});
        'b0101: (k28y_rdn ?
                tagged Valid BlockValue{value: 5, disparity: Neutral} :
                tagged Valid BlockValue{value: 2, disparity: Neutral});
        'b0011: tagged Valid BlockValue{value: 3, disparity: Neutral};
        'b1100: tagged Valid BlockValue{value: 3, disparity: Neutral};
        'b0100: tagged Valid BlockValue{value: 4, disparity: Negative};
        'b1011: tagged Valid BlockValue{value: 4, disparity: Positive};
        'b0001: tagged Valid BlockValue{value: 7, disparity: Negative};
        'b1110: tagged Valid BlockValue{value: 7, disparity: Positive};
        default: tagged Invalid;
    endcase;

module mkDecoder (Decoder);
    Reg#(Maybe#(RunningDisparity)) rd <- mkRegA(tagged Invalid);
    Wire#(Maybe#(RunningDisparity)) _rd <- mkDWire(tagged Invalid);
    FIFO#(LookupResult) lookup_result <- mkPipelineFIFO();
    FIFO#(ValueResult) value_result <- mkPipelineFIFO();

    function Action lookup_block_values(Bit#(10) c) =
        action
            $display(fmt_character(c));

            // Determine if character is a control code.
            let k28y_if_rdn = c[5:2] == 'b1111;
            let k28y_if_rdp = c[5:2] == 'b0000;
            let k_if_rdn = k28y_if_rdn || c[9:4] == 'b000101;
            let k_if_rdp = k28y_if_rdp || c[9:4] == 'b111010;
            let is_k = k_if_rdn || k_if_rdp;

            // Lookup code blocks.
            let x = lookup_x(c);
            let ky = lookup_ky(c, k28y_if_rdn);
            let dy = lookup_dy(c);

            // Determine if the decoder should have a given running disparity.
            Maybe#(RunningDisparity) expected_rd_if_k =
                tagged Valid (k_if_rdn ? RunningNegative : RunningPositive);

            Maybe#(RunningDisparity) expected_rd_if_d =
                case (c)
                    'b0011_000111: tagged Valid RunningNegative;
                    'b1100_111000: tagged Valid RunningPositive;
                    default: tagged Invalid;
                endcase;

            lookup_result.enq(
                LookupResult{
                    is_k: is_k,
                    expected_rd: is_k ? expected_rd_if_k : expected_rd_if_d,
                    x: x,
                    y: is_k ? ky : dy});
        endaction;

    (* fire_when_enabled *)
    rule do_decode;
        let result = lookup_result.first();
        lookup_result.deq();

        if (result.x matches tagged Valid .x &&& result.y matches tagged Valid .y) begin
            Maybe#(RunningDisparity) next_rd =
                case (tuple3(rd, x.disparity, y.disparity)) matches
                    // If the running disparity is unknown it can be reliably recovered if a
                    // non-neutral disparity x or y block is received. This is how the decoder will
                    // synchronize with an encoder.
                    {tagged Invalid, Positive, Neutral}: tagged Valid RunningPositive;
                    {tagged Invalid, Neutral, Positive}: tagged Valid RunningPositive;
                    {tagged Invalid, Negative, Neutral}: tagged Valid RunningNegative;
                    {tagged Invalid, Neutral, Negative}: tagged Valid RunningNegative;
                    {tagged Invalid, Positive, Negative}: tagged Valid RunningNegative;
                    {tagged Invalid, Negative, Positive}: tagged Valid RunningPositive;

                    // Check against negative running disparity, flipping the disparity if required.
                    {tagged Valid RunningNegative, Positive, Neutral}: tagged Valid RunningPositive;
                    {tagged Valid RunningNegative, Neutral, Positive}: tagged Valid RunningPositive;
                    {tagged Valid RunningNegative, Positive, Negative}: rd;
                    {tagged Valid RunningNegative, Negative, Positive}: rd;
                    {tagged Valid RunningNegative, Neutral, Neutral}: rd;

                    // Check against positive running disparity, flipping the disparity if required.
                    {tagged Valid RunningPositive, Negative, Neutral}: tagged Valid RunningNegative;
                    {tagged Valid RunningPositive, Neutral, Negative}: tagged Valid RunningNegative;
                    {tagged Valid RunningPositive, Positive, Negative}: rd;
                    {tagged Valid RunningPositive, Negative, Positive}: rd;
                    {tagged Valid RunningPositive, Neutral, Neutral}: rd;

                    // Remaining combinations are either invalid given the current running disparity
                    // or the running disparity is not known and the character is neutral.
                    default: tagged Invalid;
                endcase;

            // When decoding a K value, only test running disparity iff the decoder is already
            // tracking an encoder.
            //
            // If we were to always test against the running disparity it would be difficult to
            // start tracking an encoder since comma characters are encoded as K values. Higher
            // layer protocols purposefully require frequent transmission of comma characters in
            // order to aid receiver synchronization. Data characters would eventually synchronize
            // the decoder, but this would result in needlessly poor performance.
            //
            // The downside of assuming good intent for K characters when the decoder is not
            // synchronized is that if bit errors occur which result in erroneous received K
            // characters, the decoder may start tracking with the wrong disparity. But subsequent
            // characters are likely to then violate the running disparity, causing a reset. A bit
            // of hysteresis by a receiver using this decoder should resolve that and avoid invalid
            // values being passed to higher layer protocols.
            let expected_rd_violation_if_k = isValid(rd) && rd != result.expected_rd;

            // Only test against expected_rd iff valid.
            let expected_rd_violation_if_d =
                isValid(result.expected_rd) && rd != result.expected_rd;

            let expected_rd_violation = result.is_k ?
                expected_rd_violation_if_k :
                expected_rd_violation_if_d;

            let mk_value = result.is_k ? mk_d : mk_d;

            if (isValid(next_rd) && !expected_rd_violation) begin
                value_result.enq(tagged Valid mk_value(x.value, y.value));
                rd <= next_rd;
            end else begin
                value_result.enq(tagged Invalid({y.value, x.value}));
                rd <= tagged Invalid;
            end
        end else begin
            // Either one or both of the received x and y blocks was invalid. Return an invalid
            // result with whatever bits we can recover or zeros if the received character was total
            // garbage.
            value_result.enq(Invalid({
                fromMaybe(BlockValue{value: 0, disparity: ?}, result.y).value,
                fromMaybe(BlockValue{value: 0, disparity: ?}, result.x).value}));
            rd <= tagged Invalid;
        end
    endrule

    // Set the wire driving running_disparity().
    (* no_implicit_conditions, fire_when_enabled *)
    rule do_write_rd;
        _rd <= rd;
    endrule

    interface Put character;
        method put = lookup_block_values;
    endinterface

    interface Get value = toGet(value_result);
    method running_disparity = _rd._read;

endmodule : mkDecoder

typedef enum {
    IdleLow,
    IdleHigh
} Idle deriving (Bits, Eq, FShow);

typedef enum {
    AwaitingFirstComma = 0,
    AwaitingSecondComma,
    AwaitingDecoderLocked,
    AwaitingSufficientCharactersValid,
    Decoding
} DeserializerState deriving (Bits, Eq, FShow);

module mkDeserializer #(Idle idle) (Deserializer);
    Decoder decoder <- mkDecoder();
    Reg#(DeserializerState) state <- mkRegA(AwaitingFirstComma);

    // A bit vector indicating which of the last n characters were valid.
    Reg#(Bit#(6)) decoded_value_valid_history <- mkRegA('0);
    // Shift buffer to go from serial to parallel and decoder alignment.
    Reg#(Character) shift_buffer <- mkRegA(idle == IdleHigh ? '1 : '0);
    // A counter keeping track of the number of bits still needed for the next full character.
    Reg#(UInt#(4)) bits_until_next_character <- mkRegU();

    // Output bit indicating whether or not there is bit activity on the link. This can be used to
    // detect the absence/presence of an encoder.
    Reg#(Bool) activity_detected_ <- mkRegA(False);
    // Output bit indicating whether or not the deserializer is locked to an encoder.
    Reg#(Bool) locked_ <- mkRegA(False);

    // Events.
    RWire#(Bit#(1)) next_bit <- mkRWire();
    RWire#(Bool) decoded_value_valid <- mkRWire();
    PulseWire no_link_activity <- mkPulseWire();
    PulseWire comma_received <- mkPulseWire();

    function Bool awaiting_comma =
        case (state)
            AwaitingFirstComma: True;
            AwaitingSecondComma: True;
            default: False;
        endcase;

    function Bool link_idle = shift_buffer == (idle == IdleHigh ? '1 : '0);

    function Bool comma_in_buffer =
        shift_buffer[6:0] == 7'b1111100 ||
        shift_buffer[6:0] == 7'b0000011;

    function Action set_state(DeserializerState s) =
        action
            $display(fshow(s));
            state <= s;
            locked_ <= s == Decoding;
        endaction;

    function Action shift_in(Bit#(1) b) =
        action
            shift_buffer <= {b, shift_buffer[9:1]};
        endaction;

    (* fire_when_enabled, no_implicit_conditions *)
    rule do_set_state;
        // Update decode valid history. Note that the the updated history is not considered until
        // the next cycle.
        if (decoded_value_valid.wget() matches tagged Valid .is_valid) begin
            decoded_value_valid_history <= {decoded_value_valid_history[4:0], pack(is_valid)};
        end

        let too_many_invalid_characters =
            // The past four characters received were invalid.
            decoded_value_valid_history[3:0] == '0 ||
            // Five out of the past six characters received were invalid.
            countOnes(decoded_value_valid_history) < 2;

        let suffucient_valid_characters =
            // The past four characters received were valid.
            decoded_value_valid_history[3:0] == '1;

        let decoder_locked = isValid(decoder.running_disparity());

        if (state == Decoding && too_many_invalid_characters)
            set_state(AwaitingFirstComma);
        else if (state == AwaitingFirstComma && comma_received)
            set_state(AwaitingSecondComma);
        else if (state == AwaitingSecondComma && comma_received)
            set_state(AwaitingDecoderLocked);
        else if (state == AwaitingDecoderLocked && decoder_locked)
            set_state(AwaitingSufficientCharactersValid);
        else if (state == AwaitingSufficientCharactersValid && suffucient_valid_characters)
            set_state(Decoding);
    endrule

    (* fire_when_enabled *)
    rule do_receive_bit_and_decode_character (!awaiting_comma() && bits_until_next_character == 0);
        decoder.character.put(shift_buffer);

        if (next_bit.wget() matches tagged Valid .b) begin
            shift_in(b);

            if (link_idle()) begin
                no_link_activity.send();
            end

            if (comma_in_buffer()) begin
                $display("Comma");
                comma_received.send();
            end

            bits_until_next_character <= 9;
        end else begin
            bits_until_next_character <= 10;
        end
    endrule

    (* descending_urgency = "do_receive_bit_and_decode_character, do_receive_bit" *)
    rule do_receive_bit (next_bit.wget() matches tagged Valid .b);
        shift_in(b);

        if (link_idle()) begin
            no_link_activity.send();
        end

        if (comma_in_buffer()) begin
            $display("Comma");
            comma_received.send();
        end

        if (comma_in_buffer() || bits_until_next_character == 0)
            // If "do_receive_bit_and_decode_character" does not fire because the receiver is
            // searching for comma characters or because the encoder pipeline has stalled, the
            // buffer contents should be dropped. Failure to do so while the decoder is in
            // "Decoding" state would cause the encoder/decoder to go out of sync.
            bits_until_next_character <= 9;
        else
            bits_until_next_character <= bits_until_next_character - 1;
    endrule

    (* fire_when_enabled *)
    rule do_discard_result (state != Decoding);
        let r <- decoder.value.get();
        decoded_value_valid.wset(result_valid(r));
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_set_activity_detected;
        activity_detected_ <= !no_link_activity;
    endrule

    interface Put in = toPut(next_bit);

    interface Get out;
        method ActionValue#(ValueResult) get() if (state == Decoding);
            let r <- decoder.value.get();
            decoded_value_valid.wset(result_valid(r));
            return r;
        endmethod
    endinterface

    method activity_detected = activity_detected_._read;
    method locked = locked_._read;
endmodule

endpackage : Decoder8b10b

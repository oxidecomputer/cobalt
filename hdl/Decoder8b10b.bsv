package Decoder8b10b;

export mkDecoder;

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
    Maybe#(BlockValue#(5)) x;
    Maybe#(BlockValue#(3)) y;
    Maybe#(RunningDisparity) expected_rd;
} LookupResult deriving (Bits, FShow);

typedef union tagged {
    LookupResult K;
    LookupResult D;
} TypedLookupResult deriving (Bits, FShow);

function Maybe#(BlockValue#(5)) lookup_x(Character _c) =
    case (_c[5:0])
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

function Maybe#(BlockValue#(3)) lookup_dy(Character _c) =
    case (_c[9:6])
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

function Maybe#(BlockValue#(3)) lookup_ky(Character _c, Bool k28y_rdn) =
    case (_c[9:6])
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
    FIFO#(TypedLookupResult) lookup_result <- mkPipelineFIFO();
    FIFO#(ValueResult) value_result <- mkPipelineFIFO();

    function Action lookup_block_values(Bit#(10) c) =
        action
            $display(fmt_character(c));

            // Determine if character is a control code.
            let k28y_if_rdn = c[5:2] == 'b1111;
            let k28y_if_rdp = c[5:2] == 'b0000;
            let k_if_rdn = k28y_if_rdn || c[9:4] == 'b000101;
            let k_if_rdp = k28y_if_rdp || c[9:4] == 'b111010;

            // Lookup code blocks.
            let x = lookup_x(c);
            let ky = lookup_ky(c, k28y_if_rdn);
            let dy = lookup_dy(c);

            Maybe#(RunningDisparity) expected_rd =
                case (c)
                    'b0011_000111: tagged Valid RunningNegative;
                    'b1100_111000: tagged Valid RunningPositive;
                    default: tagged Invalid;
                endcase;

            lookup_result.enq(
                (k_if_rdn || k_if_rdp) ?
                tagged K LookupResult{
                    x: x,
                    y: ky,
                    expected_rd: tagged Valid (k_if_rdn ? RunningNegative : RunningPositive)} :
                tagged D LookupResult{
                    x: x,
                    y: dy,
                    expected_rd: expected_rd});
        endaction;

    function Action set_value_result_if_valid(
            BlockValue#(5) x,
            BlockValue#(3) y,
            Bool expected_rd_violation,
            function Value mk_value(Bit#(5) x, Bit#(3) y)) =
        action
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

                    // Check against positive running disparity, flipping the disparity if required.
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


            if (isValid(next_rd) && !expected_rd_violation) begin
                value_result.enq(tagged Valid mk_value(x.value, y.value));
                rd <= next_rd;
            end else begin
                value_result.enq(tagged Invalid({y.value, x.value}));
                rd <= tagged Invalid;
            end
        endaction;

    function Action set_invalid_value_result(Maybe#(BlockValue#(5)) x, Maybe#(BlockValue#(3)) y) =
        action
            let x_zero = BlockValue{value: 5'b0, disparity: ?};
            let y_zero = BlockValue{value: 3'b0, disparity: ?};

            value_result.enq(Invalid({
                fromMaybe(y_zero, y).value,
                fromMaybe(x_zero, x).value}));
            rd <= tagged Invalid;
        endaction;

    // Test for an RD violation if decoding a D value.
    function Bool check_rd_violation(Maybe#(RunningDisparity) expected_rd) =
        isValid(expected_rd) && rd != expected_rd;

    // Test for an RD violation if decoding a K value.
    function Bool check_rd_violation_if_k(Maybe#(RunningDisparity) expected_rd) =
        isValid(rd) && rd != expected_rd;

    (* fire_when_enabled *)
    rule do_decode_k (
            lookup_result.first() matches tagged K .r &&&
            r.x matches tagged Valid .x &&&
            r.y matches tagged Valid .y);
        lookup_result.deq();
        set_value_result_if_valid(x, y, check_rd_violation_if_k(r.expected_rd), mk_k);
    endrule

    (* fire_when_enabled *)
    rule do_decode_d (
            lookup_result.first() matches tagged D .r &&&
            r.x matches tagged Valid .x &&&
            r.y matches tagged Valid .y);
        lookup_result.deq();
        set_value_result_if_valid(x, y, check_rd_violation(r.expected_rd), mk_d);
    endrule

    // Set the wire driving running_disparity().
    (* no_implicit_conditions, fire_when_enabled *)
    rule do_write_rd;
        _rd <= rd;
    endrule

    //
    // The x block or y block is invalid/corrupt, possibly as a result of bit errors. Reset the
    // running disparity and return to upper layers whatever value bits are there.
    //

    (* descending_urgency = "do_decode_k, do_decode_k_invalid" *)
    rule do_decode_k_invalid (lookup_result.first() matches tagged K .r);
        lookup_result.deq();
        set_invalid_value_result(r.x, r.y);
    endrule

    (* descending_urgency = "do_decode_d, do_decode_d_invalid" *)
    rule do_decode_d_invalid (lookup_result.first() matches tagged D .r);
        lookup_result.deq();
        set_invalid_value_result(r.x, r.y);
    endrule

    interface Put character;
        method put = lookup_block_values;
    endinterface

    interface Get value = toGet(value_result);
    method running_disparity = _rd._read;

endmodule : mkDecoder

endpackage : Decoder8b10b

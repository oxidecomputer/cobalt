package Encoding8b10bReference;

export LookupResult(..);
export toCharacter;
export lookup_d;
export lookup_k;
export valid_k;
export is_comma;
export encode;

import Encoding8b10b::*;


typedef struct {
    Bit#(10) rdn;
    Bit#(10) rdp;
    Bool flip;
} LookupResult deriving (Bits, Eq, FShow);

function Bit#(8) d(Bit#(5) x, Bit#(3) y) = {y, x};
function Bit#(8) k(Bit#(5) x, Bit#(3) y) = {y, x};

//
// Encoder lookup table for Dx.y characters. The result is a tuple containing
// the negative running disparity character, positive running disparity and a
// boolean indicating whether or not the running disparity should flip after
// transmission of the character.
//
// Note: the function takes its input as "HGF EDCBA" (MSB to LSB) while the
// output characters are given as "abcdei fghj" (LSB to MSB). This is done to
// stay close to the reference tables, aiding a human looking at these tables.
// In order to actually return a valid character, the bits of the output
// characters should be reversed.
//
function LookupResult lookup_d(Bit#(8) v) =
    case (v)
        d(0,  0): LookupResult {rdn: 'b100111_0100, rdp: 'b011000_1011, flip: False};
        d(1,  0): LookupResult {rdn: 'b011101_0100, rdp: 'b100010_1011, flip: False};
        d(2,  0): LookupResult {rdn: 'b101101_0100, rdp: 'b010010_1011, flip: False};
        d(3,  0): LookupResult {rdn: 'b110001_1011, rdp: 'b110001_0100, flip: True};
        d(4,  0): LookupResult {rdn: 'b110101_0100, rdp: 'b001010_1011, flip: False};
        d(5,  0): LookupResult {rdn: 'b101001_1011, rdp: 'b101001_0100, flip: True};
        d(6,  0): LookupResult {rdn: 'b011001_1011, rdp: 'b011001_0100, flip: True};
        d(7,  0): LookupResult {rdn: 'b111000_1011, rdp: 'b000111_0100, flip: True};
        d(8,  0): LookupResult {rdn: 'b111001_0100, rdp: 'b000110_1011, flip: False};
        d(9,  0): LookupResult {rdn: 'b100101_1011, rdp: 'b100101_0100, flip: True};
        d(10, 0): LookupResult {rdn: 'b010101_1011, rdp: 'b010101_0100, flip: True};
        d(11, 0): LookupResult {rdn: 'b110100_1011, rdp: 'b110100_0100, flip: True};
        d(12, 0): LookupResult {rdn: 'b001101_1011, rdp: 'b001101_0100, flip: True};
        d(13, 0): LookupResult {rdn: 'b101100_1011, rdp: 'b101100_0100, flip: True};
        d(14, 0): LookupResult {rdn: 'b011100_1011, rdp: 'b011100_0100, flip: True};
        d(15, 0): LookupResult {rdn: 'b010111_0100, rdp: 'b101000_1011, flip: False};
        d(16, 0): LookupResult {rdn: 'b011011_0100, rdp: 'b100100_1011, flip: False};
        d(17, 0): LookupResult {rdn: 'b100011_1011, rdp: 'b100011_0100, flip: True};
        d(18, 0): LookupResult {rdn: 'b010011_1011, rdp: 'b010011_0100, flip: True};
        d(19, 0): LookupResult {rdn: 'b110010_1011, rdp: 'b110010_0100, flip: True};
        d(20, 0): LookupResult {rdn: 'b001011_1011, rdp: 'b001011_0100, flip: True};
        d(21, 0): LookupResult {rdn: 'b101010_1011, rdp: 'b101010_0100, flip: True};
        d(22, 0): LookupResult {rdn: 'b011010_1011, rdp: 'b011010_0100, flip: True};
        d(23, 0): LookupResult {rdn: 'b111010_0100, rdp: 'b000101_1011, flip: False};
        d(24, 0): LookupResult {rdn: 'b110011_0100, rdp: 'b001100_1011, flip: False};
        d(25, 0): LookupResult {rdn: 'b100110_1011, rdp: 'b100110_0100, flip: True};
        d(26, 0): LookupResult {rdn: 'b010110_1011, rdp: 'b010110_0100, flip: True};
        d(27, 0): LookupResult {rdn: 'b110110_0100, rdp: 'b001001_1011, flip: False};
        d(28, 0): LookupResult {rdn: 'b001110_1011, rdp: 'b001110_0100, flip: True};
        d(29, 0): LookupResult {rdn: 'b101110_0100, rdp: 'b010001_1011, flip: False};
        d(30, 0): LookupResult {rdn: 'b011110_0100, rdp: 'b100001_1011, flip: False};
        d(31, 0): LookupResult {rdn: 'b101011_0100, rdp: 'b010100_1011, flip: False};
        d(0,  1): LookupResult {rdn: 'b100111_1001, rdp: 'b011000_1001, flip: True};
        d(1,  1): LookupResult {rdn: 'b011101_1001, rdp: 'b100010_1001, flip: True};
        d(2,  1): LookupResult {rdn: 'b101101_1001, rdp: 'b010010_1001, flip: True};
        d(3,  1): LookupResult {rdn: 'b110001_1001, rdp: 'b110001_1001, flip: False};
        d(4,  1): LookupResult {rdn: 'b110101_1001, rdp: 'b001010_1001, flip: True};
        d(5,  1): LookupResult {rdn: 'b101001_1001, rdp: 'b101001_1001, flip: False};
        d(6,  1): LookupResult {rdn: 'b011001_1001, rdp: 'b011001_1001, flip: False};
        d(7,  1): LookupResult {rdn: 'b111000_1001, rdp: 'b000111_1001, flip: False};
        d(8,  1): LookupResult {rdn: 'b111001_1001, rdp: 'b000110_1001, flip: True};
        d(9,  1): LookupResult {rdn: 'b100101_1001, rdp: 'b100101_1001, flip: False};
        d(10, 1): LookupResult {rdn: 'b010101_1001, rdp: 'b010101_1001, flip: False};
        d(11, 1): LookupResult {rdn: 'b110100_1001, rdp: 'b110100_1001, flip: False};
        d(12, 1): LookupResult {rdn: 'b001101_1001, rdp: 'b001101_1001, flip: False};
        d(13, 1): LookupResult {rdn: 'b101100_1001, rdp: 'b101100_1001, flip: False};
        d(14, 1): LookupResult {rdn: 'b011100_1001, rdp: 'b011100_1001, flip: False};
        d(15, 1): LookupResult {rdn: 'b010111_1001, rdp: 'b101000_1001, flip: True};
        d(16, 1): LookupResult {rdn: 'b011011_1001, rdp: 'b100100_1001, flip: True};
        d(17, 1): LookupResult {rdn: 'b100011_1001, rdp: 'b100011_1001, flip: False};
        d(18, 1): LookupResult {rdn: 'b010011_1001, rdp: 'b010011_1001, flip: False};
        d(19, 1): LookupResult {rdn: 'b110010_1001, rdp: 'b110010_1001, flip: False};
        d(20, 1): LookupResult {rdn: 'b001011_1001, rdp: 'b001011_1001, flip: False};
        d(21, 1): LookupResult {rdn: 'b101010_1001, rdp: 'b101010_1001, flip: False};
        d(22, 1): LookupResult {rdn: 'b011010_1001, rdp: 'b011010_1001, flip: False};
        d(23, 1): LookupResult {rdn: 'b111010_1001, rdp: 'b000101_1001, flip: True};
        d(24, 1): LookupResult {rdn: 'b110011_1001, rdp: 'b001100_1001, flip: True};
        d(25, 1): LookupResult {rdn: 'b100110_1001, rdp: 'b100110_1001, flip: False};
        d(26, 1): LookupResult {rdn: 'b010110_1001, rdp: 'b010110_1001, flip: False};
        d(27, 1): LookupResult {rdn: 'b110110_1001, rdp: 'b001001_1001, flip: True};
        d(28, 1): LookupResult {rdn: 'b001110_1001, rdp: 'b001110_1001, flip: False};
        d(29, 1): LookupResult {rdn: 'b101110_1001, rdp: 'b010001_1001, flip: True};
        d(30, 1): LookupResult {rdn: 'b011110_1001, rdp: 'b100001_1001, flip: True};
        d(31, 1): LookupResult {rdn: 'b101011_1001, rdp: 'b010100_1001, flip: True};
        d(0,  2): LookupResult {rdn: 'b100111_0101, rdp: 'b011000_0101, flip: True};
        d(1,  2): LookupResult {rdn: 'b011101_0101, rdp: 'b100010_0101, flip: True};
        d(2,  2): LookupResult {rdn: 'b101101_0101, rdp: 'b010010_0101, flip: True};
        d(3,  2): LookupResult {rdn: 'b110001_0101, rdp: 'b110001_0101, flip: False};
        d(4,  2): LookupResult {rdn: 'b110101_0101, rdp: 'b001010_0101, flip: True};
        d(5,  2): LookupResult {rdn: 'b101001_0101, rdp: 'b101001_0101, flip: False};
        d(6,  2): LookupResult {rdn: 'b011001_0101, rdp: 'b011001_0101, flip: False};
        d(7,  2): LookupResult {rdn: 'b111000_0101, rdp: 'b000111_0101, flip: False};
        d(8,  2): LookupResult {rdn: 'b111001_0101, rdp: 'b000110_0101, flip: True};
        d(9,  2): LookupResult {rdn: 'b100101_0101, rdp: 'b100101_0101, flip: False};
        d(10, 2): LookupResult {rdn: 'b010101_0101, rdp: 'b010101_0101, flip: False};
        d(11, 2): LookupResult {rdn: 'b110100_0101, rdp: 'b110100_0101, flip: False};
        d(12, 2): LookupResult {rdn: 'b001101_0101, rdp: 'b001101_0101, flip: False};
        d(13, 2): LookupResult {rdn: 'b101100_0101, rdp: 'b101100_0101, flip: False};
        d(14, 2): LookupResult {rdn: 'b011100_0101, rdp: 'b011100_0101, flip: False};
        d(15, 2): LookupResult {rdn: 'b010111_0101, rdp: 'b101000_0101, flip: True};
        d(16, 2): LookupResult {rdn: 'b011011_0101, rdp: 'b100100_0101, flip: True};
        d(17, 2): LookupResult {rdn: 'b100011_0101, rdp: 'b100011_0101, flip: False};
        d(18, 2): LookupResult {rdn: 'b010011_0101, rdp: 'b010011_0101, flip: False};
        d(19, 2): LookupResult {rdn: 'b110010_0101, rdp: 'b110010_0101, flip: False};
        d(20, 2): LookupResult {rdn: 'b001011_0101, rdp: 'b001011_0101, flip: False};
        d(21, 2): LookupResult {rdn: 'b101010_0101, rdp: 'b101010_0101, flip: False};
        d(22, 2): LookupResult {rdn: 'b011010_0101, rdp: 'b011010_0101, flip: False};
        d(23, 2): LookupResult {rdn: 'b111010_0101, rdp: 'b000101_0101, flip: True};
        d(24, 2): LookupResult {rdn: 'b110011_0101, rdp: 'b001100_0101, flip: True};
        d(25, 2): LookupResult {rdn: 'b100110_0101, rdp: 'b100110_0101, flip: False};
        d(26, 2): LookupResult {rdn: 'b010110_0101, rdp: 'b010110_0101, flip: False};
        d(27, 2): LookupResult {rdn: 'b110110_0101, rdp: 'b001001_0101, flip: True};
        d(28, 2): LookupResult {rdn: 'b001110_0101, rdp: 'b001110_0101, flip: False};
        d(29, 2): LookupResult {rdn: 'b101110_0101, rdp: 'b010001_0101, flip: True};
        d(30, 2): LookupResult {rdn: 'b011110_0101, rdp: 'b100001_0101, flip: True};
        d(31, 2): LookupResult {rdn: 'b101011_0101, rdp: 'b010100_0101, flip: True};
        d(0,  3): LookupResult {rdn: 'b100111_0011, rdp: 'b011000_1100, flip: True};
        d(1,  3): LookupResult {rdn: 'b011101_0011, rdp: 'b100010_1100, flip: True};
        d(2,  3): LookupResult {rdn: 'b101101_0011, rdp: 'b010010_1100, flip: True};
        d(3,  3): LookupResult {rdn: 'b110001_1100, rdp: 'b110001_0011, flip: False};
        d(4,  3): LookupResult {rdn: 'b110101_0011, rdp: 'b001010_1100, flip: True};
        d(5,  3): LookupResult {rdn: 'b101001_1100, rdp: 'b101001_0011, flip: False};
        d(6,  3): LookupResult {rdn: 'b011001_1100, rdp: 'b011001_0011, flip: False};
        d(7,  3): LookupResult {rdn: 'b111000_1100, rdp: 'b000111_0011, flip: False};
        d(8,  3): LookupResult {rdn: 'b111001_0011, rdp: 'b000110_1100, flip: True};
        d(9,  3): LookupResult {rdn: 'b100101_1100, rdp: 'b100101_0011, flip: False};
        d(10, 3): LookupResult {rdn: 'b010101_1100, rdp: 'b010101_0011, flip: False};
        d(11, 3): LookupResult {rdn: 'b110100_1100, rdp: 'b110100_0011, flip: False};
        d(12, 3): LookupResult {rdn: 'b001101_1100, rdp: 'b001101_0011, flip: False};
        d(13, 3): LookupResult {rdn: 'b101100_1100, rdp: 'b101100_0011, flip: False};
        d(14, 3): LookupResult {rdn: 'b011100_1100, rdp: 'b011100_0011, flip: False};
        d(15, 3): LookupResult {rdn: 'b010111_0011, rdp: 'b101000_1100, flip: True};
        d(16, 3): LookupResult {rdn: 'b011011_0011, rdp: 'b100100_1100, flip: True};
        d(17, 3): LookupResult {rdn: 'b100011_1100, rdp: 'b100011_0011, flip: False};
        d(18, 3): LookupResult {rdn: 'b010011_1100, rdp: 'b010011_0011, flip: False};
        d(19, 3): LookupResult {rdn: 'b110010_1100, rdp: 'b110010_0011, flip: False};
        d(20, 3): LookupResult {rdn: 'b001011_1100, rdp: 'b001011_0011, flip: False};
        d(21, 3): LookupResult {rdn: 'b101010_1100, rdp: 'b101010_0011, flip: False};
        d(22, 3): LookupResult {rdn: 'b011010_1100, rdp: 'b011010_0011, flip: False};
        d(23, 3): LookupResult {rdn: 'b111010_0011, rdp: 'b000101_1100, flip: True};
        d(24, 3): LookupResult {rdn: 'b110011_0011, rdp: 'b001100_1100, flip: True};
        d(25, 3): LookupResult {rdn: 'b100110_1100, rdp: 'b100110_0011, flip: False};
        d(26, 3): LookupResult {rdn: 'b010110_1100, rdp: 'b010110_0011, flip: False};
        d(27, 3): LookupResult {rdn: 'b110110_0011, rdp: 'b001001_1100, flip: True};
        d(28, 3): LookupResult {rdn: 'b001110_1100, rdp: 'b001110_0011, flip: False};
        d(29, 3): LookupResult {rdn: 'b101110_0011, rdp: 'b010001_1100, flip: True};
        d(30, 3): LookupResult {rdn: 'b011110_0011, rdp: 'b100001_1100, flip: True};
        d(31, 3): LookupResult {rdn: 'b101011_0011, rdp: 'b010100_1100, flip: True};
        d(0,  4): LookupResult {rdn: 'b100111_0010, rdp: 'b011000_1101, flip: False};
        d(1,  4): LookupResult {rdn: 'b011101_0010, rdp: 'b100010_1101, flip: False};
        d(2,  4): LookupResult {rdn: 'b101101_0010, rdp: 'b010010_1101, flip: False};
        d(3,  4): LookupResult {rdn: 'b110001_1101, rdp: 'b110001_0010, flip: True};
        d(4,  4): LookupResult {rdn: 'b110101_0010, rdp: 'b001010_1101, flip: False};
        d(5,  4): LookupResult {rdn: 'b101001_1101, rdp: 'b101001_0010, flip: True};
        d(6,  4): LookupResult {rdn: 'b011001_1101, rdp: 'b011001_0010, flip: True};
        d(7,  4): LookupResult {rdn: 'b111000_1101, rdp: 'b000111_0010, flip: True};
        d(8,  4): LookupResult {rdn: 'b111001_0010, rdp: 'b000110_1101, flip: False};
        d(9,  4): LookupResult {rdn: 'b100101_1101, rdp: 'b100101_0010, flip: True};
        d(10, 4): LookupResult {rdn: 'b010101_1101, rdp: 'b010101_0010, flip: True};
        d(11, 4): LookupResult {rdn: 'b110100_1101, rdp: 'b110100_0010, flip: True};
        d(12, 4): LookupResult {rdn: 'b001101_1101, rdp: 'b001101_0010, flip: True};
        d(13, 4): LookupResult {rdn: 'b101100_1101, rdp: 'b101100_0010, flip: True};
        d(14, 4): LookupResult {rdn: 'b011100_1101, rdp: 'b011100_0010, flip: True};
        d(15, 4): LookupResult {rdn: 'b010111_0010, rdp: 'b101000_1101, flip: False};
        d(16, 4): LookupResult {rdn: 'b011011_0010, rdp: 'b100100_1101, flip: False};
        d(17, 4): LookupResult {rdn: 'b100011_1101, rdp: 'b100011_0010, flip: True};
        d(18, 4): LookupResult {rdn: 'b010011_1101, rdp: 'b010011_0010, flip: True};
        d(19, 4): LookupResult {rdn: 'b110010_1101, rdp: 'b110010_0010, flip: True};
        d(20, 4): LookupResult {rdn: 'b001011_1101, rdp: 'b001011_0010, flip: True};
        d(21, 4): LookupResult {rdn: 'b101010_1101, rdp: 'b101010_0010, flip: True};
        d(22, 4): LookupResult {rdn: 'b011010_1101, rdp: 'b011010_0010, flip: True};
        d(23, 4): LookupResult {rdn: 'b111010_0010, rdp: 'b000101_1101, flip: False};
        d(24, 4): LookupResult {rdn: 'b110011_0010, rdp: 'b001100_1101, flip: False};
        d(25, 4): LookupResult {rdn: 'b100110_1101, rdp: 'b100110_0010, flip: True};
        d(26, 4): LookupResult {rdn: 'b010110_1101, rdp: 'b010110_0010, flip: True};
        d(27, 4): LookupResult {rdn: 'b110110_0010, rdp: 'b001001_1101, flip: False};
        d(28, 4): LookupResult {rdn: 'b001110_1101, rdp: 'b001110_0010, flip: True};
        d(29, 4): LookupResult {rdn: 'b101110_0010, rdp: 'b010001_1101, flip: False};
        d(30, 4): LookupResult {rdn: 'b011110_0010, rdp: 'b100001_1101, flip: False};
        d(31, 4): LookupResult {rdn: 'b101011_0010, rdp: 'b010100_1101, flip: False};
        d(0,  5): LookupResult {rdn: 'b100111_1010, rdp: 'b011000_1010, flip: True};
        d(1,  5): LookupResult {rdn: 'b011101_1010, rdp: 'b100010_1010, flip: True};
        d(2,  5): LookupResult {rdn: 'b101101_1010, rdp: 'b010010_1010, flip: True};
        d(3,  5): LookupResult {rdn: 'b110001_1010, rdp: 'b110001_1010, flip: False};
        d(4,  5): LookupResult {rdn: 'b110101_1010, rdp: 'b001010_1010, flip: True};
        d(5,  5): LookupResult {rdn: 'b101001_1010, rdp: 'b101001_1010, flip: False};
        d(6,  5): LookupResult {rdn: 'b011001_1010, rdp: 'b011001_1010, flip: False};
        d(7,  5): LookupResult {rdn: 'b111000_1010, rdp: 'b000111_1010, flip: False};
        d(8,  5): LookupResult {rdn: 'b111001_1010, rdp: 'b000110_1010, flip: True};
        d(9,  5): LookupResult {rdn: 'b100101_1010, rdp: 'b100101_1010, flip: False};
        d(10, 5): LookupResult {rdn: 'b010101_1010, rdp: 'b010101_1010, flip: False};
        d(11, 5): LookupResult {rdn: 'b110100_1010, rdp: 'b110100_1010, flip: False};
        d(12, 5): LookupResult {rdn: 'b001101_1010, rdp: 'b001101_1010, flip: False};
        d(13, 5): LookupResult {rdn: 'b101100_1010, rdp: 'b101100_1010, flip: False};
        d(14, 5): LookupResult {rdn: 'b011100_1010, rdp: 'b011100_1010, flip: False};
        d(15, 5): LookupResult {rdn: 'b010111_1010, rdp: 'b101000_1010, flip: True};
        d(16, 5): LookupResult {rdn: 'b011011_1010, rdp: 'b100100_1010, flip: True};
        d(17, 5): LookupResult {rdn: 'b100011_1010, rdp: 'b100011_1010, flip: False};
        d(18, 5): LookupResult {rdn: 'b010011_1010, rdp: 'b010011_1010, flip: False};
        d(19, 5): LookupResult {rdn: 'b110010_1010, rdp: 'b110010_1010, flip: False};
        d(20, 5): LookupResult {rdn: 'b001011_1010, rdp: 'b001011_1010, flip: False};
        d(21, 5): LookupResult {rdn: 'b101010_1010, rdp: 'b101010_1010, flip: False};
        d(22, 5): LookupResult {rdn: 'b011010_1010, rdp: 'b011010_1010, flip: False};
        d(23, 5): LookupResult {rdn: 'b111010_1010, rdp: 'b000101_1010, flip: True};
        d(24, 5): LookupResult {rdn: 'b110011_1010, rdp: 'b001100_1010, flip: True};
        d(25, 5): LookupResult {rdn: 'b100110_1010, rdp: 'b100110_1010, flip: False};
        d(26, 5): LookupResult {rdn: 'b010110_1010, rdp: 'b010110_1010, flip: False};
        d(27, 5): LookupResult {rdn: 'b110110_1010, rdp: 'b001001_1010, flip: True};
        d(28, 5): LookupResult {rdn: 'b001110_1010, rdp: 'b001110_1010, flip: False};
        d(29, 5): LookupResult {rdn: 'b101110_1010, rdp: 'b010001_1010, flip: True};
        d(30, 5): LookupResult {rdn: 'b011110_1010, rdp: 'b100001_1010, flip: True};
        d(31, 5): LookupResult {rdn: 'b101011_1010, rdp: 'b010100_1010, flip: True};
        d(0,  6): LookupResult {rdn: 'b100111_0110, rdp: 'b011000_0110, flip: True};
        d(1,  6): LookupResult {rdn: 'b011101_0110, rdp: 'b100010_0110, flip: True};
        d(2,  6): LookupResult {rdn: 'b101101_0110, rdp: 'b010010_0110, flip: True};
        d(3,  6): LookupResult {rdn: 'b110001_0110, rdp: 'b110001_0110, flip: False};
        d(4,  6): LookupResult {rdn: 'b110101_0110, rdp: 'b001010_0110, flip: True};
        d(5,  6): LookupResult {rdn: 'b101001_0110, rdp: 'b101001_0110, flip: False};
        d(6,  6): LookupResult {rdn: 'b011001_0110, rdp: 'b011001_0110, flip: False};
        d(7,  6): LookupResult {rdn: 'b111000_0110, rdp: 'b000111_0110, flip: False};
        d(8,  6): LookupResult {rdn: 'b111001_0110, rdp: 'b000110_0110, flip: True};
        d(9,  6): LookupResult {rdn: 'b100101_0110, rdp: 'b100101_0110, flip: False};
        d(10, 6): LookupResult {rdn: 'b010101_0110, rdp: 'b010101_0110, flip: False};
        d(11, 6): LookupResult {rdn: 'b110100_0110, rdp: 'b110100_0110, flip: False};
        d(12, 6): LookupResult {rdn: 'b001101_0110, rdp: 'b001101_0110, flip: False};
        d(13, 6): LookupResult {rdn: 'b101100_0110, rdp: 'b101100_0110, flip: False};
        d(14, 6): LookupResult {rdn: 'b011100_0110, rdp: 'b011100_0110, flip: False};
        d(15, 6): LookupResult {rdn: 'b010111_0110, rdp: 'b101000_0110, flip: True};
        d(16, 6): LookupResult {rdn: 'b011011_0110, rdp: 'b100100_0110, flip: True};
        d(17, 6): LookupResult {rdn: 'b100011_0110, rdp: 'b100011_0110, flip: False};
        d(18, 6): LookupResult {rdn: 'b010011_0110, rdp: 'b010011_0110, flip: False};
        d(19, 6): LookupResult {rdn: 'b110010_0110, rdp: 'b110010_0110, flip: False};
        d(20, 6): LookupResult {rdn: 'b001011_0110, rdp: 'b001011_0110, flip: False};
        d(21, 6): LookupResult {rdn: 'b101010_0110, rdp: 'b101010_0110, flip: False};
        d(22, 6): LookupResult {rdn: 'b011010_0110, rdp: 'b011010_0110, flip: False};
        d(23, 6): LookupResult {rdn: 'b111010_0110, rdp: 'b000101_0110, flip: True};
        d(24, 6): LookupResult {rdn: 'b110011_0110, rdp: 'b001100_0110, flip: True};
        d(25, 6): LookupResult {rdn: 'b100110_0110, rdp: 'b100110_0110, flip: False};
        d(26, 6): LookupResult {rdn: 'b010110_0110, rdp: 'b010110_0110, flip: False};
        d(27, 6): LookupResult {rdn: 'b110110_0110, rdp: 'b001001_0110, flip: True};
        d(28, 6): LookupResult {rdn: 'b001110_0110, rdp: 'b001110_0110, flip: False};
        d(29, 6): LookupResult {rdn: 'b101110_0110, rdp: 'b010001_0110, flip: True};
        d(30, 6): LookupResult {rdn: 'b011110_0110, rdp: 'b100001_0110, flip: True};
        d(31, 6): LookupResult {rdn: 'b101011_0110, rdp: 'b010100_0110, flip: True};
        d(0,  7): LookupResult {rdn: 'b100111_0001, rdp: 'b011000_1110, flip: False};
        d(1,  7): LookupResult {rdn: 'b011101_0001, rdp: 'b100010_1110, flip: False};
        d(2,  7): LookupResult {rdn: 'b101101_0001, rdp: 'b010010_1110, flip: False};
        d(3,  7): LookupResult {rdn: 'b110001_1110, rdp: 'b110001_0001, flip: True};
        d(4,  7): LookupResult {rdn: 'b110101_0001, rdp: 'b001010_1110, flip: False};
        d(5,  7): LookupResult {rdn: 'b101001_1110, rdp: 'b101001_0001, flip: True};
        d(6,  7): LookupResult {rdn: 'b011001_1110, rdp: 'b011001_0001, flip: True};
        d(7,  7): LookupResult {rdn: 'b111000_1110, rdp: 'b000111_0001, flip: True};
        d(8,  7): LookupResult {rdn: 'b111001_0001, rdp: 'b000110_1110, flip: False};
        d(9,  7): LookupResult {rdn: 'b100101_1110, rdp: 'b100101_0001, flip: True};
        d(10, 7): LookupResult {rdn: 'b010101_1110, rdp: 'b010101_0001, flip: True};
        d(11, 7): LookupResult {rdn: 'b110100_1110, rdp: 'b110100_1000, flip: True};
        d(12, 7): LookupResult {rdn: 'b001101_1110, rdp: 'b001101_0001, flip: True};
        d(13, 7): LookupResult {rdn: 'b101100_1110, rdp: 'b101100_1000, flip: True};
        d(14, 7): LookupResult {rdn: 'b011100_1110, rdp: 'b011100_1000, flip: True};
        d(15, 7): LookupResult {rdn: 'b010111_0001, rdp: 'b101000_1110, flip: False};
        d(16, 7): LookupResult {rdn: 'b011011_0001, rdp: 'b100100_1110, flip: False};
        d(17, 7): LookupResult {rdn: 'b100011_0111, rdp: 'b100011_0001, flip: True};
        d(18, 7): LookupResult {rdn: 'b010011_0111, rdp: 'b010011_0001, flip: True};
        d(19, 7): LookupResult {rdn: 'b110010_1110, rdp: 'b110010_0001, flip: True};
        d(20, 7): LookupResult {rdn: 'b001011_0111, rdp: 'b001011_0001, flip: True};
        d(21, 7): LookupResult {rdn: 'b101010_1110, rdp: 'b101010_0001, flip: True};
        d(22, 7): LookupResult {rdn: 'b011010_1110, rdp: 'b011010_0001, flip: True};
        d(23, 7): LookupResult {rdn: 'b111010_0001, rdp: 'b000101_1110, flip: False};
        d(24, 7): LookupResult {rdn: 'b110011_0001, rdp: 'b001100_1110, flip: False};
        d(25, 7): LookupResult {rdn: 'b100110_1110, rdp: 'b100110_0001, flip: True};
        d(26, 7): LookupResult {rdn: 'b010110_1110, rdp: 'b010110_0001, flip: True};
        d(27, 7): LookupResult {rdn: 'b110110_0001, rdp: 'b001001_1110, flip: False};
        d(28, 7): LookupResult {rdn: 'b001110_1110, rdp: 'b001110_0001, flip: True};
        d(29, 7): LookupResult {rdn: 'b101110_0001, rdp: 'b010001_1110, flip: False};
        d(30, 7): LookupResult {rdn: 'b011110_0001, rdp: 'b100001_1110, flip: False};
        d(31, 7): LookupResult {rdn: 'b101011_0001, rdp: 'b010100_1110, flip: False};
    endcase;

function Maybe#(LookupResult) lookup_k(Bit#(8) v) =
    case (v)
        k(28, 0): tagged Valid LookupResult {rdn: 'b001111_0100, rdp: 'b110000_1011, flip: False};
        k(28, 1): tagged Valid LookupResult {rdn: 'b001111_1001, rdp: 'b110000_0110, flip: True};
        k(28, 2): tagged Valid LookupResult {rdn: 'b001111_0101, rdp: 'b110000_1010, flip: True};
        k(28, 3): tagged Valid LookupResult {rdn: 'b001111_0011, rdp: 'b110000_1100, flip: True};
        k(28, 4): tagged Valid LookupResult {rdn: 'b001111_0010, rdp: 'b110000_1101, flip: False};
        k(28, 5): tagged Valid LookupResult {rdn: 'b001111_1010, rdp: 'b110000_0101, flip: True};
        k(28, 6): tagged Valid LookupResult {rdn: 'b001111_0110, rdp: 'b110000_1001, flip: True};
        k(28, 7): tagged Valid LookupResult {rdn: 'b001111_1000, rdp: 'b110000_0111, flip: False};
        k(23, 7): tagged Valid LookupResult {rdn: 'b111010_1000, rdp: 'b000101_0111, flip: False};
        k(27, 7): tagged Valid LookupResult {rdn: 'b110110_1000, rdp: 'b001001_0111, flip: False};
        k(29, 7): tagged Valid LookupResult {rdn: 'b101110_1000, rdp: 'b010001_0111, flip: False};
        k(30, 7): tagged Valid LookupResult {rdn: 'b011110_1000, rdp: 'b100001_0111, flip: False};
        default: tagged Invalid;
    endcase;

// Return the Character given a LookupResult and running disparity.
function Character toCharacter(LookupResult result, RunningDisparity rd);
    return mk_c(rd == RunningNegative ? result.rdn : result.rdp);
endfunction

// Determine if the given Value v is a valid K value.
function Bool valid_k(Value v);
    return is_k(v) && isValid(lookup_k(value_bits(v)));
endfunction

// Determine if the given Value v is a comma character.
function Bool is_comma(Value v);
    return v == mk_k(28, 1) || v == mk_k(28, 5) || v == mk_k(28, 7);
endfunction

//
// Reference encode
//
// A function mirroring the `encode(..)` function in the `Encoding8b10b`
// package, but using the lookup tables above instead of the logic approach.
// This implementation is intended to be used for tandem verification.
//
function EncodeResult encode(Value v, RunningDisparity rd);
    // Select from lookup result and determine the next running disparity.
    function toEncodeResult(r) =
        EncodeResult {
            character: tagged Valid toCharacter(r, rd),
            rd: (r.flip ? ~rd : rd)};

    let d_result = toEncodeResult(lookup_d(value_bits(v)));

    return case (v) matches
        tagged D .*: d_result;
        tagged K .k:
            case (lookup_k(k)) matches
                // Use the results for a D value and mark the Character invalid.
                tagged Invalid: EncodeResult {
                    character: tagged Invalid result_bits(d_result.character),
                    rd: d_result.rd};
                tagged Valid .result: toEncodeResult(result);
            endcase
    endcase;
endfunction

endpackage

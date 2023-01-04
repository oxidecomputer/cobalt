// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package TestPatternGenerator;

export Pixel(..), Parameters(..);
export TestPatternGenerator(..), mkTestPatternGenerator;

import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;
import StmtFSM::*;

import TestUtils::*;


typedef struct {
    Bit#(8) b;
    Bit#(8) g;
    Bit#(8) r;
} Pixel deriving (Bits, Eq, FShow);

typedef struct {
    UInt#(14) pixels_per_column;
    UInt#(3) left_over_pixels;
} Parameters deriving (Bits, Eq, FShow);

interface TestPatternGenerator;
    interface Get#(Pixel) pixel;
    method Action set_parameters(Parameters p);
endinterface

// Colors
Pixel white = Pixel{r: 235, g: 235, b: 235};
Pixel yellow = Pixel{r: 235, g: 235, b: 16};
Pixel cyan = Pixel{r: 16, g: 235, b: 235};
Pixel green = Pixel{r: 16, g: 235, b: 16};
Pixel magenta = Pixel{r: 235, g: 16, b: 235};
Pixel red = Pixel{r: 235, g: 16, b: 16};
Pixel blue = Pixel{r: 16, g: 16, b: 235};
Pixel black = Pixel{r: 0, g: 0, b: 0};

module mkTestPatternGenerator (TestPatternGenerator);
    Reg#(Parameters) parameters <- mkRegU();
    FIFO#(Pixel) out <- mkPipelineFIFO();

    // Generator state
    Reg#(UInt#(3)) column_idx <- mkRegU();
    Reg#(UInt#(14)) pixels_remaining_in_column <- mkRegU();
    Reg#(UInt#(3)) left_over_pixels <- mkRegU();

    Reg#(Bool) restart <- mkRegA(False);
    RWire#(Parameters) parameters_next <- mkRWire();
    PulseWire put_pixel <- mkPulseWire();

    function Pixel get_pixel(UInt#(3) idx) =
        case (idx)
            0: white;
            1: yellow;
            2: cyan;
            3: green;
            4: magenta;
            5: red;
            6: blue;
            7: black;
        endcase;

    (* fire_when_enabled *)
    rule do_set_parameters (parameters_next.wget() matches tagged Valid .p);
        parameters <= p;
        column_idx <= 0;

        out.clear();
        restart <= True;

        let add_pixel = p.left_over_pixels > 0;

        pixels_remaining_in_column <= p.pixels_per_column + (add_pixel? 1 : 0);
        left_over_pixels <= p.left_over_pixels - (add_pixel? 1 : 0);
    endrule

    (* fire_when_enabled *)
    rule do_put_pixel (parameters_next.wget() matches tagged Invalid &&& (restart || put_pixel));
        restart <= False;
        out.enq(get_pixel(column_idx));

        let column_done = pixels_remaining_in_column == 1;

        if (column_done) begin
            let line_done = column_idx == 6;

            if (line_done) begin
                let add_pixel = parameters.left_over_pixels > 0;

                column_idx <= 0;
                pixels_remaining_in_column <= parameters.pixels_per_column + (add_pixel? 1 : 0);
                left_over_pixels <= parameters.left_over_pixels - (add_pixel? 1 : 0);
            end else begin
                let add_pixel = left_over_pixels > 0;

                column_idx <= column_idx + 1;
                pixels_remaining_in_column <= parameters.pixels_per_column + (add_pixel? 1 : 0);
                left_over_pixels <= left_over_pixels - (add_pixel? 1 : 0);
            end
        end else begin
            pixels_remaining_in_column <= pixels_remaining_in_column - 1;
        end
    endrule

    interface Get pixel;
        method ActionValue#(Pixel) get();
            put_pixel.send();
            out.deq();
            return out.first();
        endmethod
    endinterface

    method set_parameters = parameters_next.wset;
endmodule: mkTestPatternGenerator

module mkTestPatternGeneratorTest (Empty);
    Parameters p = Parameters{
        pixels_per_column: 1,
        left_over_pixels: 1};

    TestPatternGenerator g <- mkTestPatternGenerator();

    mkAutoFSM(seq
        g.set_parameters(p);
        assert_get_eq_display(g.pixel, white, "expected a white pixel");
        assert_get_eq_display(g.pixel, white, "expected a white pixel");
        assert_get_eq_display(g.pixel, yellow, "expected a yellow pixel");
        assert_get_eq_display(g.pixel, cyan, "expected a cyan pixel");
        assert_get_eq_display(g.pixel, green, "expected a green pixel");
        assert_get_eq_display(g.pixel, magenta, "expected a magenta pixel");
        assert_get_eq_display(g.pixel, red, "expected a red pixel");
        assert_get_eq_display(g.pixel, blue, "expected a blue pixel");
        assert_get_eq_display(g.pixel, white, "expected a white pixel of the next line");
    endseq);

    mkTestWatchdog(20);
endmodule

endpackage: TestPatternGenerator

// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Transmitter;

export Pixel(..), Characters(..);
export Transmitter(..), mkTransmitter;

import DefaultValue::*;
import GetPut::*;
import StmtFSM::*;

import Timing::*;
import TMDS::*;
import TestUtils::*;


typedef struct {
    Bit#(8) ch2;
    Bit#(8) ch1;
    Bit#(8) ch0;
} Pixel deriving (Bits, Eq, FShow);

typedef struct {
    Character clk;
    Character ch2;
    Character ch1;
    Character ch0;
} Characters deriving (Bits);

instance DefaultValue #(Characters);
    defaultValue = Characters{
        clk: 0,
        ch2: 0,
        ch1: 0,
        ch0: 0};
endinstance

interface Transmitter;
    interface Put#(Pixel) pixel;
    interface Get#(Characters) characters;
    method Action set_timing(Timing t);

    (* always_enabled *) method Bool h_sync();
    (* always_enabled *) method Bool v_sync();
    (* always_enabled *) method Bool end_of_field();
endinterface

module mkTransmitter (Transmitter);
    Encoder ch0 <- mkFasterEncoder();
    Encoder ch1 <- mkFasterEncoder();
    Encoder ch2 <- mkFasterEncoder();

    DisplayTimingGenerator display_timing <- mkDisplayTimingGenerator();
    DataIslandTimingGenerator data_island_timing <- mkDataIslandTimingGenerator();

    // Alias the island timing generators.
    IslandTiming data_island = data_island_timing.timing;
    IslandTiming video_island = display_timing.video_island;

    // Incoming pixel data.
    PulseWire put_pixel <- mkPulseWire();
    RWire#(Pixel) pixel_next <- mkRWire();

    //
    // Encoder input
    //

    (* fire_when_enabled *)
    rule do_encode_control (
            !(data_island.guard_band || video_island.guard_band) &&&
            pixel_next.wget() matches tagged Invalid);
        let ch0_data = {pack(display_timing.v.sync), pack(display_timing.h.sync)};
        let ch1_data = data_island.preamble || video_island.preamble? 2'b01 : 2'b00;

        ch0.data.put(tagged Control ch0_data);
        ch1.data.put(tagged Control ch1_data);
        ch2.data.put(tagged Control (data_island.preamble? 2'b01 : 2'b00));
    endrule

    (* fire_when_enabled *)
    rule do_encode_guard_band (
            (data_island.guard_band || video_island.guard_band) &&&
            pixel_next.wget() matches tagged Invalid);
        let ch0_data = tagged TMDS::Data ({
            2'b11,
            pack(display_timing.v.sync),
            pack(display_timing.h.sync)});

        ch0.data.put(data_island.guard_band? ch0_data : tagged Guard 'b10110_01100);
        ch1.data.put(tagged Guard 'b01001_10011);
        ch2.data.put(tagged Guard (data_island.guard_band? 'b01001_10011 : 'b10110_01100));
    endrule

    (* fire_when_enabled *)
    rule do_encode_pixel (
            !(data_island.guard_band || video_island.guard_band) &&&
            pixel_next.wget() matches tagged Valid .p);
        ch0.data.put(tagged Pixel p.ch0);
        ch1.data.put(tagged Pixel p.ch1);
        ch2.data.put(tagged Pixel p.ch2);
    endrule

    //
    // Interface
    //

    interface Put pixel;
        method put if (video_island.active && put_pixel) = pixel_next.wset;
    endinterface

    interface Get characters;
        method ActionValue#(Characters) get();
            display_timing.send();
            put_pixel.send();

            let c0 <- ch0.character.get();
            let c1 <- ch1.character.get();
            let c2 <- ch2.character.get();

            return Characters{
                ch0: c0,
                ch1: c1,
                ch2: c2,
                // The pixel clock is a fixed pattern.
                clk: 'b00000_11111};
        endmethod
    endinterface

    method set_timing = display_timing.set_timing;

    method h_sync = display_timing.h_sync;
    method v_sync = display_timing.v_sync;
    method end_of_field = display_timing.end_of_field;
endmodule: mkTransmitter

endpackage: Transmitter

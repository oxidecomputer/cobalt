// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package TestPatternVideoSource;

import GetPut::*;
import StmtFSM::*;

import TestPatternGenerator::*;
import Timing::*;
import Transmitter::*;
import TMDS::*;


interface TestPatternVideoSource;
    interface Get#(Characters) characters;

    (* always_enabled *) method Bool h_sync();
    (* always_enabled *) method Bool v_sync();
    (* always_enabled *) method Bool end_of_field();

    method Action set_timing_parameters(Timing t);
    method Action set_test_pattern_parameters(Parameters p);
endinterface

module mkTestPatternVideoSource (TestPatternVideoSource);
    TestPatternGenerator pattern <- mkTestPatternGenerator();
    Transmitter tx <- mkTransmitter();

    (* fire_when_enabled *)
    rule do_put_pixel;
        let p <- pattern.pixel.get();
        tx.pixel.put(Transmitter::Pixel{ch0: p.b, ch1: p.g, ch2: p.r});
    endrule

    interface Get characters = tx.characters;

    method h_sync = tx.h_sync;
    method v_sync = tx.v_sync;
    method end_of_field = tx.end_of_field;

    method set_timing_parameters = tx.set_timing;
    method set_test_pattern_parameters = pattern.set_parameters;
endmodule

interface FixedTimingTestPatternVideoSource;
    interface Get#(Characters) characters;

    (* always_enabled *) method Bool h_sync();
    (* always_enabled *) method Bool v_sync();
    (* always_enabled *) method Bool end_of_field();
endinterface

module mkFixedTimingTestPatternVideoSource
        #(Timing t, TestPatternGenerator::Parameters p)
        (FixedTimingTestPatternVideoSource);
    TestPatternVideoSource _source <- mkTestPatternVideoSource();
    Reg#(Bool) should_init <- mkRegA(True);

    (* fire_when_enabled *)
    rule do_init (should_init);
        should_init <= False;

        _source.set_timing_parameters(t);
        _source.set_test_pattern_parameters(p);

        $display(fmt_timing(t));
    endrule

    interface Get characters = _source.characters;

    method h_sync = _source.h_sync;
    method v_sync = _source.v_sync;
    method end_of_field = _source.end_of_field;
endmodule

module mk100pTestPatternVideoSource (FixedTimingTestPatternVideoSource);
    let timing = compute_timing(
        8, 8, 16, 160,  // H
        3, 6, 6, 100);  // V
    let pattern_parameters = Parameters{
        pixels_per_column: 22,
        left_over_pixels: 6};

    FixedTimingTestPatternVideoSource _source <-
        mkFixedTimingTestPatternVideoSource(timing, pattern_parameters);

    return _source;
endmodule

module mk480pTestPatternVideoSource (FixedTimingTestPatternVideoSource);
    let timing = compute_timing(
        16, 64, 80, 640, // H
        3, 4, 13, 480);  // V
    let pattern_parameters = Parameters{
        pixels_per_column: 91,
        left_over_pixels: 3};

    FixedTimingTestPatternVideoSource _source <-
        mkFixedTimingTestPatternVideoSource(timing, pattern_parameters);

    return _source;
endmodule

endpackage: TestPatternVideoSource

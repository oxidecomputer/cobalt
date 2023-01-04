// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Timing;

export Timing(..), compute_timing, fmt_timing;
export DisplayTiming(..), IslandTiming(..);
export DisplayTimingGenerator(..), mkDisplayTimingGenerator;
export DataIslandTimingGenerator(..), mkDataIslandTimingGenerator;

import DefaultValue::*;
import StmtFSM::*;
import TestUtils::*;


//
// Timing
//
// This package provides interfaces and modules which can be used to generate timing signals for a
// display and/or digital video source.
//

//
// Timing struct, holding pixel/line offset values used to generate event strobes. See the
// compute_timing(..) function below on how to calculate these values.
//
typedef struct {
    UInt#(16) h_sync_start;
    UInt#(16) h_sync_end;
    UInt#(16) h_active;
    UInt#(16) video_preamble;
    UInt#(16) video_leading_guard_band;
    UInt#(16) end_of_line;
    UInt#(16) v_sync_start;
    UInt#(16) v_sync_end;
    UInt#(16) v_active;
    UInt#(16) v_blank;
    UInt#(16) data_island_period_end;
    UInt#(16) data_island_last_byte;
    Bool data_island_fits_on_v_blank_line;
    Bool data_island_fits_on_v_active_line;
} Timing deriving (Bits, Eq, FShow);

//
// Compute a Timing struct using the given video timing parameters.
//
function Timing compute_timing(
        UInt#(16) h_front_porch,
        UInt#(16) h_sync,
        UInt#(16) h_back_porch,
        UInt#(16) h_active,
        UInt#(16) v_front_porch,
        UInt#(16) v_sync,
        UInt#(16) v_back_porch,
        UInt#(16) v_active);
    // Constants
    let preamble_period = 8;
    let control_period_padding = 4;
    let min_control_period = control_period_padding + preamble_period;
    let packet_period = 32;
    let guard_period = 2;

    // Derived values
    let h_blank = h_front_porch + h_sync + h_back_porch;
    let h_total = h_blank + h_active;

    let v_blank = v_front_porch + v_sync + v_back_porch;
    let v_total = v_blank + v_active;

    let min_data_island_period = preamble_period + guard_period + packet_period + guard_period;
    let video_island_leadin = min_control_period + guard_period;

    return Timing{
        // Horizontal timing
        h_sync_start: h_front_porch - 1,
        h_sync_end: h_front_porch + h_sync - 1,
        video_preamble: h_blank - 1 - preamble_period - guard_period,
        video_leading_guard_band: h_blank - 1 - guard_period,
        h_active: h_blank - 1,
        end_of_line: h_total - 2,
        // Vertial timing
        v_sync_start: v_front_porch - 1,
        v_sync_end: v_front_porch + v_sync - 1,
        v_active: v_blank - 1,
        v_blank: v_total - 1,
        // Data island timing
        data_island_period_end:
            // The modulo does not turn negative offsets positive. Adding h_total at least once
            // (which subsequently gets removed by the modulo) makes this behave properly for both
            // the negative and positive case.
            (h_blank - 1 - min_data_island_period - video_island_leadin + h_total) % h_total,
        data_island_last_byte:
            (h_blank - 1 - guard_period - video_island_leadin + h_total) % h_total,
        data_island_fits_on_v_blank_line:
            control_period_padding + min_data_island_period <= h_total,
        data_island_fits_on_v_active_line:
            control_period_padding + min_data_island_period + video_island_leadin <= h_blank};
endfunction

//
// Format the given Timing struct. Useful for debug when running Bluesim simulations.
//
function Fmt fmt_timing (Timing t);
    let h_front_porch = t.h_sync_start + 1;
    let h_sync = t.h_sync_end - t.h_sync_start;
    let h_back_porch = t.h_active - t.h_sync_end;

    let h_total = t.end_of_line + 2;
    let h_blank = h_front_porch + h_sync + h_back_porch;
    let h_active = h_total - h_blank;

    let v_front_porch = t.v_sync_start + 1;
    let v_sync = t.v_sync_end - t.v_sync_start;
    let v_back_porch = t.v_active - t.v_sync_end;

    let v_total = t.v_blank + 1;
    let v_blank = t.v_active + 1;
    let v_active = v_total - v_blank;

    return
        $format("Horizontal Timings\n\n") +
        $format("Total\t\t%d\n", h_total) +
        $format("Active\t\t%d\n", h_active) +
        $format("Blank\t\t%d\n", h_blank) +
        $format("Front Porch\t%d\n", h_front_porch) +
        $format("Sync\t\t%d\n", h_sync) +
        $format("Back Porch\t%d\n", h_back_porch) +
        $format("\nVertical Timings\n\n") +
        $format("Total\t\t%d\n", v_total) +
        $format("Active\t\t%d\n", v_active) +
        $format("Blank\t\t%d\n", v_blank) +
        $format("Front Porch\t%d\n", v_front_porch) +
        $format("Sync\t\t%d\n", v_sync) +
        $format("Back Porch\t%d\n", v_back_porch) +
        $format("\nVideo Island\n\n") +
        $format("Preamble\t%d\n", t.video_preamble) +
        $format("Leading Guard\t%d\n", t.video_leading_guard_band) +
        $format("End\t\t%d\n", t.end_of_line + 1) +
        $format("\nData Island\n\n") +
        $format("Last Accept\t%d\n", t.data_island_period_end) +
        $format("Last Byte\t%d\n", t.data_island_last_byte) +
        $format("Active Line\t%s\n", t.data_island_fits_on_v_active_line? "True" : "False") +
        $format("Blank Line\t%s", t.data_island_fits_on_v_blank_line? "True" : "False");
endfunction

interface DisplayTiming;
    method Bool blank();
    method Bool sync();
    method Bool active();
endinterface

interface IslandTiming;
    method Bool preamble();
    method Bool guard_band();
    method Bool active();
endinterface

interface DisplayTimingGenerator;
    // Get/set timing parameters.
    method Timing timing();
    method Action set_timing(Timing t);

    // Run the timing generator.
    (* always_ready *) method Action send();

    // Display periods.
    (* always_enabled *) interface DisplayTiming h;
    (* always_enabled *) interface DisplayTiming v;
    (* always_enabled *) interface IslandTiming video_island;

    // Useful strobes, these fire the cycle prior to the given period becoming active.
    (* always_enabled *) method Bool h_sync();
    (* always_enabled *) method Bool v_sync();
    (* always_enabled *) method Bool end_of_field();
endinterface

module mkDisplayTimingGenerator (DisplayTimingGenerator);
    Reg#(Timing) timing_r <- mkRegU();
    RWire#(Timing) timing_next <- mkRWire();

    PulseWire tick <- mkPulseWire();

    Reg#(UInt#(16)) pixel_count <- mkRegU();
    Reg#(UInt#(16)) line_count <- mkRegU();

    // Strobes, enabled for only a single cycle.
    Reg#(Bool) h_front_porch_start <- mkRegU();
    Reg#(Bool) h_sync_start <- mkRegU();
    Reg#(Bool) h_back_porch_start <- mkRegU();
    Reg#(Bool) h_active_start <- mkRegU();

    Reg#(Bool) video_preamble_start <- mkRegU();
    Reg#(Bool) video_guard_band_start <- mkRegU();
    Reg#(Bool) end_of_line <- mkRegU();

    Reg#(Bool) v_front_porch_start <- mkRegU();
    Reg#(Bool) v_sync_start <- mkRegU();
    Reg#(Bool) v_back_porch_start <- mkRegU();
    Reg#(Bool) v_active_start <- mkRegU();

    // Periods.
    Reg#(Bool) h_blank_period <- mkRegU();
    Reg#(Bool) h_sync_period <- mkRegU();
    Reg#(Bool) h_active_period <- mkRegU();

    Reg#(Bool) v_blank_period <- mkRegU();
    Reg#(Bool) v_sync_period <- mkRegU();
    Reg#(Bool) v_active_period <- mkRegU();

    // The timing generator is actually one line ahead of what can be observed externally in order
    // to determine if the next line can hold a data island. This set of registers is used to track
    // vertial periods.
    Reg#(Bool) v_blank_period_next_line <- mkRegU();
    Reg#(Bool) v_sync_period_next_line <- mkRegU();
    Reg#(Bool) v_active_period_next_line <- mkRegU();

    // Video island positioning.
    Reg#(Bool) video_preamble_period <- mkRegU();
    Reg#(Bool) video_guard_band_period <- mkRegU();

    // Data island positioning.
    Reg#(Bool) data_island_period_start <- mkRegU();
    Reg#(Bool) data_island_period_end <- mkRegU();
    Reg#(Bool) data_island_last_byte <- mkRegU();
    Reg#(Bool) data_island_period <- mkRegU();
    Reg#(Bool) data_island_next_byte <- mkRegU();

    // Generate a period based on a start and end strobe and maintaining the current period value
    // otherwise.
    function Bool period_between(Bool start_strobe, Bool end_strobe, Bool no_change) = (begin
        if (start_strobe) True;
        else if (end_strobe) False;
        else no_change;
    end);

    (* fire_when_enabled *)
    rule do_set_timing (timing_next.wget() matches tagged Valid .t);
        timing_r <= t;

        // Set state to sync.
        pixel_count <= t.h_sync_start;
        line_count <= t.v_sync_start;

        h_front_porch_start <= False;
        h_sync_start <= False;
        h_back_porch_start <= False;
        h_active_start <= False;

        video_preamble_start <= False;
        video_guard_band_start <= False;
        end_of_line <= False;

        v_front_porch_start <= False;
        v_sync_start <= False;
        v_back_porch_start <= False;
        v_active_start <= False;

        h_blank_period <= True;
        h_sync_period <= False;
        h_active_period <= False;

        video_preamble_period <= False;
        video_guard_band_period <= False;

        v_blank_period_next_line <= True;
        v_sync_period_next_line <= True;
        v_active_period_next_line <= False;

        v_blank_period <= True;
        v_sync_period <= False;
        v_active_period <= False;

        data_island_period_start <= False;
        data_island_period_end <= False;
        data_island_last_byte <= False;
        data_island_period <= False;
        data_island_next_byte <= False;
    endrule

    (* fire_when_enabled *)
    rule do_generate_timing (timing_next.wget() matches tagged Invalid);
        pixel_count <= end_of_line? 0 : pixel_count + (tick? 1 : 0);

        // Set pixel strobes based on the pixel counter and timing parameters.
        h_front_porch_start <= tick && end_of_line;
        h_sync_start <= tick && pixel_count == timing_r.h_sync_start;
        h_back_porch_start <= tick && pixel_count == timing_r.h_sync_end;
        h_active_start <= tick && pixel_count == timing_r.h_active;

        video_preamble_start <= tick && pixel_count == timing_r.video_preamble;
        video_guard_band_start <= tick && pixel_count == timing_r.video_leading_guard_band;
        end_of_line <= tick && pixel_count == timing_r.end_of_line;

        // Set pixel periods based on H strobes.
        h_blank_period <= period_between(h_front_porch_start, h_active_start, h_blank_period);
        h_sync_period <= period_between(h_sync_start, h_back_porch_start, h_sync_period);
        h_active_period <= period_between(h_active_start, h_front_porch_start, h_active_period);

        // Set line strobes based on line counter and end_of_line strobe.
        line_count <= v_front_porch_start? 0 : line_count + (end_of_line? 1 : 0);

        v_front_porch_start <= end_of_line && line_count == timing_r.v_blank;
        v_sync_start <= end_of_line && line_count == timing_r.v_sync_start;
        v_back_porch_start <= end_of_line && line_count == timing_r.v_sync_end;
        v_active_start <= end_of_line && line_count == timing_r.v_active;

        // Set line periods based on line strobes.
        v_blank_period_next_line <=
            period_between(
                v_front_porch_start,
                v_active_start,
                v_blank_period_next_line);
        v_sync_period_next_line <=
            period_between(
                v_sync_start,
                v_back_porch_start,
                v_sync_period_next_line);
        v_active_period_next_line <=
            period_between(
                v_active_start,
                v_front_porch_start,
                v_active_period_next_line);

        if (h_front_porch_start) begin
            v_blank_period <= v_blank_period_next_line;
            v_sync_period <= v_sync_period_next_line;
            v_active_period <= v_active_period_next_line;
        end

        // Set video island periods.
        video_preamble_period <=
            period_between(
                v_active_period && video_preamble_start,
                v_active_period && video_guard_band_start,
                video_preamble_period);
        video_guard_band_period <=
            period_between(
                v_active_period && video_guard_band_start,
                v_active_period && h_active_start,
                video_guard_band_period);

        // Set data island strobes.
        data_island_period_start <= tick && pixel_count == 4;
        data_island_period_end <= tick && pixel_count == timing_r.data_island_period_end;
        data_island_last_byte <= tick && pixel_count == timing_r.data_island_last_byte;

        // Set data island periods.
        if (!data_island_period && data_island_period_start) begin
            data_island_period <=
                timing_r.data_island_fits_on_v_active_line ||
                (timing_r.data_island_fits_on_v_blank_line && v_blank_period);
        end else if (data_island_period && data_island_period_end) begin
            // Stop allowing data islands at this point if the current line is during V active.
            if (v_active_period) begin
                data_island_period <= False;
            // If the data island was started on the previous line, only continue if the next
            // line is still during V blank.
            end else if (!timing_r.data_island_fits_on_v_active_line) begin
                data_island_period <= v_blank_period_next_line;
            end
        end

        if (data_island_period) begin
            data_island_next_byte <= True;
        end else if (data_island_last_byte) begin
            data_island_next_byte <= False;
        end
    endrule

    method timing = timing_r._read;
    method set_timing = timing_next.wset;
    method send = tick.send;

    interface DisplayTiming h;
        method blank = h_blank_period._read;
        method sync = h_sync_period._read;
        method active = h_active_period._read;
    endinterface

    interface DisplayTiming v;
        method blank = v_blank_period._read;
        method sync = v_sync_period._read;
        method active = v_active_period._read;
    endinterface

    interface IslandTiming video_island;
        method preamble = video_preamble_period._read;
        method guard_band = video_guard_band_period._read;
        method active = h_active_period && v_active_period;
    endinterface

    method h_sync = h_sync_start._read;
    method v_sync = v_sync_start._read;
    method end_of_field = v_front_porch_start._read;
endmodule: mkDisplayTimingGenerator

typedef struct {
    int sync;
    int blank;
    int active;
} Counters deriving (Bits, Eq, FShow);

instance DefaultValue #(Counters);
    defaultValue = Counters{
        sync: 0,
        blank: 0,
        active: 0};
endinstance

module mkDisplayTimingGeneratorTest #(
        Timing t,
        Counters expected_pixels /*,
        Counters expected_lines*/) (Empty);
    DisplayTimingGenerator timing <- mkDisplayTimingGenerator();

    Reg#(int) frames <- mkReg(0);
    Reg#(Counters) pixels <- mkReg(defaultValue);
    Reg#(Counters) lines <- mkReg(defaultValue);

    PulseWire count <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_count_frames (timing.end_of_field());
        frames <= frames + 1;
    endrule

    (* fire_when_enabled *)
    rule do_count (count);
        pixels <= Counters{
            sync: pixels.sync + (timing.h.sync? 1 : 0),
            blank: pixels.blank + (timing.h.blank? 1 : 0),
            active: pixels.active + (timing.h.active? 1 : 0)};
    endrule

    mkAutoFSM(seq
        action
            $display(fmt_timing(t));
            timing.set_timing(t);
        endaction

        // Advance to the next V sync period.
        while (!timing.v_sync) timing.send();

        // Wait for 2 complete frames. The condition slightly more complicated in order to avoid
        // overcounting the blanking period (1 pixel/line into the next frame).
        while (frames < 3 || frames == 3 && !timing.v_sync) action
            timing.send();
            count.send();
        endaction

        // Test pixel counts.
        action
            if (expected_pixels == pixels) $display("\nPixel\t", fshow(pixels));
            else begin
                $display("\nExpected pixel\t", fshow(expected_pixels));
                $display("Actual pixel\t", fshow(pixels));
            end
        endaction
    endseq);
endmodule

module mkMinimalDisplayTimingTest (Empty);
    // 1 pixel/line for each period.
    let t = compute_timing(
        1, 1, 1, 1,     // H
        1, 1, 1, 1);    // V

    Counters expected_pixels = Counters{
        sync: 2 * 4 * 1,  // 2 frames, 4 lines/frame, 1 pixel/line.
        blank: 2 * 4 * 3,
        active: 2 * 4 * 1};

    mkDisplayTimingGeneratorTest(t, expected_pixels);
    mkTestWatchdog(4 * 4 * 4); // ~4 frames.
endmodule

module mk100pDisplayTimingTest (Empty);
    let t = compute_timing(
        8, 8, 16, 160,  // H
        3, 6, 6, 100);  // V

    Counters expected_pixels = Counters{
        sync: 2 * 115 * 8,  // 2 frames, 4 lines/frame, 1 pixel/line.
        blank: 2 * 115 * 32,
        active: 2 * 115 * 160};

    mkDisplayTimingGeneratorTest(t, expected_pixels);
    mkTestWatchdog(4 * 115 * 192); // ~4 frames
endmodule

interface DataIslandTimingGenerator;
    interface IslandTiming timing;
endinterface

module mkDataIslandTimingGenerator (DataIslandTimingGenerator);
    interface IslandTiming timing;
        method preamble = False;
        method guard_band = False;
        method active = False;
    endinterface
endmodule

endpackage: Timing

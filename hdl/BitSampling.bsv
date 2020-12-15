// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package BitSampling;

export BitSampler(..), mkBitSampler;
export AsyncBitSampler(..), mkAsyncBitSampler;
export Polarity(..);

import FIFOF::*;
import GetPut::*;

import Strobe::*;


typedef enum {
    NegativePolarity = 0,
    PositivePolarity
} Polarity deriving (Bits, Eq, FShow);

interface BitSampler #(numeric type bit_period);
    interface Put#(Bit#(1)) in;
    interface Get#(Bit#(1)) out;
endinterface

function Bool detect_edge(Bit#(sz) ds, Polarity polarity)
        provisos (Add#(__a, 1, sz)); // sz > 0
    Bit#(sz) edge_pattern =
        polarity == PositivePolarity ? {'1, 1'b0} : {'0, 1'b1};
    return ds == edge_pattern;
endfunction

module mkBitSampler #(Strobe#(any_sz) strobe, Polarity polarity) (BitSampler#(bit_period))
        provisos (
            Add#(bit_period_msb, 1, bit_period),
            Div#(bit_period, 2, half_bit_period));
    AsyncBitSampler#(bit_period) _s <- mkAsyncBitSampler(strobe, polarity);
    interface Put in = _s.in;
    interface Put out = _s.out;
endmodule

interface AsyncBitSampler #(numeric type bit_period);
    interface Put#(Bit#(1)) in;
    interface Get#(Bit#(1)) out;
    method Action search_for_bit_edge();
endinterface

module mkAsyncBitSampler
        #(Strobe#(any_sz) strobe, Polarity polarity) (AsyncBitSampler#(bit_period))
        provisos (
            Add#(bit_period_msb, 1, bit_period),
            Div#(bit_period, 2, half_bit_period),
            Add#(half_bit_period, 1, edge_pattern_sz));
    // Next incoming bit sample.
    Wire#(Bit#(1)) d <- mkWire();
    // Bit samples
    Reg#(Bit#(bit_period)) samples <- mkRegA(polarity == PositivePolarity ? '0 : '1);
    // The sampling point for the bit.
    Wire#(Bit#(1)) sampled_bit <- mkWire();

    // Output goes through a FIFO with unguarded enq. This will overwrite samples if an upstream
    // sink does not keep up.
    FIFOF#(Bit#(1)) q <- mkGFIFOF1(True, False);

    PulseWire edge_detected <- mkPulseWire();
    PulseWire search_for_bit_edge_ <- mkPulseWire();

    function Action sample_bit =
        action
            sampled_bit <= samples[valueof(half_bit_period)];
        endaction;

    (* fire_when_enabled *)
    rule do_detect_edge;
        // Take a slice of the bit samples and match against the edge pattern. For a bit_period of 4
        // samples and a positive polarity edge pattern, this effectively looks like comparing
        // against 'b?110. For a bit period of 8 samples and negative polarity the comparison would
        // be against 'b???00001.
        Bit#(edge_pattern_sz) sample_slice = samples[valueof(half_bit_period):0];

        if (detect_edge(sample_slice, polarity)) begin
            // (Re-)align the strobe with the bit edge. Empirically it seems that instead of
            // resetting the strobe to 0, setting it to +1 step results in a sample point closer to
            // the center of the bit period.
            strobe <= fromInteger(strobe.step());
            edge_detected.send();
        end

        samples <= {d, samples[valueof(bit_period_msb):1]};
        sample_bit();
    endrule

    // sampled_bit should be written continuously in order to allow enqueueing to the output FIFO
    // whenever the strobe pulses. This rule will fire when do_sample does not, making sure this is
    // true.
    (* descending_urgency = "do_detect_edge, do_write_sampled_bit" *)
    rule do_write_sampled_bit;
        sample_bit();
    endrule

    (* fire_when_enabled *)
    rule do_sample ((search_for_bit_edge_ && edge_detected) || (!search_for_bit_edge_ && strobe));
        q.enq(sampled_bit);
    endrule

    interface Put in;
        method put = d._write;
    endinterface
    interface Get out = toGet(q);
    method search_for_bit_edge = search_for_bit_edge_.send;
endmodule

endpackage : BitSampling

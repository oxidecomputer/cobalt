// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package BitSamplingTests;

import BuildVector::*;
import GetPut::*;
import Probe::*;
import Randomizable::*;
import StmtFSM::*;
import Vector::*;

import BitSampling::*;
import TestUtils::*;


interface BitSamplingTest #(numeric type bit_period);
endinterface

//
// `mkSignalGenerator` is a helper which takes a set of expected bit samples and
// turns it into a signal with a given nominal bit period. Optionally, a
// randomizer is used to simulate aliasing in the signal as a result of clock
// jitter.
//
module mkSignalGenerator #(
        Vector#(n, Bit#(1)) signal_samples_,
        Bool enable_jitter,
        BitSampler#(bit_period_t) sampler,
        Bool sampler_initialized)
            (Empty)
                provisos (
                    Log#(bit_period_t, bit_period_sz),
                    Add#(bit_period_sz, 1, i_sz));

    // Samples from which to generate a signal.
    Reg#(Vector#(n, Bit#(1))) signal_samples <- mkReg(signal_samples_);

    // Probe to make it easier to monitor the generated signal during debug.
    Probe#(Bit#(1)) signal <- mkProbe();

    // The signal generator can add aliasing/jitter to the generated signal,
    // shortening or stretching each bit period by 1. This is enabled using the
    // `enable_jitter` flag. If no jitter is desired the min/max bounds of the
    // generator as set such that it generates the nominal bit period on every
    // invocation.
    let bit_period_min = fromInteger(valueOf(bit_period_t) - 1);
    let bit_period_max = fromInteger(valueOf(bit_period_t) + 1);
    let bit_period_nominal = fromInteger(valueOf(bit_period_t));

    Randomize#(UInt#(i_sz)) bit_period_generator <-
            mkConstrainedRandomizer(
                enable_jitter ? bit_period_min : bit_period_nominal,
                enable_jitter ? bit_period_max : bit_period_nominal);

    Reg#(UInt#(i_sz)) i <- mkReg(0);
    Reg#(UInt#(i_sz)) bit_period <- mkReg(bit_period_nominal);

    function Action get_next_bit_period() =
        action
            let bit_period_with_jitter <- bit_period_generator.next;

            // To avoid stacking shorter/longer bit periods for consequitive
            // bits, which is not representative of aliasing as a result of
            // clock jitter, only allow a shorter/longer bit period if the
            // previous period was nominal.
            if (bit_period == bit_period_nominal)
                bit_period <= bit_period_with_jitter;
            else
                bit_period <= bit_period_nominal;

            i <= 0;
        endaction;

    function Action set_sample(Bit#(1) b) =
        action
            sampler.in.put(b);
            signal <= b;
        endaction;

    mkAutoFSM(seq
        // Initialize the generator and set the initial bit period.
        bit_period_generator.cntrl.init();
        get_next_bit_period();

        // Drive the sampler until it is initialized.
        while (!sampler_initialized) set_sample(0);

        while (True) action
            set_sample(signal_samples[0]);

            // At the end of the bit period, shift the next bit into slot 0.
            if (i == (bit_period - 1)) begin
                signal_samples <= rotate(signal_samples);
                get_next_bit_period();
            end

            // Count down the current bit period.
            else begin
                i <= i + 1;
            end
        endaction
    endseq);
endmodule

module mkBitSamplingTest #(Bool enable_jitter) (BitSamplingTest#(bit_period))
        provisos (
            Add#(2, a__, bit_period),
            NumAlias#(24, n),
            Log#(n, n_sz));
    BitSampler#(bit_period) sampler <- mkBitSampler();
    Reg#(Bool) sampler_initialized <- mkReg(False);

    Reg#(UInt#(n_sz)) i <- mkReg(0);
    Vector#(n, Bit#(1)) expected_samples = vec(
            1, 1, 0, 0, 1, 0, 1, 1,
            1, 0, 0, 0, 1, 1, 0, 0,
            1, 0, 1, 1, 1, 0, 0, 0);

    mkSignalGenerator(
            expected_samples,
            enable_jitter,
            sampler,
            sampler_initialized);

    // Samples buffer.
    Reg#(Vector#(n, Bit#(1))) samples <- mkReg(replicate(0));

    mkAutoFSM(seq
        // Wait for the first sample and mark the sampler initialized.
        action
            assert_get_any(sampler.out);
            sampler_initialized <= True;
        endaction

        // Sample n bits.
        for (i <= 0; i < fromInteger(valueOf(n)); i <= i + 1) action
            let sample <- sampler.out.get;
            samples <= shiftInAtN(samples, sample);
        endaction

        // The timing of the signal generator, sampler initialized flag and the
        // sample sequence above is a bit awkward. This causes a false negative
        // test result if the bit period is 2 because an extra 0 is sampled at
        // the beginning of the sequence and the last bit is missed. For this
        // case only, rotate the samples afterwards, causing that bit at the
        // beginning to be put at the end, correcting this result.
        if (valueOf(bit_period) == 2) action
            samples <= rotate(samples);
        endaction

        assert_eq(samples, expected_samples, "unexpected samples");
    endseq);
endmodule

// Tests using a nominal bit period.

module mkBitSampling2Test (Empty);
    (* hide *) BitSamplingTest#(2) _t <- mkBitSamplingTest(False);
endmodule

module mkBitSampling3Test (Empty);
    (* hide *) BitSamplingTest#(3) _t <- mkBitSamplingTest(False);
endmodule

module mkBitSampling4Test (Empty);
    (* hide *) BitSamplingTest#(4) _t <- mkBitSamplingTest(False);
endmodule

module mkBitSampling5Test (Empty);
    (* hide *) BitSamplingTest#(5) _t <- mkBitSamplingTest(False);
endmodule

module mkBitSampling8Test (Empty);
    (* hide *) BitSamplingTest#(8) _t <- mkBitSamplingTest(False);
endmodule

module mkBitSampling16Test (Empty);
    (* hide *) BitSamplingTest#(16) _t <- mkBitSamplingTest(False);
endmodule

// Tests with jitter/aliasing enabled. Note that there is no jitter test for a
// bit period of 2 since this is not a valid mode for the sampler.

// This test with jitter for a bit period of 3 is senstitive to the random
// values generated during the longer sequences without transitions. I (arjen)
// did not want to add more complicated logic to generating these random bit
// periods, so if this is a problem in the future it would be acceptable to
// either tweak the generator more or disable this test altogether.
module mkBitSampling3JitterTest (Empty);
    (* hide *) BitSamplingTest#(3) _t <- mkBitSamplingTest(True);
endmodule

module mkBitSampling4JitterTest (Empty);
    (* hide *) BitSamplingTest#(4) _t <- mkBitSamplingTest(True);
endmodule

module mkBitSampling5JitterTest (Empty);
    (* hide *) BitSamplingTest#(5) _t <- mkBitSamplingTest(True);
endmodule

module mkBitSampling8JitterTest (Empty);
    (* hide *) BitSamplingTest#(8) _t <- mkBitSamplingTest(True);
endmodule

module mkBitSampling16JitterTest (Empty);
    (* hide *) BitSamplingTest#(16) _t <- mkBitSamplingTest(True);
endmodule

//
// This case tests a specific scenario where a bit edge occurs simultaneously
// with the periodic sample strobe. In this case the sampled bit period is
// erroneously made longer (because the bit edge is expected to delay the next
// sample point), in turn causing the first byte of a UART transmission to be
// corrupted.
//
// Note that this test uses a bit period of 5, but this happens at any bit
// period. It was simply chosen to mirror logic analyzer data.
//
module mkAsyncBitSamplingTest (Empty);
    BitSampler#(5) sampler <- mkBitSampler();
    Reg#(Bit#(1)) sample <- mkReg(0);
    RWire#(Bit#(1)) next_sample <- mkRWire();

    Reg#(UInt#(4)) i <- mkReg(1);

    (* fire_when_enabled *)
    rule do_sample;
        let s <- sampler.out.get;
        next_sample.wset(s);
    endrule

    (* fire_when_enabled *)
    rule do_count_bit_period;
        let sample_next = fromMaybe(sample, next_sample.wget);
        sample <= sample_next;

        if (sample == 1 && sample_next == 0)
            i <= 0;
        else if (sample == 0)
            i <= i + 1;
    endrule

    mkAutoFSM(seq
        repeat(10) sampler.in.put(1); // idle high
        repeat(5) sampler.in.put(0);  // start bit
        repeat(5) sampler.in.put(1);  // next bit

        assert_eq(i, 5, "expected bit period of zero bit to be 5 cycles");
    endseq);
endmodule

endpackage

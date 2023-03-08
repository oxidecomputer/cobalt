// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package BitSampling;

export BitSampler(..);
export mkBitSampler;

import ConfigReg::*;
import DReg::*;
import GetPut::*;
import Vector::*;

//
// A `BitSampler` can be used to implement sampling primitives which recover
// received bits from an incoming signal. The number of samples per bit is given
// by the `bit_period`.
//
interface BitSampler #(numeric type bit_period);
    interface Put#(Bit#(1)) in;
    interface Get#(Bit#(1)) out;
endinterface

//
// `mkBitSampler` is an asynchronous implementation of the `BitSampler`
// interface. It assumes a source producing a bit signal with a constant given
// bit period.
//
// Without any bit edges in the signal the sampler will provide a sampled bit
// every `bit_period` iterations. Any time an edge is detected in the signal the
// sample point is re-aligned in an attempt to sample the next bit near the
// center of the bit period. This allows the sampler to track the signal source
// despite some amount of clock jitter and sampling aliasing. This works
// particularly well for signals with short run lengths but can also be applied
// to signals witn an asynchronous encoding.
//
// It is theoretically possible to use a bit period of three samples on external
// signals if the clocks in both systems have sufficient jitter performance.
// Samplers with a bit period of five and more samples have been succesfully
// demonstrated using real hardware, with both synchronous (8B10B encoded)
// signals and asynchronous encoded (UART) signals. A bit period of two can only
// be used between systems with an alias free channel.
//
// Note that due to the sampler re-aligning on every bit edge it is not suited
// for use with signals with uneven bit periods, such as a PWM or I^2C signal.
//
module mkBitSampler (BitSampler#(bit_period))
        provisos (
            // The bit period should last two or more samples.
            Add#(2, a__, bit_period),
            // Ceiling of bit_period / 2. This works correct for odd count
            // periods.
            Div#(bit_period, 2, half_bit_period));

    ConfigReg#(Vector#(2, Bit#(1))) samples <- mkConfigRegU();
    Reg#(UInt#(TLog#(bit_period))) count <- mkRegU();
    Reg#(Bool) sample_valid <- mkDReg(False);

    interface Put in;
        method Action put(Bit#(1) b);
            // Sampler events.
            let bit_edge = (samples[1] != samples[0]);
            let count_zero = (count == 0);

            // Shift in the next sample.
            samples <= shiftInAtN(samples, b);

            // The current sample in `samples[0]` can only be valid if no bit
            // edge is detected. Marking a sample valid during a transition
            // would lead to the edge being sampled too early which may corrupt
            // the first of an asynchronous signal.
            sample_valid <= !bit_edge && count_zero;

            // Set the counter untill the next sample being valid. This attempts
            // to aim for the center of the next bit period.
            //
            // If the bit period is even the sample point should be as late as
            // possible in the first half of the bit period. If delayed past the
            // half bit period an early bit edge may bit to be missed.
            //
            // If the bit period is odd the sample point should be in the center
            // of the bit.
            count <= (begin
                if (bit_edge)
                    // Special case for a bit period of 2 since otherwise the
                    // counter will wrap around. For this bit period the sample
                    // point is on the next iteration.
                    if (valueOf(bit_period) == 2)
                        0;
                    else
                        fromInteger(valueOf(half_bit_period) - 2);

                else if (count_zero)
                    // Sample at the same point in one full bit period.
                    fromInteger(valueOf(bit_period) - 1);

                else
                    (count - 1);
                end);
        endmethod
    endinterface

    interface Get out;
        method ActionValue#(Bit#(1)) get() if (sample_valid);
            return samples[0];
        endmethod
    endinterface
endmodule

endpackage: BitSampling

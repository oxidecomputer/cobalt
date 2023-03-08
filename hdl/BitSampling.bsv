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
// A `BitSampler` can be used to implement (over)sampling primitives which
// recover received bits from an incoming signal. The number of samples per bit
// is given by the `bit_period`.
//
interface BitSampler #(numeric type bit_period);
    interface Put#(Bit#(1)) in;
    interface Get#(Bit#(1)) out;
endinterface

//
// `mkBitSampler` is an asynchronous implementation of the `BitSampler`
// interface. It assumes a source producing a bit signal with a constant given
// bit period, oversamples this signal and aims to provide the sample closest to
// the center of the bit period to downstream logic.
//
// Without any bit edges in the signal the sampler will provide a sample on its
// `out` interface every `bit_period` invocations of the `in` interface. Any
// time an edge is detected in the signal the strobe indicating which sample is
// to be returned is re-aligned in an attempt to hit near the center of the
// following bit period. This allows the sampler to track the signal source
// despite some amount of clock jitter and sampling aliasing. This works
// particularly well for signals with short run lengths but has been applied to
// signals with longer run lengths and asynchronous encoding.
//
// This module assumes downstream logic can accept a sample from the `out`
// interface the next cycle it is marked available. If this can not be
// guaranteed a FIFO should be inserted between the `out` interface and
// downstream logic.
//
// It is theoretically possible to use a bit period of three samples on external
// signals if the clocks in both systems have sufficient jitter performance.
// Samplers with a bit period of five and more samples have been succesfully
// demonstrated using real hardware, with both synchronous (8B10B encoded)
// signals and asynchronous encoded (UART) signals. A bit period of two can only
// be used between systems with an alias-free channel.
//
// Note that due to the sampler re-aligning on every bit edge it is not suited
// for use with signals with uneven bit periods, such as PWM or I^2C signals.
//
module mkBitSampler (BitSampler#(bit_period))
        provisos (
            // The bit period should last two or more samples.
            Add#(2, a__, bit_period),
            // Ceiling of bit_period / 2. This works correct for odd count
            // periods.
            Div#(bit_period, 2, half_bit_period));

    // Sample buffer used by the edge detector.
    ConfigReg#(Vector#(2, Bit#(1))) samples <- mkConfigRegU();

    // Counter used to determine the next bit center.
    Reg#(UInt#(TLog#(bit_period))) samples_until_bit_center <- mkRegU();

    // Strobe indicating the sample in `samples[0]` is valid for downstream
    // logic and used as a guard on the `out` interface.
    Reg#(Bool) sample0_valid <- mkDReg(False);

    interface Put in;
        method Action put(Bit#(1) b);
            // Shift the next sample into the buffer/edge detector.
            samples <= shiftInAtN(samples, b);

            // The sampler relies on two events; the detection of edges in the
            // sampled signal and a counter used to approximate the center of a
            // bit period.
            let bit_edge = (samples[1] != samples[0]);
            let bit_center = (samples_until_bit_center == 0);

            // The sample currently in `samples[0]` can only be valid if no edge
            // is detected. Marking this sample valid during a transition would
            // lead to the edge appearing too early to downstream logic which
            // may corrupt the first bits of an asynchronous signal.
            sample0_valid <= !bit_edge && bit_center;

            // Update the count down to the center of the next bit period. The
            // order of this decision tree matters;
            //
            // If an edge is detected in the signal, the next center is ~half a
            // bit period in the future and the count down should be adjusted
            // accordingly. This matches the decision above to not mark
            // `sample[0]` valid when a bit edge is detected.
            if (bit_edge)
                // Special case for a bit period of 2 since otherwise the
                // counter will wrap around. For this bit period the sample
                // point is on the next iteration.
                if (valueOf(bit_period) == 2)
                    samples_until_bit_center <= 0;
                else
                    samples_until_bit_center <=
                        fromInteger(valueOf(half_bit_period) - 2);

            // If the center of a bit period is reached the count down should be
            // re-armed for one full bit period into the future.
            else if (bit_center)
                samples_until_bit_center <= fromInteger(valueOf(bit_period) - 1);

            // If neither of these conditions are true simply count down to the
            // next bit center.
            else
                samples_until_bit_center <= samples_until_bit_center - 1;
        endmethod
    endinterface

    interface Get out;
        method ActionValue#(Bit#(1)) get() if (sample0_valid);
            return samples[0];
        endmethod
    endinterface
endmodule

endpackage: BitSampling

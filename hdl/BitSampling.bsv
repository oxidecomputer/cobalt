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


interface BitSampler #(numeric type bit_period);
    interface Put#(Bit#(1)) in;
    interface Get#(Bit#(1)) out;
endinterface

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
            let bit_edge = (samples[1] != samples[0]);
            let do_sample = (count == 0);

            samples <= shiftInAtN(samples, b);
            sample_valid <= do_sample;

            count <= (begin
                if (do_sample)
                    // Sample at the same point in one full bit period.
                    fromInteger(valueOf(bit_period) - 1);
                else if (bit_edge)
                    // Sample near the center of the current bit period.
                    //
                    // If the bit period is 2 the sample point is on the next
                    // cycle.
                    if (valueOf(bit_period) == 2) begin
                        0;
                    end

                    // If the bit period is even the sample point should be one
                    // sample past half bit period in order to allow maximum
                    // time to observe a possible next bit transition.
                    else if (valueOf(half_bit_period) % 2 == 0) begin
                        fromInteger(valueOf(half_bit_period) - 1);
                    end

                    // If the bit period is odd the sample point should be the
                    // center sample of the bit period.
                    else begin
                        fromInteger(valueOf(half_bit_period) - 2);
                    end
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

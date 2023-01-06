// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package BitSamplingTests;

import BuildVector::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

import BitSampling::*;
import TestUtils::*;


interface BitSamplingTest #(numeric type bit_period);
endinterface

module mkBitSamplingTest (BitSamplingTest#(bit_period))
        provisos (Add#(2, a__, bit_period));
    BitSampler#(bit_period) sampler <- mkBitSampler();
    Reg#(Bool) sampler_initialized <- mkReg(False);

    // Signal to be sampled.
    Reg#(Bit#(1)) v <- mkReg(0);
    Reg#(UInt#(4)) i <- mkReg(0);
    Reg#(UInt#(4)) j <- mkReg(0);

    // Samples.
    Reg#(UInt#(4)) k <- mkReg(0);
    Reg#(Vector#(10, Bit#(1))) samples <- mkReg(replicate(0));

    Vector#(10, Bit#(1)) expected_samples = vec(1, 1, 0, 0, 1, 1, 0, 0, 1, 1);

    (* fire_when_enabled *)
    rule do_put_v;
        sampler.in.put(v);

        if (i == fromInteger(valueOf(bit_period) - 1)) begin
            i <= 0;
            j <= j + 1;

            if (j > 0 && j % 2 == 1) begin
                v <= ~v;
                // The sampler needs to observe at least one signal edge before
                // its counter is in a known state. Set this flag so the test
                // script knows when to start sampling.
                sampler_initialized <= True;
            end
        end
        else begin
            i <= i + 1;
        end
    endrule

    mkAutoFSM(seq
        await(sampler_initialized);

        for (k <= 0; k < 10; k <= k + 1) action
            let s <- sampler.out.get;
            samples[k] <= s;
        endaction

        assert_eq(samples, expected_samples, "unexpected samples");
    endseq);
endmodule

module mkBitSampling2Test (Empty);
    (* hide *) BitSamplingTest#(2) _t <- mkBitSamplingTest();
endmodule

module mkBitSampling3Test (Empty);
    (* hide *) BitSamplingTest#(3) _t <- mkBitSamplingTest();
endmodule

module mkBitSampling4Test (Empty);
    (* hide *) BitSamplingTest#(4) _t <- mkBitSamplingTest();
endmodule

module mkBitSampling5Test (Empty);
    (* hide *) BitSamplingTest#(5) _t <- mkBitSamplingTest();
endmodule

module mkBitSampling8Test (Empty);
    (* hide *) BitSamplingTest#(8) _t <- mkBitSamplingTest();
endmodule

module mkBitSampling16Test (Empty);
    (* hide *) BitSamplingTest#(16) _t <- mkBitSamplingTest();
endmodule

endpackage

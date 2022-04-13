// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2cTest;

import I2c::*;

import Assert::*;
import StmtFSM::*;

typedef struct {
    Integer core_clk_freq;
    Integer scl_freq;
} BitControlParams;

BitControlParams test_params    = BitControlParams {
                                    core_clk_freq: 4000,
                                    scl_freq: 100};

(* synthesize *)
module mkI2cBitControlStartTest (Empty);
    BitControl bit_ctrl <- mkBitControl(test_params.core_clk_freq, test_params.scl_freq);

    mkAutoFSM(seq
        // check state coming out of reset
        action
            dynamicAssert(bit_ctrl.pins.scl_o == 1, "SCL should be high");
            dynamicAssert(bit_ctrl.pins.sda_o == 1, "SDA should be high");
            dynamicAssert(!bit_ctrl.busy, "bit control should not be busy");
        endaction
        // Generate START condition
        bit_ctrl.start(True);
        delay(1);
        action
            dynamicAssert(bit_ctrl.pins.scl_o == 1, "SCL should be high");
            dynamicAssert(bit_ctrl.pins.sda_o == 0, "SDA should be low");
            dynamicAssert(bit_ctrl.busy, "bit control should be busy");
        endaction
        delay(10);
        action
            dynamicAssert(bit_ctrl.pins.scl_o == 0, "SCL should be low");
            dynamicAssert(bit_ctrl.pins.sda_o == 0, "SDA should be low");
            dynamicAssert(!bit_ctrl.busy, "bit control should not be busy");
        endaction
    endseq);
endmodule

(* synthesize *)
module mkI2cBitControlStopTest (Empty);
    BitControl bit_ctrl <- mkBitControl(test_params.core_clk_freq, test_params.scl_freq);

    mkAutoFSM(seq
        // Generate START condition
        bit_ctrl.start(True);
        await(!bit_ctrl.busy);
        // Generate STOP condition
        bit_ctrl.stop(True);
        delay(1);
        action
            dynamicAssert(bit_ctrl.pins.scl_o == 1, "SCL should be high");
            dynamicAssert(bit_ctrl.pins.sda_o == 0, "SDA should be low");
        endaction
        delay(10);
        action
            dynamicAssert(bit_ctrl.pins.scl_o == 1, "SCL should be high");
            dynamicAssert(bit_ctrl.pins.sda_o == 1, "SDA should be high");
        endaction
    endseq);
endmodule


endpackage: I2cTest
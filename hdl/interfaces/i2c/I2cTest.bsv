// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2c_test;

import I2c::*;

import Assert::*;
import StmtFSM::*;

(* synthesize *)
module mkI2cBitControlTest (Empty);
    BitControl bit_ctrl <- mkBitControl(500, 100);
    
    mkAutoFSM(seq
        // check state coming out of reset
        action
            dynamicAssert(bit_ctrl.pins.scl_o == 1, "SCL should be high");
            dynamicAssert(bit_ctrl.pins.sda_o == 1, "SDA should be high")
        endaction
    endseq);
endmodule

(* synthesize *)
module mkI2cWriteTest (Empty);
endmodule

endpackage: I2c_test
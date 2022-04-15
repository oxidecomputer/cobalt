// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2cTest;

import I2c::*;

import Assert::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

typedef struct {
    Integer core_clk_freq;
    Integer scl_freq;
} BitControlParams;

BitControlParams test_params    = BitControlParams {
                                    core_clk_freq: 4000,
                                    scl_freq: 100};

interface Bench;
    method Bit#(8) read();
    method Bool error();

    method Action write(Bit#(8) byte_);
    method Action clear();
endinterface

module mkBench (Bench);
    BitControl dut <- mkBitControl(test_params.core_clk_freq, test_params.scl_freq);

    method error = dut.error;
    method Action clear = dut.clear;

    method Action write(Bit#(8) byte_);
        dut.send.put(tagged Start);
        dut.send.put(tagged Write byte_);
        dut.send.put(tagged Stop);
    endmethod
endmodule

(* synthesize *)
module mkI2cBitControlOneByteWriteTest (Empty);
    Bench bench <- mkBench();

    Reg#(Bit#(1)) sda_i <- mkReg(0);

    mkConnection(sda_i, bit_ctrl.pins.sda_i);

    mkAutoFSM(seq
        // check state coming out of reset
        action
            dynamicAssert(bit_ctrl.pins.scl_o == 1, "SCL should be high");
            dynamicAssert(bit_ctrl.pins.sda_o == 1, "SDA should be high");
        endaction
        // send Event::Start
        bit_ctrl.send.put(tagged Start);
        bit_ctrl.send.put(tagged Write 8'b11010011);
        bit_ctrl.send.put(tagged Stop);
        action
            let e <- bit_ctrl.receive.get();
            dynamicAssert(e == tagged Ack, "Expected an ACK");
        endaction
        delay(200);
    endseq);
endmodule

endpackage: I2cTest
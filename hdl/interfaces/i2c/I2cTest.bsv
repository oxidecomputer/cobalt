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
    Bit#(7) peripheral_addr;
} BitControlParams;

BitControlParams test_params    = BitControlParams {
                                    core_clk_freq: 4000,
                                    scl_freq: 100,
                                    peripheral_addr: 7'b1010110};

interface Bench;
    method Bool busy();

    method Bit#(8) read();
    method Action write(Bit#(8) byte_);
    method Bool error();
    method Action clear();
endinterface

module mkBench (Bench);
    BitControl dut <- mkBitControl(test_params.core_clk_freq, test_params.scl_freq);
    I2CPeripheralModel periph <- mkI2CPeripheralModel(test_params.peripheral_addr);

    mkConnection(dut.pins.scl_o, periph.scl_i);
    mkConnection(dut.pins.sda_o, periph.sda_i);
    mkConnection(dut.pins.sda_o_en, periph.sda_i_en);
    mkConnection(dut.pins.sda_i, periph.sda_o);

    Reg#(Bit#(8)) wr_data   <- mkReg(0);
    Reg#(Bit#(8)) rd_data   <- mkReg(0);

    FSM write_seq <- mkFSM(seq
        dut.send.put(tagged Start);
        dut.send.put(tagged Write wr_data);
        dut.send.put(tagged Stop);
    endseq);

    method busy = !write_seq.done();

    method Action write(Bit#(8) byte_);
        wr_data <= byte_;
        write_seq.start();
    endmethod

    method error = dut.error;
    method Action clear = dut.clear;
endmodule

(* synthesize *)
module mkI2cBitControlOneByteWriteTest (Empty);
    Bench bench <- mkBench();
    // BitControl dut <- mkBitControl(test_params.core_clk_freq, test_params.scl_freq);

    // Reg#(Bit#(1)) sda_i <- mkReg(0);

    // mkConnection(sda_i, bench.dut.pins.sda_i);

    mkAutoFSM(seq
        // check state coming out of reset
        // action
        //     dynamicAssert(bench.dut.pins.scl_o == 1, "SCL should be high");
        //     dynamicAssert(bench.dut.pins.sda_o == 1, "SDA should be high");
        // endaction
        // send Event::Start
        bench.write(8'b10101100);
        await(!bench.busy());
        // bench.dut.send.put(tagged Write 8'b11010011);
        // bench.dut.send.put(tagged Stop);
        // action
        //     let e <- bench.dut.receive.get();
        //     dynamicAssert(e == tagged Ack, "Expected an ACK");
        // endaction
        delay(20);
    endseq);
endmodule

endpackage: I2cTest
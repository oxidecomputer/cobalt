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

typedef struct {
    Bit#(8) reg_addr;
    Bit#(8) data;
} WriteByte deriving (Bits, Eq, FShow);

WriteByte default_write_byte = WriteByte {
                                reg_addr: 8'hFF,
                                data: 8'hFF};

interface Bench;
    method Bool busy();

    method Action read(Bit#(8) reg_addr);
    method Action write(WriteByte cmd);
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

    Reg#(Bit#(8)) addr_write    <- mkReg({test_params.peripheral_addr, 1'b0});
    Reg#(Bit#(8)) addr_read     <- mkReg({test_params.peripheral_addr, 1'b1});
    Reg#(WriteByte) wr_byte_cmd <- mkReg(default_write_byte);

    FSM write_seq <- mkFSM(seq
        dut.send.put(tagged Start);
        dut.send.put(tagged Write addr_write);
        action
            let e <- periph.receive.get();
            dynamicAssert (e == tagged ReceivedStart, "Expected to receive START");
        endaction
        action
            let e <- periph.receive.get();
            dynamicAssert (e == tagged AddressMatch, "Expected address to match");
        endaction
        action
            let e <- dut.receive.get();
            dynamicAssert (e == tagged Ack, "Expected an ACK on the command");
        endaction
        dut.send.put(tagged Write wr_byte_cmd.reg_addr);
        action
            let e <- dut.receive.get();
            dynamicAssert (e == tagged Ack, "Expected an ACK on the data");
        endaction
        action
            let e <- periph.receive.get();
            dynamicAssert (e == tagged ReceivedData wr_byte_cmd.reg_addr, "Expected to receive reg addr that was sent");
        endaction
        dut.send.put(tagged Write wr_byte_cmd.data);
        dut.send.put(tagged Stop);
        action
            let e <- periph.receive.get();
            dynamicAssert (e == tagged ReceivedData wr_byte_cmd.data, "Expected to receive data that was sent");
        endaction
        action
            let e <- dut.receive.get();
            dynamicAssert (e == tagged Ack, "Expected an ACK on the data");
        endaction
        action
            let e <- periph.receive.get();
            dynamicAssert (e == tagged ReceivedStop, "Expected to receive STOP");
        endaction
    endseq);

    method busy = !write_seq.done();

    method Action write(WriteByte cmd);
        wr_byte_cmd <= cmd;
        write_seq.start();
    endmethod

    method error = dut.error;
    method Action clear = dut.clear;
endmodule

(* synthesize *)
module mkI2cBitControlOneByteWriteTest (Empty);
    Bench bench <- mkBench();

    WriteByte payload = WriteByte {
        reg_addr: 8'hA5,
        data: 8'h3C
    };

    mkAutoFSM(seq
        delay(200);
        bench.write(payload);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

endpackage: I2cTest
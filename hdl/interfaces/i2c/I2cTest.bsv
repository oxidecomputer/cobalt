// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2cTest;

import I2c::*;

import Assert::*;
import BuildVector::*;
import Connectable::*;
import DefaultValue::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

typedef struct {
    Integer core_clk_freq;
    Integer scl_freq;
    Bit#(7) peripheral_addr;
} BitControlParams;

BitControlParams test_params = BitControlParams {
    core_clk_freq: 4000,
    scl_freq: 100,
    peripheral_addr: 7'b1010110
};

typedef enum {
    Write       = 0,
    Read        = 1,
    RandomRead  = 2
} OpType deriving (Eq, Bits, FShow);

typedef struct {
    OpType op;
    Bit#(7) peripheral_addr;
    Bit#(8) register_addr;
    Vector#(4, Maybe#(Bit#(8))) data;
} Command deriving (Bits, Eq, FShow);

instance DefaultValue #(Command);
    defaultValue = Command {
        op: Read,
        peripheral_addr: 7'h7F,
        register_addr: 8'hFF,
        data: vec(tagged Invalid, tagged Invalid, tagged Invalid, tagged Invalid)
    };
endinstance

function Action check_peripheral_event(I2CPeripheralModel peripheral,
                                        I2c::ModelEvent expected,
                                        String message) = 
    action
        let e <- peripheral.receive.get();
        dynamicAssert (e == expected, message);
    endaction;

function Action check_controller_event(BitControl controller,
                                I2c::Event expected,
                                String message) = 
    action
        let e <- controller.receive.get();
        dynamicAssert (e == expected, message);
    endaction;

interface Bench;
    method Bool busy();

    method Action command(Command cmd);
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

    // Reg#(OpType) read_cmd_type     <- mkReg(Read);
    // Reg#(OpType) write_cmd_type    <- mkReg(Write);
    // Reg#(Bit#(7)) peripheral_addr       <- mkReg(test_params.peripheral_addr);

    Reg#(Command) command_r     <- mkReg(defaultValue);
    Reg#(Bit#(8)) read_reg_addr     <- mkReg(0);
    Reg#(UInt#(2)) seq_cntr <- mkReg(0);
    Wire#(Bool) busy_ <- mkWire();

    FSM write_seq <- mkFSMWithPred(seq
        dut.send.put(tagged Start);
        action
            let write_byte = {command_r.peripheral_addr, pack(command_r.op != Write)};
            dut.send.put(tagged Write write_byte);
        endaction

        check_peripheral_event(periph, tagged ReceivedStart, "Expected to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");
        check_controller_event(dut, tagged Ack, "Expected an ACK on the command");

        dut.send.put(tagged Write command_r.register_addr);

        check_controller_event(dut, tagged Ack, "Expected an ACK on the command");
        check_peripheral_event(periph, tagged ReceivedData command_r.register_addr, "Expected to receive reg addr that was sent");

        while (head(command_r.data) != tagged Invalid) seq
                dut.send.put(tagged Write fromMaybe(8'h00, head(command_r.data)));
                check_peripheral_event(periph, tagged ReceivedData fromMaybe(8'h00, head(command_r.data)), "Expected to receive data that was sent");
                check_controller_event(dut, tagged Ack, "Expected an ACK on the command");
                command_r.data  <= shiftOutFrom0(tagged Invalid, command_r.data, 1);
        endseq

        dut.send.put(tagged Stop);

        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");

    endseq, command_r.op == Write);

    FSM read_seq <- mkFSMWithPred(seq
    //     dut.send.put(tagged Start);
    //     action
    //         let read_byte = {peripheral_addr, pack(read_cmd_type)};
    //         dut.send.put(tagged Write read_byte);
    //     endaction

    //     check_peripheral_event(periph, tagged ReceivedStart, "Expected to receive START");
    //     check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");
    //     check_controller_event(dut, tagged Ack, "Expected an ACK on the command");

    //     dut.send.put(tagged Write command_r.reg_addr);

    //     check_controller_event(dut, tagged Ack, "Expected an ACK on the command");
    //     check_peripheral_event(periph, tagged ReceivedData command_r.reg_addr, "Expected to receive reg addr that was sent");
    endseq, command_r.op == Read);

    (* fire_when_enabled, no_implicit_conditions *)
    rule do_busy;
        busy_ <= !write_seq.done() || !read_seq.done();
    endrule

    method busy = busy_;

    method Action command(Command cmd) if (!busy_);
        command_r <= cmd;
        if (cmd.op == Write) begin
            write_seq.start();
        end else begin
            read_seq.start();
        end
    endmethod

    method error = dut.error;
    method Action clear = dut.clear;
endmodule

(* synthesize *)
module mkI2cBitControlOneByteWriteTest (Empty);
    Bench bench <- mkBench();

    Command payload = Command {
        op: Write,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hA5,
        data: vec(tagged Valid 8'h3C, tagged Invalid, tagged Invalid, tagged Invalid)
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(payload);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2cBitControlSequentialWriteTest (Empty);
    Bench bench <- mkBench();

    Command payload = Command {
        op: Write,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'h9D,
        data: vec(tagged Valid 8'hDE, tagged Valid 8'hAD,
                  tagged Valid 8'hBE, tagged Valid 8'hEF)
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(payload);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

// (* synthesize *)
// module mkI2cBitControlOneByteReadTest (Empty);
//     Bench bench <- mkBench();

//     Command payload = Command {
//         cmd: Read,
//         reg_addr: 8'h5A,
//         data: 8'hFF
//     };

//     mkAutoFSM(seq
//         delay(200);
//         bench.command(payload);
//         await(!bench.busy());
//         delay(200);
//     endseq);
// endmodule

endpackage: I2cTest
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

typedef Vector#(3, Maybe#(Bit#(8))) I2CBytes;

typedef struct {
    OpType op;
    Bit#(7) peripheral_addr;
    Bit#(8) register_addr;
    I2CBytes data;
    UInt#(2) read_length;
} Command deriving (Bits, Eq, FShow);

I2CBytes no_data = vec(tagged Invalid, tagged Invalid, tagged Invalid);

instance DefaultValue #(Command);
    defaultValue = Command {
        op: Read,
        peripheral_addr: 7'h7F,
        register_addr: 8'hFF,
        data: no_data,
        read_length: 1
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

    Reg#(Command) command_r                     <- mkReg(defaultValue);
    Reg#(Vector#(3,Bit#(8))) prev_written_bytes <- mkReg(replicate(0));
    Reg#(UInt#(2)) bytes_done                 <- mkReg(0);
    Reg#(Bool) is_last_byte                     <- mkReg(False);

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

        bytes_done <= 0;
        while (command_r.data[0] != tagged Invalid) seq
                dut.send.put(tagged Write fromMaybe(8'h00, command_r.data[0]));
                check_peripheral_event(periph, tagged ReceivedData fromMaybe(8'h00, command_r.data[0]), "Expected to receive data that was sent");
                check_controller_event(dut, tagged Ack, "Expected an ACK on the command");
                prev_written_bytes[bytes_done]   <= fromMaybe(8'h00, command_r.data[0]);
                bytes_done                       <= bytes_done + 1;
                command_r.data                   <= shiftOutFrom0(tagged Invalid, command_r.data, 1);
        endseq

        dut.send.put(tagged Stop);
        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");

    endseq, command_r.op == Write);

    FSM read_seq <- mkFSMWithPred(seq
        dut.send.put(tagged Start);
        action
            let read_byte = {command_r.peripheral_addr, pack(command_r.op != Write)};
            dut.send.put(tagged Write read_byte);
        endaction

        check_peripheral_event(periph, tagged ReceivedStart, "Expected to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");
        check_controller_event(dut, tagged Ack, "Expected an ACK on the command");

        bytes_done <= 0;
        while (bytes_done != command_r.read_length) seq
            is_last_byte <= bytes_done + 1 == command_r.read_length;
            dut.send.put(tagged Read is_last_byte);

            check_peripheral_event(periph, tagged TransmittedData prev_written_bytes[bytes_done], "Expected to read back written data");
            check_controller_event(dut, tagged ReadData prev_written_bytes[bytes_done], "Expected controller to receive byte");
            bytes_done <= bytes_done + 1;

            action
                if (is_last_byte) begin
                    check_peripheral_event(periph, tagged ReceivedNack, "Expected a Nack to end the read");
                end else begin
                    check_peripheral_event(periph, tagged ReceivedAck, "Expected an Ack to continue the read");
                end
            endaction
        endseq

        dut.send.put(tagged Stop);
        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");

    endseq, command_r.op == Read);

    FSM rnd_read_seq <- mkFSMWithPred(seq
        dut.send.put(tagged Start);

        action
            let write_byte = {command_r.peripheral_addr, 1'b0};
            dut.send.put(tagged Write write_byte);
        endaction

        check_peripheral_event(periph, tagged ReceivedStart, "Expected to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");
        check_controller_event(dut, tagged Ack, "Expected an ACK on the command");

        dut.send.put(tagged Write command_r.register_addr);

        check_controller_event(dut, tagged Ack, "Expected an ACK on the command");
        check_peripheral_event(periph, tagged ReceivedData command_r.register_addr, "Expected to receive reg addr that was sent");

        dut.send.put(tagged Start);

        action
            let read_byte = {command_r.peripheral_addr, pack(command_r.op != Write)};
            dut.send.put(tagged Write read_byte);
        endaction

        check_peripheral_event(periph, tagged ReceivedStart, "Expected to receive START");
        check_peripheral_event(periph, tagged AddressMatch, "Expected address to match");
        check_controller_event(dut, tagged Ack, "Expected an ACK on the command");

        bytes_done <= 0;
        while (bytes_done != command_r.read_length) seq
            is_last_byte <= bytes_done + 1 == command_r.read_length;
            dut.send.put(tagged Read is_last_byte);

            check_peripheral_event(periph, tagged TransmittedData prev_written_bytes[bytes_done], "Expected to read back written data");
            check_controller_event(dut, tagged ReadData prev_written_bytes[bytes_done], "Expected controller to receive byte");
            bytes_done <= bytes_done + 1;

            action
                if (is_last_byte) begin
                    check_peripheral_event(periph, tagged ReceivedNack, "Expected a Nack to end the read");
                end else begin
                    check_peripheral_event(periph, tagged ReceivedAck, "Expected an Ack to continue the read");
                end
            endaction
        endseq

        dut.send.put(tagged Stop);
        check_peripheral_event(periph, tagged ReceivedStop, "Expected to receive STOP");
    endseq, command_r.op == RandomRead);

    method busy = !write_seq.done() || !read_seq.done() || !rnd_read_seq.done();

    method Action command(Command cmd) if (write_seq.done() && read_seq.done() && rnd_read_seq.done());
        command_r <= cmd;
        if (cmd.op == Write) begin
            write_seq.start();
        end else if (cmd.op == Read) begin
            read_seq.start();
        end else begin
            rnd_read_seq.start();
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
        data: vec(tagged Valid 8'h3C, tagged Invalid, tagged Invalid),
        read_length: 0
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
        data: vec(tagged Valid 8'hDE, tagged Valid 8'hAD, tagged Valid 8'hBE),
        read_length: 0
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(payload);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2cBitControlOneByteReadTest (Empty);
    Bench bench <- mkBench();

    Command write_read_addr = Command {
        op: Write,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hA5,
        data: vec(tagged Valid 8'h3C, tagged Invalid, tagged Invalid),
        read_length: 0
    };

    Command read = Command {
        op: Read,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hFF,
        data: no_data,
        read_length: 1
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_read_addr);
        bench.command(read);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2cBitControlSequentialReadTest (Empty);
    Bench bench <- mkBench();

    Command write_data = Command {
        op: Write,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hA5,
        data: vec(tagged Valid 8'hAB, tagged Valid 8'hAD, tagged Valid 8'hBE),
        read_length: 0
    };

    Command write_read_addr = Command {
        op: Write,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hA5,
        data: no_data,
        read_length: 0
    };

    Command read = Command {
        op: Read,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hFF,
        data: no_data,
        read_length: 3
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_data);
        bench.command(write_read_addr);
        bench.command(read);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

(* synthesize *)
module mkI2cBitControlRandomReadTest (Empty);
    Bench bench <- mkBench();

    Command write_data = Command {
        op: Write,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hA5,
        data: vec(tagged Valid 8'hAB, tagged Valid 8'hAD, tagged Valid 8'hBE),
        read_length: 0
    };

    Command random_read = Command {
        op: RandomRead,
        peripheral_addr: test_params.peripheral_addr,
        register_addr: 8'hA5,
        data: no_data,
        read_length: 3
    };

    mkAutoFSM(seq
        delay(200);
        bench.command(write_data);
        bench.command(random_read);
        await(!bench.busy());
        delay(200);
    endseq);
endmodule

endpackage: I2cTest
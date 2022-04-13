// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2c;

import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import Strobe::*;

import I2cCoreRegs::*;

// If proper tri-stating requires access to device primitives, leave that up to
// the user to implement for their device. If not, push this down a layer and
// simple expose SCL/SDA Inout interfaces instead?
interface I2cPins;
    method Bit#(1) scl_o;
    method Action scl_i(Bit#(1) val);
    method Bit#(1) sda_o;
    method Action sda_i(Bit#(1) val);
endinterface

interface I2cCoreRegisters;
    method Action scl_prescale(Prescale val);
    method Action control(Control val);
    method Action transmit(Transmit val);
    method Receive receive;
    method Action command(Command val);
    method Status status;
endinterface

interface I2cCore;
    interface I2cPins pins;
    interface I2cCoreRegisters regs;
endinterface

typedef enum {
    Invalid = 0,
    Idle    = 1,
    Start   = 2,
    Read    = 3,
    Write   = 4,
    Ack     = 5
} I2cState deriving (Eq, Bits, FShow);

module mkI2cCore (I2cCore);

    Reg#(I2cState) core_state <- mkReg(Invalid);

    Wire#(Control) regs_ctrl    <- mkWire();
    Wire#(Command) regs_cmd     <- mkWire();
    Reg#(Bool) is_start_sent    <- mkReg(False);

    (* fire_when_enabled *)
    rule do_reset_core (core_state == Invalid);
        core_state <= Idle;
    endrule

    (* fire_when_enabled *)
    rule do_idle_state (core_state == Idle);
        if (regs_ctrl.en == 1 && regs_cmd.start == 1) begin
            core_state <= Start;
        end
    endrule

    (* fire_when_enabled *)
    rule do_start_state (core_state == Start);
        if (is_start_sent) begin
            if (regs_cmd.read == 1) begin
                core_state <= Read;
            end else begin
                core_state <= Write;
            end
        end
    endrule

    (* fire_when_enabled *)
    rule do_read_state (core_state == Read);

    endrule

    (* fire_when_enabled *)
    rule do_write_state (core_state == Write);

    endrule

    (* fire_when_enabled *)
    rule do_ack_state (core_state == Ack);

    endrule

    interface I2cCoreRegisters regs;
        method Action control(Control val)  = regs_ctrl._write(val);
        method Action command(Command val)  = regs_cmd._write(val);
    endinterface

endmodule

interface BitControl;
    interface I2cPins pins;
    interface Put#(Bit#(8)) wr_data;
    interface Get#(Bit#(8)) rd_data;
    method Action start(Bool val);
    method Action stop(Bool val);
    method Action write(Bool val);
    method Action read(Bool val);
    method Bool busy;
endinterface

module mkBitControl #(Integer core_clk_freq, Integer i2c_scl_freq) (BitControl);

    // generate strobe to toggle scl at a desired period
    // ex: 50MHz / 100KHz / 2 = 250
    Integer scl_half_period_limit = core_clk_freq / i2c_scl_freq / 2;

    Strobe#(8) scl_toggle_strobe <- mkLimitStrobe(1, scl_half_period_limit, 0);

    Reg#(Bool) in_transaction <- mkReg(False);

    Reg#(Bit#(1)) scl_  <- mkReg(1);
    Reg#(Bit#(1)) sda_  <- mkReg(1);
    Wire#(Bool) busy_   <- mkWire();

    PulseWire start_        <- mkPulseWire();
    PulseWire stop_         <- mkPulseWire();

    FSM gen_start <- mkFSMWithPred(seq
        sda_ <= 0;
        delay(10);
        scl_ <= 0;
    endseq, !scl_toggle_strobe);

    FSM gen_stop <- mkFSMWithPred(seq
        scl_ <= 1;
        delay(10);
        sda_ <= 1;
    endseq, !scl_toggle_strobe);

    (* fire_when_enabled *)
    rule do_tick_scl_toggle_strobe (in_transaction);
        scl_toggle_strobe.send();
    endrule

    (* fire_when_enabled *)
    rule do_scl_toggle_counter (scl_toggle_strobe);
        scl_ <= ~scl_;
    endrule

    (* fire_when_enabled, no_implicit_conditions *)
    rule do_busy;
        busy_ <= !gen_start.done() || !gen_stop.done();
    endrule

    (* fire_when_enabled *)
    rule do_start (start_ && !stop_ && !busy_);
        gen_start.start();
    endrule

    (* fire_when_enabled *)
    rule do_stop (stop_ && !start_ && !busy_);
        gen_stop.start();
    endrule

    method Action start(Bool val)   = start_.send;
    method Action stop(Bool val)    = stop_.send;

    method busy = busy_;

    interface I2cPins pins;
        method scl_o = scl_;
        method sda_o = sda_;
    endinterface

endmodule

endpackage: I2c
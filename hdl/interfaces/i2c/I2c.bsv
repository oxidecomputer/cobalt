// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package I2c;

import I2cCoreRegs::*;

// If proper tri-stating requires access to device primitives, leave that up to
// the user to implement for their device. If not, push this down a layer and
// simple expose SCL/SDA Inout interfaces instead?
interface I2cPins;
    method Bit(#1) scl_o;
    method Action scl_i(Bit#(1) val);
    method Bit(#1) sda_o;
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

    I2cState core_state <- mkReg(Invalid);

    Wire#(Control) regs_ctrl    <- mkWire();
    Wire#(Command) regs_cmd     <- mkWire();
    Reg#(Bool) is_start_sent    <- mkReg();

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

endpackage: I2c;
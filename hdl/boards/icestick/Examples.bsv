// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Examples;

import Board::*;

import Blinky::*;
import UART::*;
import UARTLoopback::*;


(* default_clock_osc="clk_12mhz" *)
module mkBlinky (Top);
    FTDI ftdi_noop <- mkFTDITieOff();
    IRDA irda_noop <- mkIRDATieOff();
    Blinky#(12_000_000) blinky <- Blinky::mkBlinky();

    interface FTDI ftdi = ftdi_noop;
    interface IRDA irda = irda_noop;
    method led() = {'0, blinky.led()};
endmodule

(* default_clock_osc="clk_12mhz" *)
module mkUARTLoopback (Top);
    IRDA irda_noop <- mkIRDATieOff();
    UARTLoopback#(12_000_000, 115200, 8) loopback <- UARTLoopback::mkUARTLoopback();

    // RX input register. Since the output of this register goes into additional FFs as part of the
    // bit sampler no meta instability is expected to occur.
    Reg#(Bit#(1)) rx_sync <- mkRegU();

    interface IRDA irda = irda_noop;

    interface FTDI ftdi;
        method rxd = loopback.serial.tx;
        method Action txd(Bit#(1) val);
            rx_sync <= val;
            loopback.serial.rx(rx_sync);
        endmethod

        // Ignore flow control.
        method Action rts_n(Bit#(1) val);
        endmethod
        method Bit#(1) cts_n() = 0;

        method Bit#(1) dcd_n() = 0;
        method Bit#(1) dsr_n() = 0;
        method Action dtr_n(Bit#(1) val);
        endmethod
    endinterface

    method led = 0;
endmodule

endpackage : Examples

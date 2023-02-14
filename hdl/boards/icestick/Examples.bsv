// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Examples;

import Board::*;
import IOSync::*;

import Blinky::*;
import LoopbackUART::*;


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
module mkLoopbackUART (Top);
    IRDA irda_noop <- mkIRDATieOff();
    LoopbackUART#(12_000_000, 115200, 8) uart <- LoopbackUART::mkLoopbackUART();

    interface IRDA irda = irda_noop;

    interface FTDI ftdi;
        method rxd = uart.serial.tx;
        method txd = uart.serial.rx;

        // Ignore flow control.
        method Action rts_n(Bit#(1) val);
        endmethod
        method Bit#(1) cts_n() = 0;

        method Bit#(1) dcd_n() = 0;
        method Bit#(1) dsr_n() = 0;
        method Action dtr_n(Bit#(1) val);
        endmethod
    endinterface

    method led = truncate(uart.frame);
endmodule

endpackage : Examples

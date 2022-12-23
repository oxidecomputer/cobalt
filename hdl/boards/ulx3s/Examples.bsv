// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Examples;

import Board::*;
import ECP5::*;

import Blinky::*;
import UART::*;
import UARTLoopback::*;


(* default_clock_osc="clk_25mhz", default_reset="btn_pwr" *)
module mkBlinky (Top);
    GSR gsr <- mkGSR(); // Allow btn_pwr to reset the design.
    Blinky#(25_000_000) blinky <- Blinky::mkBlinky();

    method led() = {'0, blinky.led()};

    method Action btn(Bit#(6) val);
        if (val != 0) begin
            blinky.button_pressed();
        end
    endmethod

    interface ESP32 wifi;
        // Tie this high to keep board from resetting.
        method gpio0 = 1;
    endinterface

    method Action sw(Bit#(4) val);
        // Ignore switches.
    endmethod

    interface FTDI ftdi;
        // Ignore FTDI IO.
        method Bit#(1) rxd() = 1;
        method Action txd(Bit#(1) val);
        endmethod
    endinterface
endmodule

(* default_clock_osc="clk_25mhz", default_reset="btn_pwr" *)
module mkUARTLoopback (Top);
    GSR gsr <- mkGSR(); // Allow btn_pwr to reset the design.
    UARTLoopback#(25_000_000, 115200, 8) loopback <- UARTLoopback::mkUARTLoopback();

    // RX input register. Since the output of this register goes into additional FFs as part of the
    // bit sampler no meta instability is expected to occur.
    Reg#(Bit#(1)) rx_sync <- mkRegU();

    interface FTDI ftdi;
        method rxd = loopback.serial.tx;
        method Action txd(Bit#(1) val);
            rx_sync <= val;
            loopback.serial.rx(rx_sync);
        endmethod
    endinterface

    interface ESP32 wifi;
        // Tie this high to keep board from resetting.
        method gpio0 = 1;
    endinterface

    method led = 0;

    method Action btn(Bit#(6) val);
        // Ignore buttons.
    endmethod

    method Action sw(Bit#(4) val);
        // Ignore switches.
    endmethod
endmodule

endpackage : Examples

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Examples;

import Board::*;
import ECP5::*;
import IOSync::*;

import Blinky::*;
import LoopbackUART::*;


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
module mkLoopbackUART (Top);
    GSR gsr <- mkGSR(); // Allow btn_pwr to reset the design.
    LoopbackUART#(25_000_000, 115200, 8) uart <- LoopbackUART::mkLoopbackUART();

    interface FTDI ftdi;
        method rxd = uart.serial.tx;
        method txd = uart.serial.rx;
    endinterface

    interface ESP32 wifi;
        // Tie this high to keep board from resetting.
        method gpio0 = 1;
    endinterface

    method led = uart.frame;

    method Action btn(Bit#(6) val);
        // Ignore buttons.
    endmethod

    method Action sw(Bit#(4) val);
        // Ignore switches.
    endmethod
endmodule

endpackage : Examples

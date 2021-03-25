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


(* synthesize, default_clock_osc="CLK_12mhz", default_reset="GSR_N" *)
module mkBlinky (TopMinimal);
    GSR gsr <- mkGSR(); // Allow GSR_N to reset the design.
    Blinky#(12_000_000) blinky <- Blinky::mkBlinky();

    method led = {~'0, blinky.led()};

    method Action btn(Bit#(1) val);
        if (val != 0) begin
            blinky.button_pressed();
        end
    endmethod

    // Ignore UART.
    method uart_tx = 1;
    method Action uart_rx(val);
    endmethod
endmodule

(* synthesize, default_clock_osc="CLK_12mhz", default_reset="GSR_N" *)
module mkUARTLoopback (TopMinimal);
    GSR gsr <- mkGSR(); // Allow GSR_N to reset the design.
    UARTLoopback#(12_000_000, 115200, 8) loopback <- UARTLoopback::mkUARTLoopback();

    // RX input register. Since the output of this register goes into additional FFs as part of the
    // bit sampler no meta instability is expected to occur.
    Reg#(Bit#(1)) rx_sync <- mkRegU();

    method uart_tx = loopback.serial.tx;
    method Action uart_rx(Bit#(1) val);
        rx_sync <= val;
        loopback.serial.rx(rx_sync);
    endmethod

    method led = ~0;

    method Action btn(Bit#(1) val);
        // Ignore buttons.
    endmethod
endmodule

endpackage : Examples

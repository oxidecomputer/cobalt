// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Examples;

import Board::*;
import ECP5::*;
import IOSync::*;

import Blinky::*;
import LoopbackUART::*;


(* default_clock_osc="CLK_12mhz", default_reset="GSR_N" *)
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

(* default_clock_osc="CLK_12mhz", default_reset="GSR_N" *)
module mkLoopbackUART (TopMinimal);
    GSR gsr <- mkGSR(); // Allow GSR_N to reset the design.
    LoopbackUART#(12_000_000, 115200, 8) uart <- LoopbackUART::mkLoopbackUART();

    method uart_tx = uart.serial.tx;
    method uart_rx = uart.serial.rx;

    method led = ~uart.frame;

    method Action btn(Bit#(1) val);
        // Ignore buttons.
    endmethod
endmodule

//
// mkClocks is a minimal example which demonstrates the ECP5 PLL wrapper and how to clock different
// parts of a design using independent clocks. This example should blink the first two LEDs in phase
// at 1Hz.
//
(* default_clock_osc="CLK_12mhz", default_reset="GSR_N" *)
module mkClocks (TopMinimal);
    GSR gsr <- mkGSR(); // Allow GSR_N to reset the design.

    let pll_parameters = ECP5PLLParameters {
        clki_frequency: 12.0,
        clki_divide: 3,
        // Primary output clock parameters.
        clkop_enable: True,
        clkop_frequency: 100.0,
        clkop_divide: 6,
        clkop_coarse_phase_adjust: 0,
        clkop_fine_phase_adjust: 0,
        // Secondary output clock parameters.
        clkos_enable: True,
        clkos_frequency: 50.0,
        clkos_divide: 12,
        clkos_coarse_phase_adjust: 0,
        clkos_fine_phase_adjust: 0,
        // Secondary output clock 2 parameters.
        clkos2_enable: False,
        clkos2_frequency: 0.0,
        clkos2_divide: 0,
        clkos2_coarse_phase_adjust: 0,
        clkos2_fine_phase_adjust: 0,
        // Secondary output clock 3 parameters.
        clkos3_enable: False,
        clkos3_frequency: 0.0,
        clkos3_divide: 0,
        clkos3_coarse_phase_adjust: 0,
        clkos3_fine_phase_adjust: 0,
        // Feedback parameters.
        feedback_path: "CLKOP",
        feedback_divide: 25};

    Clock clk_12mhz <- exposeCurrentClock();
    Reset rst_12mhz <- exposeCurrentReset();
    ECP5PLL pll <- mkECP5PLL(pll_parameters, clk_12mhz, rst_12mhz);

    Blinky#(100_000_000) blinky_100mhz <- Blinky::mkBlinky(clocked_by pll.clkop);
    Blinky#(50_000_000) blinky_50mhz <- Blinky::mkBlinky(clocked_by pll.clkos);

    let led0 = blinky_100mhz.led[0];
    let led1 = blinky_50mhz.led[0];
    let led2 = blinky_100mhz.led[1] | blinky_50mhz.led[1];
    method led = {~'0, led2, led1, led0};

    method Action btn(Bit#(1) val);
        if (val != 0) begin
            blinky_100mhz.button_pressed();
            blinky_50mhz.button_pressed();
        end
    endmethod

    // Ignore UART.
    method uart_tx = 1;
    method Action uart_rx(val);
    endmethod
endmodule

endpackage: Examples

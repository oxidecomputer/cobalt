// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Examples;

import Board::*;

import Blinky::*;
import UART::*;
import UARTLoopback::*;


(* synthesize, default_clock_osc="clk_12mhz" *)
module mkBlinky (Top);
    Blinky#(12_000_000) blinky <- Blinky::mkBlinky();

    method led() = {'0, blinky.led()};

    interface FTDI ftdi;
        // Ignore FTDI IO.
        method Bit#(1) rxd() = 1;
        method Action txd(Bit#(1) val);
        endmethod
    endinterface
endmodule

(* synthesize, default_clock_osc="clk_12mhz" *)
module mkUARTLoopback (Top);
    UARTLoopback#(12_000_000, 115200, 8) loopback <- UARTLoopback::mkUARTLoopback();

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

    method led = 0;
endmodule

endpackage : Examples

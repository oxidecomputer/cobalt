// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package ULX3S;

export FTDI(..), ESP32(..), ULX3STop(..);
export mkBlinky;

import ECP5::*;


(* always_ready, always_enabled *)
interface FTDI;
    method Bit#(1) rxd();
    (* prefix = "" *)
    method Action txd((* port = "txd" *) Bit#(1) val);
endinterface

(* always_ready, always_enabled *)
interface ESP32;
    method Bit#(1) gpio0();
endinterface

interface ULX3STop;
    interface FTDI ftdi;
    interface ESP32 wifi;

    (* always_ready, always_enabled *)
    method Bit#(8) led;
    (* always_ready, always_enabled, prefix = "" *)
    method Action btn((* port = "btn" *) Bit#(6) val);
    (* always_ready, always_enabled, prefix = "" *)
    method Action sw((* port = "sw" *) Bit#(4) val);
endinterface

(* synthesize, default_clock_osc="clk_25mhz", default_reset="btn_pwr" *)
module mkBlinky (ULX3STop);
    GSR gsr <- mkGSR(); // Allow btn_pwr to reset the design.

    Reg#(UInt#(TLog#(25_000_000))) c <- mkRegA(0);
    Reg#(Bit#(1)) d0 <- mkRegA(0);

    PulseWire button_pressed <- mkPulseWire;

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_count;
        let overflow = c >= fromInteger(25_000_000 / 2);
        c <= overflow ? 0 : c + 1;
        d0 <= overflow ? ~d0 : d0;
    endrule

    method Bit#(8) led();
        return {'0, pack(button_pressed), d0};
    endmethod

    method Action btn(Bit#(6) val);
        if (val != 0) begin
            button_pressed.send();
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

endpackage : ULX3S

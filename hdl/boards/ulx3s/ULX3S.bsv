// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package ULX3S;

export FTDI(..), ESP32(..);
export ULX3STop(..);


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

endpackage : ULX3S

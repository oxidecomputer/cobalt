// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Board;

export FTDI(..), ESP32(..);
export Top(..);


interface FTDI;
    method Bit#(1) rxd();
    (* prefix = "" *)
    method Action txd((* port = "txd" *) Bit#(1) val);
endinterface

interface ESP32;
    method Bit#(1) gpio0();
endinterface

(* always_enabled *)
interface Top;
    interface FTDI ftdi;
    interface ESP32 wifi;

    method Bit#(8) led;
    (* prefix = "" *)
    method Action btn((* port = "btn" *) Bit#(6) val);
    (* prefix = "" *)
    method Action sw((* port = "sw" *) Bit#(4) val);
endinterface

endpackage: Board

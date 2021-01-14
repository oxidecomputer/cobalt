// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Board;

export FTDI(..);
export Top(..);


(* always_ready, always_enabled *)
interface FTDI;
    method Bit#(1) rxd();
    (* prefix = "" *)
    method Action txd((* port = "txd" *) Bit#(1) val);
endinterface

interface Top;
    interface FTDI ftdi;

    (* always_ready, always_enabled *)
    method Bit#(5) led;
endinterface

endpackage : Board

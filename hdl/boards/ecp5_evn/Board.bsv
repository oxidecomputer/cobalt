// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Board;

export TopMinimal(..);


(* always_enabled *)
interface TopMinimal;
    method Bit#(8) led;
    (* prefix = "" *)
    method Action btn((* port = "btn" *) Bit#(1) val);

    (* prefix = "" *)
    method Action uart_rx((* port = "uart_rx" *) Bit#(1) val);
    method Bit#(1) uart_tx();
endinterface

endpackage: Board

// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Board;

export FTDI(..), mkFTDITieOff;
export IRDA(..), mkIRDATieOff;
export Top(..);


interface FTDI;
    method Bit#(1) rxd();
    (* prefix = "" *)
    method Action txd((* port = "txd" *) Bit#(1) val);

    (* prefix = "" *)
    method Action rts_n((* port = "rts_n" *) Bit#(1) val);
    method Bit#(1) cts_n();

    method Bit#(1) dcd_n();
    method Bit#(1) dsr_n();
    (* prefix = "" *)
    method Action dtr_n((* port = "dtr_n" *) Bit#(1) val);
endinterface

module mkFTDITieOff (FTDI);
    method Bit#(1) rxd() = 1;
    method Action txd(Bit#(1) val);
    endmethod

    method Action rts_n(Bit#(1) val);
    endmethod
    method Bit#(1) cts_n() = 0;

    method Bit#(1) dcd_n() = 0;
    method Bit#(1) dsr_n() = 0;
    method Action dtr_n(Bit#(1) val);
    endmethod
endmodule

// This interface is obviously not correct, but without knowing which signals
// are outputs this is the safe default.
interface IRDA;
    (* prefix = "" *)
    method Action txd((* port = "txd" *) Bit#(1) val);
    (* prefix = "" *)
    method Action rxd((* port = "rxd" *) Bit#(1) val);
    (* prefix = "" *)
    method Action sd((* port = "sd" *) Bit#(1) val);
endinterface

module mkIRDATieOff (IRDA);
    method Action txd(Bit#(1) val);
    endmethod
    method Action rxd(Bit#(1) val);
    endmethod
    method Action sd(Bit#(1) val);
    endmethod
endmodule

(* always_enabled *)
interface Top;
    interface FTDI ftdi;
    interface IRDA irda;
    method Bit#(5) led;
endinterface

endpackage: Board

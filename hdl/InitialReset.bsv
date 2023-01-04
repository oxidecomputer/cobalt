// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package InitialReset;

export mkInitialReset;

import Clocks::*;
import StmtFSM::*;

import TestUtils::*;


import "BVI" InitialReset =
    module vInitialReset#(Integer cycles) (ResetGenIfc);
        default_clock clk(CLK, (* unused *) CLK_GATE) ;
        no_reset ;

        parameter CYCLES =
          (cycles > 0) ? cycles : error("Reset generator built with hold cycles less than 1") ;

        output_reset gen_rst(RST) clocked_by(clk) ;
    endmodule

module mkInitialReset #(Integer cycles) (Reset);
    (* hide *) ResetGenIfc _ifc <- vInitialReset(cycles);
    return _ifc.gen_rst;
endmodule

module mkInitialResetTest (Empty);
    Reset initial_reset <- mkInitialReset(2);
    Reg#(Bool) r <- mkReg(True, reset_by initial_reset);

    mkAutoFSM(seq
        await(r);
    endseq,
    reset_by initial_reset);

    mkTestWatchdog(5);
endmodule

endpackage

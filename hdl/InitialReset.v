// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

`ifdef BSV_ASSIGNMENT_DELAY
`else
  `define BSV_ASSIGNMENT_DELAY
`endif

`ifdef BSV_POSITIVE_RESET
  `define BSV_RESET_VALUE 1'b1
  `define BSV_RESET_EDGE posedge
`else
  `define BSV_RESET_VALUE 1'b0
  `define BSV_RESET_EDGE negedge
`endif


module InitialReset
#(
    parameter CYCLES = 2
)
(
    input CLK,
    output RST
);

    reg [CYCLES - 1:0] hold;
    wire [CYCLES:0] hold_next = {hold, ~`BSV_RESET_VALUE};

    assign RST = hold[CYCLES - 1];

    always @(posedge CLK) begin
        hold <= `BSV_ASSIGNMENT_DELAY hold_next[CYCLES - 1:0];
    end

    initial begin
        #0 // Required so that negedge is seen by any derived async resets
        hold = {CYCLES{`BSV_RESET_VALUE}};
    end

endmodule

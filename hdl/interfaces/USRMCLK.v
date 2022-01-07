// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

module USRMCLK (
    input USRMCLKI,
    input USRMCLKTS
);

USRMCLK usrmclk_i (USRMCLKI(USRMCLKI), USRMCLKTS(USRMCLKTS))
    /* synthesis syn_noprune=1 */;

endmodule
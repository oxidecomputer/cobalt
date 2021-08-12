// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package PLL;

export PLL(..);

import Vector::*;

//
// PLL(..) is an attempt at a generic PLL interface with a variable number of output clocks. This
// interface is currently used to abstract the PLL primitives provided for ECP5 FPGA devices but may
// need to evolve to accomodate other devices and our understanding of clocks in Bluespec.
//
interface PLL #(numeric type n_output_clocks);
    interface Clock in;
    method Vector#(n_output_clocks, Clock) out();
    method Bool locked();
endinterface

endpackage: PLL

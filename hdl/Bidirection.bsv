// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Bidirection;

// Interface to bundle signals which connect to bidirectional pins (inout)
// at the top level of a design. See `IOSync` for a convenient wrapper to
// turn this into an `Inout`.
interface Bidirection #(type t);
    method t out;
    method Bool out_en;
    method Action in(t val);
endinterface

endpackage: Bidirection

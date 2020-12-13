// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package TestUtils;

export mkTestTimeout;
export assert_get;

import Assert::*;
import GetPut::*;


module mkTestTimeout #(Integer timeout) (Empty);
    // The rule in this module may fire early in the schedule, potentially tripping this assert
    // before all rules/methods of this cycle have completed. This may cause the last cycle of a
    // test to be only partially executed which in turn could causing a false negative test failure.
    // Delay the timeout by one cycle so everything scheduled for this cycle will complete.
    Reg#(UInt#(32)) _c <- mkRegA(0);

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_timeout;
        _c <= _c + 1;
        dynamicAssert(_c < fromInteger(timeout + 1), "test timed out");
    endrule
endmodule

function Action assert_get(Get#(t) o, t expected, String s)
        provisos (Eq#(t)) =
    action
        let actual <- o.get();
        dynamicAssert(actual == expected, s);
    endaction;

endpackage : TestUtils

// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package TestUtils;

export TestWatchdog(..), mkTestWatchdog;
export assert_get, assert_get_and_display, assert_get_and_display_fshow;

import Assert::*;
import GetPut::*;


//
// Test benches build using StmtFSM primitives tend to run indefinite if/when they deviate from the
// design happy path. This interface and accompanying module allows adding a watch dog to the test
// bench, forcing a failing assert if the test runs for longer than the intended number of cycles.
//
interface TestWatchdog;
    // Pet the watchdog, allowing for tests consisting of a bounded number of steps, each consisting
    // of a bounded number of cycles.
    method Action send();
endinterface

module mkTestWatchdog #(Integer timeout) (TestWatchdog);
    // The rule in this module may fire early in the schedule, potentially tripping this assert
    // before all rules/methods of this cycle have completed. This may cause the last cycle of a
    // test to be only partially executed which in turn could causing a false negative test failure.
    // Delay the timeout by one cycle so everything scheduled for this cycle will complete.
    Reg#(UInt#(32)) timeout_count <- mkRegA(0);
    PulseWire should_restart <- mkPulseWire();

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_timeout;
        timeout_count <= should_restart? 0 : timeout_count + 1;
        dynamicAssert(timeout_count < fromInteger(timeout + 1), "test timed out");
    endrule

    method send = should_restart.send;
endmodule

//
// Get a value from a Get(..) interface, asserting it matches the given expected value and
// discarding it afterwards.
//
function Action assert_get(Get#(t) g, t expected, String msg)
        provisos (Eq#(t)) =
    action
        let actual <- g.get();
        dynamicAssert(actual == expected, msg);
    endaction;

//
// Get a value from a Get(..) interface, asserting it matches the given expected value and
// displaying it using $display(..).
//
function Action assert_get_and_display(Get#(t) g, t expected, String msg)
        provisos (
            Eq#(t),
            Bits#(t, sz)) =
    action
        let actual <- g.get();
        $display(actual);
        dynamicAssert(actual == expected, msg);
    endaction;

//
// Get a value from a Get(..) interface, asserting it matches the given expected value and
// displaying it using $display(fshow(..)).
//
function Action assert_get_and_display_fshow(Get#(t) g, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t)) =
    action
        let actual <- g.get();
        $display(fshow(actual));
        dynamicAssert(actual == expected, msg);
    endaction;

endpackage : TestUtils

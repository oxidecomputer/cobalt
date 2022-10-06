// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package TestUtils;

export assert_fail;
export assert_set;
export assert_not_set;
export assert_true;
export assert_false;
export assert_eq;
export assert_not_eq;
export assert_av_set;
export assert_av_not_set;
export assert_av_true;
export assert_av_false;
export assert_av_eq;
export assert_av_not_eq;
export assert_av_any;
export assert_av_eq_display;
export assert_av_not_eq_display;
export assert_av_any_display;
export assert_av_eq_display_fmt;
export assert_av_not_eq_display_fmt;
export assert_av_any_display_fmt;
export assert_get_set;
export assert_get_not_set;
export assert_get_true;
export assert_get_false;
export assert_get_eq;
export assert_get_not_eq;
export assert_get_any;
export assert_get_eq_display;
export assert_get_not_eq_display;
export assert_get_any_display;
export assert_get_eq_display_fmt;
export assert_get_not_eq_display_fmt;
export assert_get_any_display_fmt;

export TestResult(..);
export Test(..);
export TestWatchdog(..);
export mkTestWatchdog;

import Assert::*;
import GetPut::*;


//
// `assert_fail(..)` is an assertion which always fails when evaluated. It can
// be used to halt a test when branches deemed unreacheable are taken.
//
function Action assert_fail(String msg);
    return dynamicAssert(False, msg);
endfunction

//
// `assert_set(..)`/`assert_not_set(..)` assert that the given bit is set or not set
// respectively.
//
function Action assert_set(one_bit_type v, String msg)
        provisos (Bits#(one_bit_type, 1));
    return dynamicAssert(pack(v) == 1, msg);
endfunction

function Action assert_not_set(one_bit_type v, String msg)
        provisos (Bits#(one_bit_type, 1));
    return dynamicAssert(pack(v) == 0, msg);
endfunction

//
// `assert_true(..)`/`assert_false(..)` assert that the given boolean expression
// is `True` or `False` respectively.
//
function Action assert_true(Bool b, String msg);
    return assert_set(b, msg);
endfunction

function Action assert_false(Bool b, String msg);
    return assert_not_set(b, msg);
endfunction

//
// `assert_eq(..)`/`assert_not_eq(..)` assert that the given expression does or
// does not match an expected result respectively. In case the assertion does
// not hold both values are displayed.
//
function Action assert_eq(t actual, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return action
        if (actual != expected) begin
            $display("expected: ", fshow(expected));
            $display("actual: ", fshow(actual));
        end
        dynamicAssert(actual == expected, msg);
    endaction;
endfunction

function Action assert_not_eq(t actual, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return action
        if (actual == expected) begin
            $display("value: ", fshow(actual));
        end
        dynamicAssert(actual != expected, msg);
    endaction;
endfunction

//
// `assert_av_set(..)`/`assert_av_not_set(..)` assert that the result of the
// given `ActionValue` is set or not set respectively.
//
function Action assert_av_set(ActionValue#(one_bit_type) av, String msg)
        provisos (Bits#(one_bit_type, 1));
    return action
        let b <- av;
        assert_set(b, msg);
    endaction;
endfunction

function Action assert_av_not_set(ActionValue#(one_bit_type) av, String msg)
        provisos (Bits#(one_bit_type, 1));
    return action
        let b <- av;
        assert_not_set(b, msg);
    endaction;
endfunction

//
// `assert_av_true(..)`/`assert_av_false(..)` assert that the boolean result of
// the given `ActionValue` is `True` or `False` respectively.
//
function Action assert_av_true(ActionValue#(Bool) av, String msg);
    return assert_av_set(av, msg);
endfunction

function Action assert_av_false(ActionValue#(Bool) av, String msg);
    return assert_av_not_set(av, msg);
endfunction

//
// `assert_av_eq(..)`/`assert_av_not_eq(..)` assert that the result of the given
// `ActionValue` does or does not match an expected result respectively. In
// case the assertion does not hold both the expected and actual value are
// displayed.
//
function Action assert_av_eq(ActionValue#(t) av, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return action
        let actual <- av;
        assert_eq(actual, expected, msg);
    endaction;
endfunction

function Action assert_av_not_eq(ActionValue#(t) av, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return action
        let actual <- av;
        assert_not_eq(actual, expected, msg);
    endaction;
endfunction

//
// `assert_av_any(..)` collects any value from the given `ActionValue`. It does
// not assert anything about this action, but provides some syntactic sugar when
// writing tests that involve "don't care" values.
//
function Action assert_av_any(ActionValue#(t) av);
    return action
        let _ <- av;
    endaction;
endfunction

//
// `assert_av_eq_display(..)`/`assert_av_not_eq_display(..) assert that the
// result of the given `ActionValue` does or does not match an expected
// result respectively. If the assertion holds, the resulting value is
// displayed. If the assertion does not hold, both the expected and the
// resulting value are displayed.
//
function Action assert_av_eq_display(ActionValue#(t) av, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return action
        let actual <- av;
        if (actual == expected) $display(fshow(actual));
        assert_eq(actual, expected, msg);
    endaction;
endfunction

function Action assert_av_not_eq_display(
        ActionValue#(t) av,
        t expected,
        String msg)
            provisos (
                Eq#(t),
                FShow#(t));
    return action
        let actual <- av;
        if (actual != expected) $display(fshow(actual));
        assert_not_eq(actual, expected, msg);
    endaction;
endfunction

//
// `assert_av_any_display(..)` collects and displays any value from the given
// `ActionValue`. It does not assert anything about this action, but provides
// some syntactic sugar when writing tests that involve "don't care" values.
//
function Action assert_av_any_display(ActionValue#(t) av)
        provisos (
            Eq#(t),
            FShow#(t));
    return action
        let v <- av;
        $display(fshow(v));
    endaction;
endfunction

//
// `assert_av_eq_display_fmt(..)`/`assert_av_not_eq_display_fmt(..) assert that
// the result of the given `ActionValue` does or does not match an expected
// result respectively. If the assertion holds, the resulting value is displayed
// using the given format function. If the assertion does not hold, both the
// expected and the resulting value are displayed using the given format
// function.
//
function Action assert_av_eq_display_fmt(
        ActionValue#(t) av,
        t expected,
        String msg,
        function Fmt fmt(t v))
            provisos (Eq#(t));
    return action
        let actual <- av;
        if (actual == expected)
            $display(fmt(actual));
        else begin
            $display("expected: ", fmt(expected));
            $display("actual: ", fmt(actual));
        end
        assert_true(actual == expected, msg);
    endaction;
endfunction

function Action assert_av_not_eq_display_fmt(
        ActionValue#(t) av,
        t expected,
        String msg,
        function Fmt fmt(t v))
            provisos (Eq#(t));
    return action
        let actual <- av;
        if (actual != expected)
            $display(fmt(actual));
        else begin
            $display("value: ", fmt(actual));
        end
        assert_true(actual != expected, msg);
    endaction;
endfunction

//
// `assert_av_any_display_fmt(..)` collects and display using the given format
// function any value from the given `ActionValue`. It does not assert anything
// about this action, but provides some syntactic sugar when writing tests that
// involve "don't care" values.
//
function Action assert_av_any_display_fmt(
        ActionValue#(t) av,
        function Fmt fmt(t v))
            provisos (
                Eq#(t));
    return action
        let v <- av;
        $display(fmt(v));
    endaction;
endfunction

//
// `assert_get_set(..)`/`assert_get_not_set(..)` assert that the result of the
// given `Get` interface is set or not set respectively.
//
function Action assert_get_set(Get#(one_bit_type) g, String msg)
        provisos (Bits#(one_bit_type, 1));
    return assert_av_set(g.get, msg);
endfunction

function Action assert_get_not_set(Get#(one_bit_type) g, String msg)
        provisos (Bits#(one_bit_type, 1));
    return assert_av_not_set(g.get, msg);
endfunction

//
// `assert_get_true(..)`/`assert_get_false(..)` assert that the boolean result
// of the given `Get` interface is `True` or `False` respectively.
//
function Action assert_get_true(Get#(Bool) g, String msg);
    return assert_av_true(g.get, msg);
endfunction

function Action assert_get_false(Get#(Bool) g, String msg);
    return assert_av_false(g.get, msg);
endfunction

//
// `assert_get_eq(..)`/`assert_get_not_eq(..)` assert that the value from a
// `Get` interface does or does not match an expected result respectively.
// In case the assertion does not hold both the expected and resulting value are
// displayed.
//
function Action assert_get_eq(Get#(t) g, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return assert_av_eq(g.get, expected, msg);
endfunction

function Action assert_get_not_eq(Get#(t) g, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return assert_av_not_eq(g.get, expected, msg);
endfunction

//
// `assert_get_any(..)` collects any value from the given `Get` interface. It
// does not assert anything about this action, but provides some syntactic sugar
// when writing tests that involve "don't care" values.
//
function Action assert_get_any(Get#(t) g);
    return assert_av_any(g.get);
endfunction

//
// `assert_get_eq_display(..)`/`assert_get_not_eq_display(..)` assert that the
// value from a `Get` interface does or does not match an expected result
// respectively. If the assertion holds, the resulting value is displayed. If
// the assertion does not hold, both the expected and the resulting value are
// displayed.
//
function Action assert_get_eq_display(Get#(t) g, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return assert_av_eq_display(g.get, expected, msg);
endfunction

function Action assert_get_not_eq_display(Get#(t) g, t expected, String msg)
        provisos (
            Eq#(t),
            FShow#(t));
    return assert_av_not_eq_display(g.get, expected, msg);
endfunction

//
// `assert_get_any_display(..)` collects and display any value from the given
// `Get` interface. It does not assert anything about this action, but provides
// some syntactic sugar when writing tests that involve "don't care" values.
//
function Action assert_get_any_display(Get#(t) g)
        provisos (
            Eq#(t),
            FShow#(t));
    return assert_av_any_display(g.get);
endfunction

//
// `assert_get_eq_display(..)`/`assert_get_not_eq_display(..)` assert that the
// value from a `Get` interface does or does not match an expected result
// respectively. If the assertion holds, the resulting value is displayed. If
// the assertion does not hold, both the expected and the resulting value are
// displayed.
//
function Action assert_get_eq_display_fmt(
        Get#(t) g,
        t expected,
        String msg,
        function Fmt fmt(t v))
            provisos (Eq#(t));
    return assert_av_eq_display_fmt(g.get, expected, msg, fmt);
endfunction

function Action assert_get_not_eq_display_fmt(
        Get#(t) g,
        t expected,
        String msg,
        function Fmt fmt(t v))
            provisos (Eq#(t));
    return assert_av_not_eq_display_fmt(g.get, expected, msg, fmt);
endfunction

//
// `assert_get_any_display_fmt(..)` collects and display using the given format
// function any value from the given `Get` interface. It does not assert
// anything about this action, but provides some syntactic sugar when writing
// tests that involve "don't care" values.
//
function Action assert_get_any_display_fmt(
        Get#(t) g,
        function Fmt fmt(t v))
            provisos (Eq#(t));
    return assert_av_any_display_fmt(g.get, fmt);
endfunction

//
// `Test(..)` is a minimal interface which can be used to represent a test
// running either in simulation or on target hardware.
//

typedef enum {
    Pass,
    Fail,
    Timeout
} TestResult deriving (Bits, Eq, FShow);

interface Test #(type status_type, type debug_type);
    method Action start();
    method TestResult result();

    // Additional (status) data which can be used by the test harness to show
    // status while the test is running, for example using LEDs.
    (* always_enabled *) method status_type status();

    // Additional (debug) data which can be passed on by the test hardness to
    // for example a logic analyzer to aid debugging failing tests.
    (* always_enabled *) method debug_type debug();
endinterface

//
// Test benches build using StmtFSM primitives tend to run indefinite if/when
// they deviate from the design happy path. This interface and accompanying
// module allows adding a watch dog to the test bench, forcing a failing assert
// if the test runs for longer than the intended number of cycles.
//
interface TestWatchdog;
    // Pet the watchdog, allowing for tests consisting of a bounded number of
    // steps, each consisting of a bounded number of cycles.
    method Action send();
    (* always_enabled *) method Bool timeout();
endinterface

module mkTestWatchdog #(Integer timeout) (TestWatchdog);
    Reg#(UInt#(32)) count <- mkRegA(fromInteger(timeout + 2));
    Reg#(Bool) timed_out <- mkRegA(False);

    PulseWire restart <- mkPulseWire();

    // The rule in this module may fire early in the schedule, potentially
    // tripping this assert before all rules/methods of this cycle have
    // completed. This may cause the last cycle of a test to be only partially
    // executed which in turn could causing a false negative test failure. Delay
    // the timeout by one cycle so everything scheduled for this cycle will
    // complete.
    (* fire_when_enabled *)
    rule do_count_down;
        count <= restart ?
            fromInteger(timeout + 2) :
            satMinus(Sat_Zero, count, 1);

        let timed_out_ = (count == 1);
        timed_out <= timed_out_;
        assert_false(timed_out_, "time out");
    endrule

    method send = restart.send;
    method timeout = timed_out;
endmodule

endpackage: TestUtils

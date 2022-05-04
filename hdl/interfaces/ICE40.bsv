// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package ICE40;

import Clocks::*;


//
// The `ICE40` package provides wrappers around various iCE40 primitives. These are currently only
// tested against recent versions of Yosys/Nextpnr, but should in theory work with the Lattice
// provided synthesis toolchain.
//

//
// DifferentialPairTx(..) provides an interface to the inout pads of a differential output pin pair.
//
interface DifferentialPairTx #(type one_bit_type);
    interface Inout#(one_bit_type) p;
    interface Inout#(one_bit_type) n;
endinterface

//
// DifferentialPairRx(..) provides an interface to the inout pads of a differential input pin pair.
// A receiving pair only needs the positive polarity pin. The negative polarity pin is inferred by
// the synthesis process.
//
interface DifferentialPairRx #(type one_bit_type);
    interface Inout#(one_bit_type) p;
endinterface

//
// `DifferentialTranceiver(..)` is used to implement an LVDS transceiver, allowing the pin pads of
// the diff pair to be connected somewhat conveniently to an appropriate IO primitive.
//
interface DifferentialTransceiver #(type one_bit_type);
    interface DifferentialPairTx#(one_bit_type) tx;
    interface DifferentialPairRx#(one_bit_type) rx;
endinterface

//
// Interface the Lattice defined SB_IO(..) primitive. See Lattice Semi "TN1253: Using Differential
// I/O (LVDS, Sub-LVDS) in iCE40 LP/HX Devices" for more details on the modes of the primitives.
//
(* always_enabled *)
interface SB_IO #(type one_bit_type);
    interface Inout#(one_bit_type) pad;
    method one_bit_type q0();
    method one_bit_type q1();
    method Action d(one_bit_type x0, one_bit_type x1);
endinterface

import "BVI" SB_IO =
    module vMkSB_IO #(
            Bit#(6) pin_type,
            String io_standard,
            Bool pull_up,
            Bool negative_trigger) (SB_IO#(one_bit_type))
                provisos (Bits#(one_bit_type, 1));
        parameter PIN_TYPE = pin_type;
        parameter IO_STANDARD = io_standard;
        parameter PULLUP = pull_up;
        parameter NEG_TRIGGER = negative_trigger;

        // The primitive can be clocked by two different clocks yet the gate is a single signal.
        // This is annoying, because the gate signal should be an OR of the gates of the two clocks,
        // which seems difficult to make happen within the BVI syntax.
        //
        // For two different clocks to work with the Bluespec compiler synchronization would need to
        // happen using the OUTPUT_ENABLE signal below. For now just assume this primitive is only
        // used in a single clock domain and feed it the current clock for both input and output.
        input_clock read_clk (INPUT_CLK, CLOCK_ENABLE) <- exposeCurrentClock();
        input_clock write_clk (OUTPUT_CLK, (* unused *) OUTPUT_CLK_GATE) <- exposeCurrentClock();
        default_clock read_clk;
        default_reset no_reset;

        ifc_inout pad(PACKAGE_PIN);

        method D_IN_0 q0() clocked_by(read_clk);
        method D_IN_1 q1() clocked_by(read_clk);
        method d (D_OUT_0, D_OUT_1) enable(OUTPUT_ENABLE) clocked_by(read_clk);

        schedule (q0, q1) CF (q0, q1);
        schedule (d) C (d);         // Write once per cycle.
        schedule (d) C (q0, q1);    // Read or write in a given cycle, not both.
    endmodule

//
// Enum types representing valid IO_TYPE values. See TN1253 for deets.
//
typedef enum {
    InputRegistered = 2'b00,
    InputNonRegistered = 2'b01,
    InputLatch = 2'b11,
    InputRegisteredLatch = 2'b10
} InputType deriving (Bits, Eq);

typedef enum {
    OutputDisabled = 4'b0000,
    OutputNonRegistered = 4'b0110,
    OutputTriState = 4'b1010,
    OutputRegistered = 4'b0101,
    OutputRegisteredEnable = 4'b1001,
    OutputEnableRegistered = 4'b1110,
    OutputRegisteredEnableRegistered = 4'b1101,
    OutputRegisteredInverted = 4'b0111,
    OutputRegisteredEnableInverted = 4'b1011,
    OutputRegisteredEnableRegisteredInverted = 'b1111
} OutputType deriving (Bits, Eq);

typedef enum {
    OutputDisabled = 4'b0000,
    OutputRegistered = 4'b0100,
    OutputRegisteredEnable = 4'b1000,
    OutputRegisteredEnableRegistered = 4'b1100
} OutputTypeDDR deriving (Bits, Eq);

//
// IO interfaces exposing pin pads and _read(..)/_write(..) methods.
//
interface Input #(type one_bit_type);
    interface Inout#(one_bit_type) pad;
    method one_bit_type _read();
endinterface

interface DifferentialInput #(type one_bit_type);
    interface DifferentialPairRx#(one_bit_type) pads;
    method one_bit_type _read();
endinterface

interface Output #(type one_bit_type);
    interface Inout#(one_bit_type) pad;
    method Action _write(one_bit_type val);
endinterface

interface DifferentialOutput #(type one_bit_type);
    interface DifferentialPairTx#(one_bit_type) pads;
    method Action _write(one_bit_type val);
endinterface

typedef Tuple2#(DifferentialInput#(one_bit_type), DifferentialOutput#(one_bit_type))
    DifferentialInputOutput#(type one_bit_type);

//
// Input primitive of the given `input_type` with selectable pull-up.
//
module mkInput #(InputType input_type, Bool pull_up) (Input#(one_bit_type))
        provisos (
            Bits#(one_bit_type, 1));    // 1-bit type
    let pin_type = {pack(OutputType'(OutputDisabled)), pack(input_type)};
    let negative_trigger = False;

    SB_IO#(one_bit_type) io <- vMkSB_IO(pin_type, "SB_LVCMOS", pull_up, negative_trigger);

    interface Inout pad = io.pad;
    method _read = io.q0;
endmodule

//
// Differential input primitive of the given `input_type`.
//
module mkDifferentialInput #(InputType input_type) (DifferentialInput#(one_bit_type))
        provisos (
            Bits#(one_bit_type, 1));    // 1-bit type
    let pin_type = {pack(OutputType'(OutputDisabled)), pack(input_type)};
    let pull_up = False;
    let negative_trigger = False;

    SB_IO#(one_bit_type) p_io <- vMkSB_IO(pin_type, "SB_LVDS_INPUT", pull_up, negative_trigger);

    interface DifferentialPairRx pads;
        interface Inout p = p_io.pad;
    endinterface

    method _read = p_io.q0;
endmodule

//
// Output primitive of the given `output_type`.
//
module mkOutput #(OutputType output_type, Bool pull_up) (Output#(one_bit_type))
        provisos (
            Bits#(one_bit_type, 1));    // 1-bit type
    let pin_type = {pack(output_type), pack(InputType'(InputRegistered))};
    let negative_trigger = False;

    SB_IO#(one_bit_type) io <- vMkSB_IO(pin_type, "SB_LVCMOS", pull_up, negative_trigger);

    interface Inout pad = io.pad;
    method Action _write(one_bit_type val);
        io.d(val, unpack(0));
    endmethod
endmodule

//
// Differential output primitive of the given `output_type`.
//
module mkDifferentialOutput #(OutputType output_type) (DifferentialOutput#(one_bit_type))
        provisos (
            Bits#(one_bit_type, 1));    // 1-bit type
    let pin_type = {pack(output_type), pack(InputType'(InputRegistered))};
    let pull_up = False;
    let negative_trigger = False;

    SB_IO#(one_bit_type) p_io <- vMkSB_IO(pin_type, "SB_LVCMOS", pull_up, negative_trigger);
    SB_IO#(one_bit_type) n_io <- vMkSB_IO(pin_type, "SB_LVCMOS", pull_up, negative_trigger);

    interface DifferentialPairTx pads;
        interface Inout p = p_io.pad;
        interface Inout n = n_io.pad;
    endinterface

    method Action _write(one_bit_type val);
        p_io.d(val, unpack(0));
        n_io.d(unpack(~pack(val)), unpack(0));
    endmethod
endmodule

endpackage: ICE40

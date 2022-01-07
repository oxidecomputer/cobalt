// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package ECP5;

//
// The ECP5 package provides wrappers around various ECP5 primitives. These are currently only
// tested against recent versions of Yosys/Nextpnr, but should in theory work with the Lattice
// provided synthesis toolchain.
//

export GSR(..), mkGSR;
export ECP5PLLParameters(..), ECP5PLL(..), mkECP5PLL, mkPLL;
export USRMCLK(..), mkUSRMCLK;

import DefaultValue::*;
import Vector::*;

import PLL::*;


//
// GSR primitive, which provides a global reset of the fabric using a user signal. This is
// effectively the same as a PoR and can be used for external reset.
//
// Note: this currently uses the default reset of the module instantiating this primitive.
//
interface GSR;
endinterface

import "BVI" GSR =
    module mkGSR (GSR ifc);
        default_clock no_clock;
        default_reset gsr (GSR);
    endmodule

//
// ECP5PLL(..) is an interface to the ECP5PLL module found in the adjacent Verilog file. See
// vMkECP5PLL for details how this maps on the wrapper and EHXPLLL primitive and see Lattice Semi
// "FPGA-TN-02200-1.2" and the Lattice Semi "FPGA Libraries Reference Guide" on how this primitive
// works.
//
interface ECP5PLL;
    // Primary output clock of the PLL.
    interface Clock clkop;
    // Secondary output clocks of the PLL. These can be either be integer divisions or phase shifted
    // from the primary output clock.
    interface Clock clkos;
    interface Clock clkos2;
    interface Clock clkos3;
    // The `lock` signal of the EXHPLLL primitive is negative asserted.
    method Bool not_lock();
endinterface

//
// ECP5 PLL parameters. See Section 18 in Lattice Semi "FPGA-TN-02200-1.2" for valid values and
// expected behavior.
//
typedef struct {
    // Input clock parameters.
    Real clki_frequency;
    Integer clki_divide;
    // Primary output clock parameters.
    Bool clkop_enable;
    Real clkop_frequency;
    Integer clkop_divide;
    Integer clkop_coarse_phase_adjust;
    Integer clkop_fine_phase_adjust;
    // Secondary output clock parameters.
    Bool clkos_enable;
    Real clkos_frequency;
    Integer clkos_divide;
    Integer clkos_coarse_phase_adjust;
    Integer clkos_fine_phase_adjust;
    // Secondary output clock 2 parameters.
    Bool clkos2_enable;
    Real clkos2_frequency;
    Integer clkos2_divide;
    Integer clkos2_coarse_phase_adjust;
    Integer clkos2_fine_phase_adjust;
    // Secondary output clock 3 parameters.
    Bool clkos3_enable;
    Real clkos3_frequency;
    Integer clkos3_divide;
    Integer clkos3_coarse_phase_adjust;
    Integer clkos3_fine_phase_adjust;
    // Feedback parameters.
    String feedback_path;
    Integer feedback_divide;
} ECP5PLLParameters;

instance DefaultValue #(ECP5PLLParameters);
    defaultValue = ECP5PLLParameters {
        clki_frequency: 0.0,
        clki_divide: 0,
        // Primary output clock parameters.
        clkop_enable: False,
        clkop_frequency: 0.0,
        clkop_divide: 0,
        clkop_coarse_phase_adjust: 0,
        clkop_fine_phase_adjust: 0,
        // Secondary output clock parameters.
        clkos_enable: False,
        clkos_frequency: 0.0,
        clkos_divide: 0,
        clkos_coarse_phase_adjust: 0,
        clkos_fine_phase_adjust: 0,
        // Secondary output clock 2 parameters.
        clkos2_enable: False,
        clkos2_frequency: 0.0,
        clkos2_divide: 0,
        clkos2_coarse_phase_adjust: 0,
        clkos2_fine_phase_adjust: 0,
        // Secondary output clock 3 parameters.
        clkos3_enable: False,
        clkos3_frequency: 0.0,
        clkos3_divide: 0,
        clkos3_coarse_phase_adjust: 0,
        clkos3_fine_phase_adjust: 0,
        // Feedback parameters.
        feedback_path: "CLKOP",
        feedback_divide: 1};
endinstance

import "BVI" ECP5PLL =
    module vMkECP5PLL #(ECP5PLLParameters parameters, Clock clk_in, Reset rst) (ECP5PLL);
        parameter CLKI_FREQUENCY = realToString(parameters.clki_frequency);
        parameter CLKI_DIV = parameters.clki_divide;
        parameter CLKOP_ENABLE = parameters.clkop_enable ? "ENABLED" : "DISABLED";
        parameter CLKOP_FREQUENCY = realToString(parameters.clkop_frequency);
        parameter CLKOP_DIV = parameters.clkop_divide;
        parameter CLKOP_CPHASE = parameters.clkop_coarse_phase_adjust;
        parameter CLKOP_FPHASE = parameters.clkop_fine_phase_adjust;
        parameter CLKOS_ENABLE = parameters.clkos_enable ? "ENABLED" : "DISABLED";
        parameter CLKOS_FREQUENCY = realToString(parameters.clkos_frequency);
        parameter CLKOS_DIV = parameters.clkos_divide;
        parameter CLKOS_CPHASE = parameters.clkos_coarse_phase_adjust;
        parameter CLKOS_FPHASE = parameters.clkos_fine_phase_adjust;
        parameter CLKOS2_ENABLE = parameters.clkos2_enable ? "ENABLED" : "DISABLED";
        parameter CLKOS2_FREQUENCY = realToString(parameters.clkos2_frequency);
        parameter CLKOS2_DIV = parameters.clkos2_divide;
        parameter CLKOS2_CPHASE = parameters.clkos2_coarse_phase_adjust;
        parameter CLKOS2_FPHASE = parameters.clkos2_fine_phase_adjust;
        parameter CLKOS3_ENABLE = parameters.clkos3_enable ? "ENABLED" : "DISABLED";
        parameter CLKOS3_FREQUENCY = realToString(parameters.clkos3_frequency);
        parameter CLKOS3_DIV = parameters.clkos3_divide;
        parameter CLKOS3_CPHASE = parameters.clkos3_coarse_phase_adjust;
        parameter CLKOS3_FPHASE = parameters.clkos3_fine_phase_adjust;
        parameter FB_DIV = parameters.feedback_divide;
        parameter FB_PATH = parameters.feedback_path;

        default_clock clki(CLKI, CLKI_GATE) = clk_in;
        default_reset rst = rst;

        // TODO (arjen): determine how to add output clock gating without breaking
        // `no_implicit_conditions` assertions in modules clocked by these outputs.
        port CLKOP_GATE = 1'b0;
        port CLKOS_GATE = 1'b0;
        port CLKOS2_GATE = 1'b0;
        port CLKOS3_GATE = 1'b0;

        output_clock clkop(CLKOP);
        output_clock clkos(CLKOS);
        output_clock clkos2(CLKOS2);
        output_clock clkos3(CLKOS3);

        same_family (clki, clkop);
        same_family (clki, clkos);
        same_family (clki, clkos2);
        same_family (clki, clkos3);

        method LOCK not_lock() clocked_by(no_clock);

        schedule not_lock CF not_lock;
    endmodule

//
// Instantiate an ECP5PLL with the given parameters.
//
module mkECP5PLL #(ECP5PLLParameters parameters, Clock clk_in, Reset rst) (ECP5PLL);
    let pll <- vMkECP5PLL(parameters, clk_in, rst);
    return pll;
endmodule

//
// Instantiate a generic PLL with the given parameters. This is experimental and likely to change.
//
module mkPLL #(ECP5PLLParameters parameters, Clock clk_in, Reset rst) (PLL#(n_output_clocks));
    ECP5PLL _pll <- mkECP5PLL(parameters, clk_in, rst);

    interface Clock in = clk_in;

    method Vector#(n_output_clocks, Clock) out();
        // TODO (arjen): This generates a compiler warning. Determine how to improve this.
        Vector#(n_output_clocks, Clock) cs;

        if (valueOf(n_output_clocks) >= fromInteger(1)) cs[0] = _pll.clkop;
        if (valueOf(n_output_clocks) >= fromInteger(2)) cs[1] = _pll.clkos;
        if (valueOf(n_output_clocks) >= fromInteger(3)) cs[2] = _pll.clkos2;
        if (valueOf(n_output_clocks) >= fromInteger(3)) cs[3] = _pll.clkos3;

        return cs;
    endmethod

    method locked = !_pll.not_lock;
endmodule

// The USRMCLK(..) interface is a wrapper for the ECP5's USRMCLK primitive, which is
// what controls the configuration SPI SCLK pin. Once the device enters user mode,
// usr_mclk_in can be used to drive a user defined clock out of the pin. Additionally,
// usr_mclk_ts can be driven to tri-state the pin.
// Details can be found in Lattice TN1260 ECP5 and ECP5-5G sysCONFIG Usage Guide in
// the Master SPI section.

interface USRMCLK;
    method Action usr_mclk_in((* port = "usr_mclk_in" *) Bit#(1) val);
    method Action usr_mclk_ts((* port = "usr_mclk_ts" *) Bit#(1) val);
endinterface

import "BVI" USRMCLK =
    module mkUSRMCLK (USRMCLK);
        method usr_mclk_in (USRMCLKI) enable((* inhigh *) EN0);
        method usr_mclk_ts (USRMCLKTS) enable((* inhigh *) EN1);
    endmodule

endpackage: ECP5

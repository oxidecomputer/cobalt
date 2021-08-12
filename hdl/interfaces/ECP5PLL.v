// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// This file was generated using the `ecppll` utility, part of nextpnr-ecp5 and edited to provide
// additional parameters and signals.

// diamond 3.7 accepts this PLL
// diamond 3.8-3.9 is untested
// diamond 3.10 or higher is likely to abort with error about unable to use feedback signal
// cause of this could be from wrong CPHASE/FPHASE parameters
module ECP5PLL
#(
    parameter CLKI_FREQUENCY = "",
    parameter CLKI_DIV = 0,
    parameter CLKOP_ENABLE = "",
    parameter CLKOP_FREQUENCY = "",
    parameter CLKOP_DIV = 0,
    parameter CLKOP_CPHASE = 0,
    parameter CLKOP_FPHASE = 0,
    parameter CLKOS_ENABLE = "",
    parameter CLKOS_FREQUENCY = "",
    parameter CLKOS_DIV = 0,
    parameter CLKOS_CPHASE = 0,
    parameter CLKOS_FPHASE = 0,
    parameter CLKOS2_ENABLE = "",
    parameter CLKOS2_FREQUENCY = "",
    parameter CLKOS2_DIV = 0,
    parameter CLKOS2_CPHASE = 0,
    parameter CLKOS2_FPHASE = 0,
    parameter CLKOS3_ENABLE = "",
    parameter CLKOS3_FREQUENCY = "",
    parameter CLKOS3_DIV = 0,
    parameter CLKOS3_CPHASE = 0,
    parameter CLKOS3_FPHASE = 0,
    parameter FB_DIV = 0,
    parameter FB_PATH = ""
)
(
    input CLKI,
    input CLKI_GATE,
    input CLKOP_GATE,
    input CLKOS_GATE,
    input CLKOS2_GATE,
    input CLKOS3_GATE,
    output CLKOP,
    output CLKOS,
    output CLKOS2,
    output CLKOS3,
    output LOCK
);
    (* FREQUENCY_PIN_CLKI=CLKI_FREQUENCY *)
    (* FREQUENCY_PIN_CLKOP=CLKOP_FREQUENCY *)
    (* FREQUENCY_PIN_CLKOS=CLKOS_FREQUENCY *)
    (* FREQUENCY_PIN_CLKOS2=CLKOS2_FREQUENCY *)
    (* FREQUENCY_PIN_CLKOS3=CLKOS3_FREQUENCY *)
    (* ICP_CURRENT="12" *) (* LPF_RESISTOR="8" *) (* MFG_ENABLE_FILTEROPAMP="1" *) (* MFG_GMCREF_SEL="2" *)
    EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("ENABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(CLKI_DIV),
        .CLKOP_ENABLE(CLKOP_ENABLE),
        .CLKOP_DIV(CLKOP_DIV),
        .CLKOP_CPHASE(CLKOP_CPHASE),
        .CLKOP_FPHASE(CLKOP_FPHASE),
        .CLKOS_ENABLE(CLKOS_ENABLE),
        .CLKOS_DIV(CLKOS_DIV),
        .CLKOS_CPHASE(CLKOS_CPHASE),
        .CLKOS_FPHASE(CLKOS_FPHASE),
        .CLKOS2_ENABLE(CLKOS2_ENABLE),
        .CLKOS2_DIV(CLKOS2_DIV),
        .CLKOS2_CPHASE(CLKOS2_CPHASE),
        .CLKOS2_FPHASE(CLKOS2_FPHASE),
        .CLKOS3_ENABLE(CLKOS3_ENABLE),
        .CLKOS3_DIV(CLKOS3_DIV),
        .CLKOS3_CPHASE(CLKOS3_CPHASE),
        .CLKOS3_FPHASE(CLKOS3_FPHASE),
        .FEEDBK_PATH(FB_PATH),
        .CLKFB_DIV(FB_DIV)
    ) pll_i (
        .RST(1'b0),
        .STDBY(~CLKI_GATE),
        .CLKI(CLKI),
        .CLKOP(CLKOP),
        .CLKOS(CLKOS),
        .CLKOS2(CLKOS2),
        .CLKOS3(CLKOS3),
        .CLKFB(CLKOP),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(CLKOP_GATE),
        .ENCLKOS(CLKOS_GATE),
        .ENCLKOS2(CLKOS2_GATE),
        .ENCLKOS3(CLKOS3_GATE),
        .LOCK(LOCK)
    );
endmodule

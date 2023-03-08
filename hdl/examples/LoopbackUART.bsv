// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package LoopbackUART;

export SampledSerialIO(..);
export LoopbackUART(..);
export mkLoopbackUART;

import Assert::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import BitSampling::*;
import SerialIO::*;
import Strobe::*;
import TestUtils::*;
import UART::*;

// This package contains an example of the UART primitives and demonstrates how
// a bit strobe is used to implement a peripheral which runs at a lower baud
// rate, independent of the design clock.

interface LoopbackUART#(
        numeric type clk_freq,
        numeric type baud_rate,
        numeric type bit_period);
    interface SampledSerialIO#(bit_period) serial;
    method Bit#(8) frame;
endinterface

module mkLoopbackUART (LoopbackUART#(clk_freq, baud_rate, bit_period))
        provisos (
            Add#(2, a__, bit_period)); // bit_period >= 2
    staticAssert(
        valueof(clk_freq) >= valueof(baud_rate) * valueof(bit_period),
        "clk_freq < baud_rate * bit_period");

    // The bit size for this strobe is picked a bit arbitrarily. For baud
    // rates/bit periods which do not wholly divide into the clock frequency,
    // adding more bits will reduce strobe jitter. Adding more bits to a strobe
    // will increase the addition carry chain, which limits the maximum
    // frequency of this design.
    let strobe_fraction = valueof(clk_freq) / valueof(baud_rate) / valueof(bit_period);
    Strobe#(16) bit_strobe <- mkFractionalStrobe(strobe_fraction, 0);
    mkFreeRunningStrobe(bit_strobe);

    SamplingTransceiver#(bit_period) txr <- mkSamplingTransceiver(bit_strobe);

    Reg#(Bit#(8)) received_frame <- mkRegU();

    (* fire_when_enabled *)
    rule do_loopback;
        let frame <- tpl_1(txr.frame).get;

        tpl_2(txr.frame).put(frame);
        received_frame <= frame;
    endrule

    interface SampledSerialIO serial = txr.serial;

    method frame = received_frame;
endmodule

module mkLoopbackUARTTest (Empty);
    LoopbackUART#(921600, 115200, 8) uart <- mkLoopbackUART();

    // Use another SerDes as source/sink.
    Serializer tx <- mkSerializer();
    Deserializer rx <- mkDeserializer();

    Reg#(Bit#(1)) rx_bit <- mkReg(1);
    Reg#(Bit#(1)) tx_bit <- mkReg(1);
    Strobe#(3) tx_strobe <- mkPowerTwoStrobe(1, 0);
    BitSampler#(8) rx_sampler <- mkBitSampler();

    mkFreeRunningStrobe(tx_strobe);
    mkConnection(rx_sampler.out, rx.in);

    Reg#(UInt#(9)) i <- mkRegU();
    Reg#(UInt#(9)) j <- mkRegU();

    // "Transmit" to the UART by getting the next bit from the test bench. The
    // rule fires contineously, but only fetches a new bit every bit period.
    (* fire_when_enabled *)
    rule do_tx;
        if (tx_strobe) begin
            let b <- tx.out.get;
            tx_bit <= b;
        end

        uart.serial.rx(tx_bit);
    endrule

    // Contineously receive from the UART and sample in order to recover the
    // transmitted frame.
    (* fire_when_enabled *)
    rule do_rx;
        rx_bit <= uart.serial.tx;
        rx_sampler.in.put(rx_bit);
    endrule

    mkAutoFSM(par
        for (i <= 0; i < 256; i <= i + 1)
            tx.in.put(truncate(pack(i)));

        for (j <= 0; j < 256; j <= j + 1)
            assert_get_eq(rx.out, truncate(pack(j)), "unexpected data");
    endpar);

    mkTestWatchdog((256 * 10 * 8) + 200);
endmodule

endpackage

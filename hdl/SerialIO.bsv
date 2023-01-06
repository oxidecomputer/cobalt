// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package SerialIO;

export SerialIO(..);
export SampledSerialIO(..);
export SampledSerialIOTxOutputEnable(..);
export SampledSerialIOTxInout(..);
export asSerialIO;
export mkSampledSerialIOWithBitStrobe;
export mkSampledSerialIOWithTxStrobe;
export mkSampledSerialIOWithPassiveTx;
export mkSampledSerialIOWithTxStrobeAndOutputEnable;
export mkSampledSerialIOWithTxStrobeInout;

import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import Vector::*;

import BitSampling::*;
import IOSync::*;
import Strobe::*;
import WriteOnlyTriState::*;


//
// The `SerialIO` package provides several adapters which can be used to connect
// serial interface primitives such as serializers/deserializers which use
// timing agnostic `Get`/`Put` interfaces to continuous IO signals in a design
// top interface. The implemented adapters use the `BitSampler` and `Strobe`
// primitives to appropriately align incoming and outgoing bits with the design
// frequency, allowing the protocol specific primitives to be as timing agnostic
// (and usually simple) as possible.
//
// For a concrete example of the `SampledSerialIO` interface and a UART, see the
// `SamplingTransceiver` in `hdl/interfaces/UART.bsv`, `LoopbackUART` in
// `hdl/examples/LoopbackUART.bsv` and a concrete realization of this module in
// the `Examples.bsv` for one of the boards foud in `hdl/boards`.
//

//
// `SerialIO` is a minimal interface used to represent continuous IO signals for
// a serial interface.
//

(* always_enabled *)
interface SerialIO;
    method Action rx(Bit#(1) val);
    method Bit#(1) tx();
endinterface

//
// The `SampledSerialIO` interface and its variants are used to implement
// sampled serial IO, for interfaces with a baud rate which runs at some
// fraction of the design frequency. This is done by sampling the bit period of
// the incoming signal and providing downstream modules with bit samples through
// their `Put` interface. The outgoing signal is generated by periodically
// polling the `Get` interface of an upstream module and buffering the bit for
// the appropriate duration.
//
// For troubleshooting the output of the bit sampler is exposed and can be
// directly connected to an output pin for analysis using a logic analyzer or
// oscilloscope.
//

(* always_enabled *)
interface SampledSerialIO #(numeric type bit_period);
    method Action rx(Bit#(1) val);
    method Bit#(1) rx_sample();
    method Bit#(1) tx();
endinterface

//
// `SampledSerialIOTxOutputEnable` and `SampledSerialIOTxInout` provide the
// ability to explicitly enable the output. This can be used for example to
// implement a SPI peripheral which releases its output driver when not
// selected.
//

(* always_enabled *)
interface SampledSerialIOTxOutputEnable #(numeric type bit_period);
    method Action rx(Bit#(1) val);
    method Bit#(1) rx_sample();
    method Bit#(1) tx();
    method Bool tx_enabled();
endinterface

(* always_enabled *)
interface SampledSerialIOTxInout #(numeric type bit_period);
    method Action rx(Bit#(1) val);
    method Bit#(1) rx_sample();
    interface Inout#(Bit#(1)) tx;
endinterface

function SerialIO asSerialIO(SampledSerialIO#(bit_period) io) =
    (interface SerialIO;
        method rx = io.rx;
        method tx = io.tx;
    endinterface);

module mkSampledSerialIOWithBitStrobe #(
        Bool bit_strobe,
        GetPut#(Bit#(1)) txr)
            (SampledSerialIO#(bit_period))
                provisos (Add#(2, a__, bit_period));
    InputReg#(Bit#(1), 2) rx_sync <- mkInputSync();
    Reg#(Bit#(1)) tx_sync <- mkConfigRegU();

    // This module is intended to be connected to pins in the top interface of a
    // design. BitSampler however requires an implicit reset because of its
    // implicit use of a RWire inside a DReg.
    //
    // https://github.com/B-Lang-org/bsc/blob/861ec2de8daeca2ee8666cc74c4d0155423c8b34/src/Libraries/Base1/PreludeBSV.bsv#L113
    // suggests that for sources without a reset it is appropriate to
    // instantiate an RWire without one. The implicit expectation of this module
    // is that since it is driven by an external signal the reset state of the
    // sampler should not matter and upstream receivers should do whatever is
    // necessary to correctly align themselves with the incoming data. It should
    // therefor be safe to instantiate the BitSampler without reset as is done
    // here.
    BitSampler#(bit_period) sampler <- mkBitSampler(reset_by noReset);
    Reg#(Bit#(1)) sample <- mkConfigRegU();

    Strobe#(TLog#(bit_period)) tx_strobe <-
        mkLimitStrobe(1, valueof(bit_period), 0);

    // Generate the TX strobe from the bit strobe.
    (* fire_when_enabled *)
    rule do_tx_strobe (bit_strobe);
        tx_strobe.send();
    endrule

    // Forward bit samples from the sampler to the receiver.
    (* fire_when_enabled *)
    rule do_rx_sample;
        let b <- sampler.out.get;

        tpl_2(txr).put(b);
        sample <= b;
    endrule

    (* fire_when_enabled *)
    rule do_tx (tx_strobe);
        let b <- tpl_1(txr).get;
        tx_sync <= b;
    endrule

    // Synchronize incoming bits and sample when indicated by the bit strobe.
    method Action rx(Bit#(1) b);
        rx_sync <= b;

        if (bit_strobe) begin
            sampler.in.put(rx_sync);
        end
    endmethod

    method rx_sample = sample;
    method tx = tx_sync;
endmodule

module mkSampledSerialIOWithTxStrobe #(
        Bool tx_strobe,
        GetPut#(Bit#(1)) txr)
            (SampledSerialIO#(bit_period))
                provisos (Add#(2, a__, bit_period));
    InputReg#(Bit#(1), 2) rx_sync <- mkInputSync();
    Reg#(Bit#(1)) tx_sync <- mkConfigRegU();

    // See above for a discussion on reset of the BitSampler.
    BitSampler#(bit_period) sampler <- mkBitSampler(reset_by noReset);
    Reg#(Bit#(1)) sample <- mkConfigRegU();

    // Forward bit samples from the sampler to the transceiver.
    (* fire_when_enabled *)
    rule do_rx_sample;
        let b <- sampler.out.get;

        tpl_2(txr).put(b);
        sample <= b;
    endrule

    (* fire_when_enabled *)
    rule do_tx (tx_strobe);
        let b <- tpl_1(txr).get;
        tx_sync <= b;
    endrule

    // Synchronize incoming bits and sample.
    method Action rx(Bit#(1) b);
        rx_sync <= b;
        sampler.in.put(rx_sync);
    endmethod

    method rx_sample = sample;
    method tx = tx_sync;
endmodule

module mkSampledSerialIOWithPassiveTx #(
        GetPut#(Bit#(1)) txr)
            (SampledSerialIO#(bit_period))
                provisos (Add#(2, a__, bit_period));
    InputReg#(Bit#(1), 2) rx_sync <- mkInputSync();
    Reg#(Bit#(1)) tx_sync <- mkConfigRegU();

    // See above for a discussion on reset of the BitSampler.
    BitSampler#(bit_period) sampler <- mkBitSampler(reset_by noReset);
    Reg#(Bit#(1)) sample <- mkConfigRegU();

    // Forward bit samples from the sampler to the transceiver.
    (* fire_when_enabled *)
    rule do_rx_sample;
        let b <- sampler.out.get;

        tpl_2(txr).put(b);
        sample <= b;
    endrule

    (* fire_when_enabled *)
    rule do_tx;
        tx_sync <= peekGet(tpl_1(txr));
    endrule

    // Synchronize incoming bits and sample when indicated by the bit strobe.
    method Action rx(Bit#(1) b);
        rx_sync <= b;
        sampler.in.put(rx_sync);
    endmethod

    method rx_sample = sample;
    method tx = tx_sync;
endmodule

module mkSampledSerialIOWithTxStrobeAndOutputEnable #(
        Bool tx_strobe,
        Bool tx_enable,
        GetPut#(Bit#(1)) txr)
            (SampledSerialIOTxOutputEnable#(bit_period))
                provisos (Add#(2, a__, bit_period));
    (* hide *) SampledSerialIO#(bit_period) _io <-
            mkSampledSerialIOWithTxStrobe(tx_strobe, txr);

    // Keep TX enable in phase with TX.
    Reg#(Bool) tx_enable_sync <- mkConfigRegU();

    (* fire_when_enabled *)
    rule do_tx_enable_sync;
        tx_enable_sync <= tx_enable;
    endrule

    method rx = _io.rx;
    method rx_sample = _io.rx_sample;
    method tx = _io.tx;
    method tx_enabled = tx_enable_sync;
endmodule

module mkSampledSerialIOWithTxStrobeInout #(
        Bool tx_strobe,
        Bool tx_enable,
        GetPut#(Bit#(1)) txr)
            (SampledSerialIOTxInout#(bit_period))
                provisos (Add#(2, a__, bit_period));
    (* hide *) SampledSerialIOTxOutputEnable#(bit_period) _io <-
            mkSampledSerialIOWithTxStrobeAndOutputEnable(
                tx_strobe,
                tx_enable,
                txr);

    (* hide *) WriteOnlyTriState#(Bit#(1)) _tx <-
        mkNullCrossingWriteOnlyTriState(_io.tx_enabled, _io.tx);

    method rx = _io.rx;
    method rx_sample = _io.rx_sample;
    interface Inout tx = _tx.o;
endmodule

//
//
//

typeclass ToSerialIO#(type t);
    function SerialIO toSerialIO(t o);
endtypeclass

//
// Connectable
//

instance Connectable#(
            SampledSerialIO#(bit_period),
            SampledSerialIO#(bit_period));
    module mkConnection #(
            SampledSerialIO#(bit_period) a,
            SampledSerialIO#(bit_period) b)
                (Empty);
        mkConnection(a.tx, b.rx);
        mkConnection(b.tx, a.rx);
    endmodule
endinstance

instance Connectable#(
        SampledSerialIOTxOutputEnable#(n),
        SampledSerialIOTxOutputEnable#(m));
    module mkConnection #(
            SampledSerialIOTxOutputEnable#(n) a,
            SampledSerialIOTxOutputEnable#(m) b)
                (Empty);
        (* fire_when_enabled *)
        rule do_tx;
            b.rx(a.tx_enabled ? a.tx : 0);
            a.rx(b.tx_enabled ? b.tx : 0);
        endrule
    endmodule
endinstance

instance Connectable#(SampledSerialIOTxOutputEnable#(n), SampledSerialIO#(m));
    module mkConnection #(
            SampledSerialIOTxOutputEnable#(n) a,
            SampledSerialIO#(m) b)
                (Empty);
        (* fire_when_enabled *)
        rule do_tx;
            b.rx(a.tx_enabled ? a.tx : 0);
            a.rx(b.tx);
        endrule
    endmodule
endinstance

instance Connectable#(SampledSerialIO#(n), SampledSerialIOTxOutputEnable#(m));
    module mkConnection #(
            SampledSerialIO#(n) a,
            SampledSerialIOTxOutputEnable#(m) b)
                (Empty);
        mkConnection(b, a);
    endmodule
endinstance

endpackage

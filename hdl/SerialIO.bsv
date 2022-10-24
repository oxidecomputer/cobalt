// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package SerialIO;

export SerialIO(..);
export ToSerialIO(..);
export SerialIOAdapter(..);
export mkSerialIOAdapter;
export mkSerialIOAdapterPassiveTx;

import ConfigReg::*;
import Connectable::*;
import GetPut::*;
import Vector::*;

import BitSampling::*;
import Strobe::*;


typedef GetPut#(Bit#(1)) SerialIO;

typeclass ToSerialIO#(type t);
    function SerialIO toSerialIO(t o);
endtypeclass

instance Connectable #(SerialIO, SerialIO);
    module mkConnection #(SerialIO sio1, SerialIO sio2) (Empty);
        mkConnection(tpl_1(sio1), tpl_2(sio2));
        mkConnection(tpl_2(sio1), tpl_1(sio2));
    endmodule
endinstance

//
// `SerialIOAdapter` is a convenience wrapper to connect something with a serial
// `GetPut#(Bit#(1))` interface to external signals. The wrapper includes a
// `BitSampler` and I/O registers for synchronization and because the output
// register does not require a reset it can be passed through a reset boundary.
//
// For easy troubleshooting the output of the bit sampler is exposed and can be
// directly connected to an output pin for analysis using a logic analyzer or
// oscilloscope.
//

interface SerialIOAdapter #(numeric type bit_period);
    (* always_enabled *) method Action rx(Bit#(1) val);
    (* always_enabled *) method Bit#(1) rx_mirror();
    (* always_enabled *) method Bit#(1) rx_sampled();
    (* always_enabled *) method Bit#(1) tx();
    (* always_enabled *) method Bit#(1) samples0();
    (* always_enabled *) method Bool sample_point();
endinterface

module mkSerialIOAdapter #(
        Strobe#(any_sz) tx_strobe,
        SerialIO txr)
            (SerialIOAdapter#(5));
                //provisos (Add#(2, _, bit_period));
    Reg#(Bit#(1)) tx_sync <- mkConfigRegU();
    Reg#(Bit#(1)) rx_sync <- mkConfigRegU();
    Reg#(Bit#(1)) rx_sampled_ <- mkConfigRegU();

    BitSamplerNg#(5) rx_sampler <- mkBitSamplerNg5();

    // Connect the sampler output to the transceiver Put.
    mkConnection(rx_sampler.out, tpl_2(txr));

    (* fire_when_enabled *)
    rule do_rx_sample;
        rx_sampled_ <= peekGet(rx_sampler.out);
    endrule

    (* fire_when_enabled *)
    rule do_tx (tx_strobe);
        let b <- tpl_1(txr).get;
        tx_sync <= b;
    endrule

    method Action rx(Bit#(1) b);
        rx_sync <= b;
        rx_sampler.in.put(rx_sync);
    endmethod

    method rx_mirror = rx_sync;
    method rx_sampled = rx_sampled_;
    method tx = tx_sync;

    method samples0 = rx_sampler.samples0;
    method sample_point = rx_sampler.sample_point;
endmodule

module mkSerialIOAdapterPassiveTx #(SerialIO txr)
            (SerialIOAdapter#(5));
                //provisos (Add#(2, _, bit_period));
    Reg#(Bit#(1)) tx_sync <- mkConfigRegU();
    Reg#(Bit#(1)) rx_sync <- mkConfigRegU();
    Reg#(Bit#(1)) rx_sampled_ <- mkConfigRegU();

    BitSamplerNg#(5) rx_sampler <- mkBitSamplerNg5();

    // Connect the sampler output to the transceiver Put.
    mkConnection(rx_sampler.out, tpl_2(txr));

    (* fire_when_enabled *)
    rule do_rx_sample;
        rx_sampled_ <= peekGet(rx_sampler.out);
    endrule

    (* fire_when_enabled *)
    rule do_tx;
        tx_sync <= peekGet(tpl_1(txr));
    endrule

    method Action rx(Bit#(1) b);
        rx_sync <= b;
        rx_sampler.in.put(rx_sync);
    endmethod

    method rx_mirror = rx_sync;
    method rx_sampled = rx_sampled_;
    method tx = tx_sync;

    method samples0 = rx_sampler.samples0;
    method sample_point = rx_sampler.sample_point;
endmodule

instance Connectable#(SerialIOAdapter#(n), SerialIOAdapter#(n));
    module mkConnection #(SerialIOAdapter#(n) a, SerialIOAdapter#(n) b) (Empty);
        mkConnection(a.tx, b.rx);
        mkConnection(b.tx, a.rx);
    endmodule
endinstance

endpackage

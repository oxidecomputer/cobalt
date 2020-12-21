// Copyright 2020 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package Encoding8b10bTest;

import Assert::*;
import GetPut::*;
import StmtFSM::*;

import Encoder8b10b::*;
import Decoder8b10b::*;
import Encoding8b10b::*;
import TestUtils::*;


interface Link;
    interface Put#(Value) send;
    interface Get#(ValueResult) receive;
    method Bool locked();

    method Action connect(Bool discard_decoded_values);
    method Action disconnect();

    // Guarded methods
    method Action await_locked();
    method Action await_not_locked();

    method UInt#(16) encoding_errors();
    method UInt#(16) decoding_errors();
endinterface

module mkLink #(Value idle_value) (Link);
    Serializer ser <- mkSerializer();
    Deserializer des <- mkDeserializer(IdleLow);

    Reg#(UInt#(16)) encoding_errors_ <- mkRegA(0);
    Reg#(UInt#(16)) decoding_errors_ <- mkRegA(0);

    Wire#(Value) next_value <- mkWire();
    Reg#(Bool) connected <- mkRegA(False);
    Reg#(Bool) discard_decoded_values <- mkRegA(False);

    PulseWire connect_requested <- mkPulseWire();
    PulseWire disconnect_requested <- mkPulseWire();

    function ActionValue#(ValueResult) get_decoded_value() =
        actionvalue
            let v <- des.out.get();
            if (!result_valid(v)) begin
                decoding_errors_ <= decoding_errors_ + (decoding_errors_ == unpack('1) ? 0 : 1);
            end
            return v;
        endactionvalue;

    (* fire_when_enabled *)
    rule do_connect (connect_requested && !disconnect_requested);
        $display("Connect");
        connected <= True;
    endrule

    (* fire_when_enabled *)
    rule do_disconnect (!connect_requested && disconnect_requested);
        $display("Disconnect");
        connected <= False;
    endrule

    (* fire_when_enabled *)
    rule do_put_bit_if_connected (connected);
        let b <- ser.out.get();
        des.in.put(b);
    endrule

    (* descending_urgency = "do_put_bit_if_connected, do_pull_down" *)
    rule do_pull_down;
        des.in.put(0);
    endrule

    (* fire_when_enabled *)
    rule do_send_value;
        ser.in.put(next_value);
    endrule

    (* descending_urgency = "do_send_value, do_send_idle_value" *)
    rule do_send_idle_value
            ((connect_requested && !disconnect_requested) || (connected && ser.last_call()));
        ser.in.put(idle_value);
    endrule

    (* fire_when_enabled *)
    rule do_discard_decoded_values (discard_decoded_values);
        let v <- get_decoded_value();
        $display(fshow(v));
    endrule

    (* fire_when_enabled *)
    rule do_count_encoding_errors (ser.encoding_error);
        encoding_errors_ <= encoding_errors_ + (encoding_errors_ == unpack('1) ? 0 : 1);
    endrule

    interface Put send = toPut(next_value._write);
    interface Get receive = toGet(get_decoded_value);

    method locked = des.locked;

    method Action connect(Bool discard_decoded_values_);
        discard_decoded_values <= discard_decoded_values_;
        connect_requested.send;
    endmethod
    method Action disconnect = disconnect_requested.send;

    method Action await_locked if (des.locked());
    endmethod

    method Action await_not_locked if (!des.locked());
    endmethod

    method encoding_errors = encoding_errors_._read;
    method decoding_errors = decoding_errors_._read;
endmodule

(* synthesize *)
module mkConnectTest (Empty);
    Link link <- mkLink(mk_k(28, 1));

    mkAutoFSM(seq
        repeat(10) noAction;
        link.connect(True /* discard decoded values */);
        link.await_locked();
        $finish;
    endseq);

    mkTestTimeout(100);
endmodule

(* synthesize *)
module mkDisconnectTest (Empty);
    Link link <- mkLink(mk_k(28, 1));

    mkAutoFSM(seq
        link.connect(True /* discard decoded values */);
        link.await_locked();
        link.disconnect();
        link.await_not_locked();
        dynamicAssert(link.decoding_errors() == 4, "expected 4 decoding errors");
        $finish;
    endseq);

    mkTestTimeout(150);
endmodule

endpackage

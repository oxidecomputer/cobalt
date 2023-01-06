// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package UART;

export Error(..);
export Serializer(..);
export Deserializer(..);
export mkSerializer;
export mkDeserializer;
export Transceiver(..);

export SampledSerialIO(..);
export SamplingTransceiver(..);
export mkSamplingTransceiver;

import Connectable::*;
import DReg::*;
import GetPut::*;
import FIFO::*;
import FIFOF::*;
import Probe::*;
import StmtFSM::*;
import Vector::*;

import BitSampling::*;
import SerialIO::*;
import Strobe::*;
import TestUtils::*;


typedef struct {
    Bool stop_missing;
    Bool overflow;
} Error deriving (Bits, Eq, FShow);

Error error_none = Error {stop_missing: False, overflow: False};

interface Deserializer;
    interface Put#(Bit#(1)) in;
    interface Get#(Bit#(8)) out;
    (* always_enabled *) method Error error();
endinterface

interface Serializer;
    interface Put#(Bit#(8)) in;
    interface Get#(Bit#(1)) out;
endinterface

interface Transceiver;
    interface GetPut#(Bit#(1)) serial;
    interface GetPut#(Bit#(8)) frame;
    (* always_enabled *) method Error error();
endinterface

Bit#(1) start = 0;
Bit#(1) stop_or_idle = 1;

module mkSerializer (Serializer);
    RWire#(Bit#(8)) in_frame <- mkRWire();
    Reg#(Vector#(9, Bit#(1))) buffer <- mkReg(replicate(stop_or_idle));

    Reg#(Bool) idle <- mkReg(True);
    PulseWire shift <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_serialize;
        if (in_frame.wget matches tagged Valid .frame) begin
            // Set the shifter to contain a START bit and the frame to be sent.
            buffer <= unpack({frame, start});
            idle <= False;
        end
        else if (shift) begin
            // Shift in stop/idle bits.
            buffer <= shiftInAtN(buffer, stop_or_idle);

            // A bit is shifted out during this cycle. If all but this bit are
            // the IDLE pattern it means the frame has been sent and the
            // serializer is idle.
            if (tail(buffer) == replicate(stop_or_idle)) begin
                idle <= True;
            end
        end
    endrule

    interface Put in;
        method Action put (Bit#(8) frame) if (idle);
            in_frame.wset(frame);
        endmethod
    endinterface

    interface Get out;
        method ActionValue#(Bit#(1)) get();
            shift.send();
            return buffer[0];
        endmethod
    endinterface
endmodule: mkSerializer

module mkDeserializer (Deserializer);
    FIFOF#(Bit#(8)) out_frame <- mkGLFIFOF(True, False);

    Reg#(Vector#(11, Bit#(1))) buffer <- mkRegU();
    Reg#(Bit#(4)) bits_remaining <- mkRegU();

    Reg#(Bool) fifo_full <- mkDReg(False);
    Reg#(Bool) stop_missing <- mkDReg(False);

    interface Put in;
        method Action put(Bit#(1) in_bit);
            // Always receive the next bit.
            buffer <= shiftInAtN(buffer, in_bit);

            // Check if a IDLE/STOP to START sequence and a STOP bit are present
            // in the receive buffer.
            let start_pattern = (buffer[0] == stop_or_idle && buffer[1] == start);
            let stop = (buffer[10] == stop_or_idle);

            // Update state based on the counter and what is currently in the
            // buffer.
            if (start_pattern && bits_remaining == 0) begin
                // Start looking for the next byte
                bits_remaining <= 9;

                if (stop) begin
                    // The buffer contains a start pattern, the frame and a
                    // STOP.
                    let frame = takeAt(2, buffer);

                    // Attempt to enqueue the received byte. The FIFO enq is
                    // unguarded (possibly overwriting the previous byte), so if
                    // it was still full raise the overflow flag.
                    out_frame.enq(pack(frame));

                    if (!out_frame.notFull) begin
                        fifo_full <= True;
                    end
                end
                else begin
                    stop_missing <= True;
                end
            end
            // Continue receiving bits.
            else if (bits_remaining != 0)begin
                bits_remaining <= bits_remaining - 1;
            end
        endmethod
    endinterface

    interface Get out = toGet(out_frame);

    method error = Error {
        stop_missing: stop_missing,
        overflow: fifo_full};
endmodule: mkDeserializer

module mkTransceiver (Transceiver);
    Serializer serializer <- mkSerializer();
    Deserializer deserializer <- mkDeserializer();

    interface GetPut serial = tuple2(serializer.out, deserializer.in);
    interface GetPut frame = tuple2(deserializer.out, serializer.in);
    method error = deserializer.error;
endmodule

interface SamplingTransceiver #(numeric type bit_period);
    interface SampledSerialIO#(bit_period) serial;
    interface GetPut#(Bit#(8)) frame;
    (* always_enabled *) method Error error();
endinterface

module mkSamplingTransceiver
        #(Bool bit_strobe)
            (SamplingTransceiver#(bit_period))
                provisos (Add#(2, a__, bit_period)); // bit_period >= 1
    (* hide *) Transceiver _txr <- mkTransceiver();
    (* hide *) SampledSerialIO#(bit_period) _serial <-
        mkSampledSerialIOWithBitStrobe(bit_strobe, _txr.serial);

    interface SampledSerialIO serial = _serial;
    interface GetPut frame = _txr.frame;
    method error = _txr.error;
endmodule

// Make Serializer/Deserializer connectable, because we can.
instance Connectable#(Serializer, Deserializer);
    module mkConnection#(Serializer ser, Deserializer des) (Empty);
        mkConnection(ser.out, des.in);
    endmodule
endinstance

//
// Tests
//

module mkSerializerTest (Empty);
    Serializer ser <- mkSerializer();

    mkAutoFSM(seq
        repeat(3) assert_get_eq(ser.out, stop_or_idle, "expected idle bit");
        action
            ser.in.put('h7f);
            assert_get_eq(ser.out, stop_or_idle, "expected idle bit");
        endaction
        assert_get_eq(ser.out, start, "expected start bit");
        repeat(7) assert_get_eq(ser.out, 1, "expected high bit");
        assert_get_eq(ser.out, 0, "expected low msb");
        assert_get_eq(ser.out, stop_or_idle, "expected stop bit");
        assert_get_eq(ser.out, stop_or_idle, "expected idle bit");
    endseq);

    mkTestWatchdog(15);
endmodule

module mkDeserializerTest (Empty);
    Deserializer des <- mkDeserializer();

    mkAutoFSM(seq
        repeat(3) des.in.put(stop_or_idle);
        des.in.put(start);
        repeat(7) des.in.put(1);    // Frame bits 0-6
        des.in.put(0);              // Frame msb
        des.in.put(stop_or_idle);
        des.in.put(stop_or_idle);
        assert_get_eq(des.out, 'h7f, "expected frame");
    endseq);

    mkTestWatchdog(15);
endmodule

module mkDeserializerStopMissingTest (Empty);
    Deserializer des <- mkDeserializer();

    mkAutoFSM(seq
        repeat(3) des.in.put(stop_or_idle);
        des.in.put(start);
        repeat(9) des.in.put(0);    // Frame bits 0-7 and 0 instead of STOP
        des.in.put(stop_or_idle);
        assert_true(des.error.stop_missing, "expected stop missing");
    endseq);

    mkTestWatchdog(15);
endmodule

module mkDeserializerOverflowTest (Empty);
    Deserializer des <- mkDeserializer();

    mkAutoFSM(seq
        repeat(3) des.in.put(stop_or_idle);

        // Receive two frames without retreiving them, causing a FIFO overflow.
        repeat(2) seq
            des.in.put(start);
            repeat(8) des.in.put(0);    // Frame bits 0-7
            des.in.put(stop_or_idle);
        endseq
        des.in.put(stop_or_idle);

        assert_true(des.error.overflow, "expected FIFO overflow");
    endseq);

    mkTestWatchdog(25);
endmodule

module mkSerializerDeserializerTest (Empty);
    mkTestWatchdog(400);

    Serializer ser <- mkSerializer();
    Deserializer des <- mkDeserializer();

    // A probe to make it easier to observe the "transmitted" bits.
    Probe#(Bit#(1)) b <- mkProbe();

    (* fire_when_enabled *)
    rule do_tx;
        let b_ <- ser.out.get;
        des.in.put(b_);
        b <= b_;
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_monitor_errors;
        assert_eq(des.error, error_none, "expected no errors");
    endrule

    mkAutoFSM(seq
        par
            repeat(3) ser.in.put('h71);
            repeat(3) assert_get_eq_display(des.out, 'h71, "frame");
        endpar

        // Demonstrate that the link can go idle for some number of cycles and
        // continue.
        repeat(10) noAction;

        par
            repeat(3) ser.in.put('h71);
            repeat(3) assert_get_eq_display(des.out, 'h71, "frame");
        endpar
    endseq);
endmodule

endpackage : UART

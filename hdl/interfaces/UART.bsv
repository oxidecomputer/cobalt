// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package UART;

export Error(..);
export Serializer(..);
export Deserializer(..);
export Transceiver(..);
export mkSerializer;
export mkDeserializer;
export mkTransceiver;

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

//
// This package implements serializer/deserializer primitives used to implement
// a minimal UART. The serializer/deserializer primitives are purely data driven
// and are expected to be combined with elements from `BitSampling` and `Strobe`
// and `SerialIO` packages to implement timing and bit sampling.
//

// Error struct for the `Deserializer`, indicating errors which occured while
// receiving bits.
typedef struct {
    // Indicates the STOP bit was missing in the received frame.
    Bool stop_missing;
    // Indicates the deserializer FIFO was full when the next frame was
    // received.
    Bool overflow;
} Error deriving (Bits, Eq, FShow);

Error error_none = Error {stop_missing: False, overflow: False};

//
// Interfaces for a UART `Serializer`, `Deserializer` and a `Transceiver`.
//
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

//
// `SamplingTransceiver` can be used to implement a `Transceiver` which operates
// at a lower baud rate than the design clock, by sampling each bit for a given
// number of cycles.
//
interface SamplingTransceiver #(numeric type bit_period);
    interface SampledSerialIO#(bit_period) serial;
    interface GetPut#(Bit#(8)) frame;
    (* always_enabled *) method Error error();
endinterface

Bit#(1) start = 0;
Bit#(1) stop_or_idle = 1;

//
// A minimal implementation of the `Serializer` interface, generating a stream
// of 8N1 frames from provided bytes. This implementation works as follows:
//
// When the serializer is idle and a byte is provided on the `in` interface, the
// byte is combined with a START bit and latched into a shift buffer. This
// buffer is then shifted every time the `out` interface is enabled and IDLE
// bits are inserted on the opposite end of the buffer. This fills the buffer
// with IDLE bits which will automatically get shifted out as STOP/IDLE once the
// byte has been transmitted. When the last bit of the byte has been shifted out
// the serializer is marked idle and the next byte can be submitted for
// transmission.
//
module mkSerializer (Serializer);
    RWire#(Bit#(8)) in_byte <- mkRWire();
    Reg#(Vector#(9, Bit#(1))) buffer <- mkReg(replicate(stop_or_idle));

    Reg#(Bool) idle <- mkReg(True);
    Reg#(UInt#(4)) bits_remaining <- mkRegU();

    PulseWire shift <- mkPulseWire();

    (* fire_when_enabled *)
    rule do_serialize;
        if (in_byte.wget matches tagged Valid .b) begin
            // Set the shifter to contain a START bit and the frame to be sent.
            buffer <= unpack({b, start});

            idle <= False;
            bits_remaining <= 1 + 8 + 1; // START + data + STOP
        end
        else if (shift) begin
            // Shift in stop/idle bits.
            buffer <= shiftInAtN(buffer, stop_or_idle);

            // Count down the remaining bits and set to idle if the last bit is
            // being shifted out.
            if (!idle) begin
                bits_remaining <= bits_remaining - 1;
            end

            if (bits_remaining == 1) begin
                idle <= True;
            end
        end
    endrule

    interface Put in;
        method Action put (Bit#(8) b) if (idle);
            in_byte.wset(b);
        endmethod
    endinterface

    interface Get out;
        method ActionValue#(Bit#(1)) get();
            shift.send();
            return buffer[0];
        endmethod
    endinterface
endmodule

//
// A minimal implementation of the 'Deserializer` interface, generating bytes
// from a serial stream of 8N1 frames. This module works as follows:
//
// 8N1 frames consist of a high to low transition (1 STOP/IDLE bit, followed by
// a START bit), 8 data bits and a STOP bit. The deserializer shifts bits into a
// shift buffer and scans this buffer for the 8N1 frame pattern. If the pattern
// is found the byte is enqueued and counter is set such that the contents of
// the shift buffer are ignored until all bits for a possible next 8N1 frame are
// received. If such a frame is received the byte is enqueued, but if instead
// the deserializer received idle bits the shift buffer will be examened on
// every received bit until the frame pattern appears, indicating the next
// received byte.
//
// The 8N1 serial protocol does not provide any means to synchronize the
// receiver to a transmitter other than by observing at least a full frame of
// IDLE bits. As such it may occur that the deserializer comes out of the reset
// in the middle of a frame and returns invalid data if what is received happens
// to match the frame pattern. This is expected and a higher level protocol
// should provide its own framing/parsing if alignment is required for proper
// operation.
//
// Note that the module expects downstream logic to dequeue received bytes as
// soon as they become available. If the output FIFO is full when the next frame
// is received the contents will be overwritten and the overflow flag in `Error`
// will be set for one cycle.
//
module mkDeserializer (Deserializer);
    FIFOF#(Bit#(8)) out_byte <- mkGLFIFOF(True, False);

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
                    // The buffer contains a START, byte and a STOP.
                    let b = takeAt(2, buffer);

                    // Attempt to enqueue the received byte. The FIFO enq is
                    // unguarded (possibly overwriting the previous byte), so if
                    // it was still full raise the overflow flag.
                    out_byte.enq(pack(b));

                    if (!out_byte.notFull) begin
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

    interface Get out = toGet(out_byte);

    method error = Error {
        stop_missing: stop_missing,
        overflow: fifo_full};
endmodule

//
// A `Transceiver` implemented by combining the minimal
// `Serializer`/`Deserializer` implementations.
//
module mkTransceiver (Transceiver);
    Serializer serializer <- mkSerializer();
    Deserializer deserializer <- mkDeserializer();

    interface GetPut serial = tuple2(serializer.out, deserializer.in);
    interface GetPut frame = tuple2(deserializer.out, serializer.in);
    method error = deserializer.error;
endmodule

//
// `mkSamplingTransceiver` implements a `SamplingTransceiver` by combining a
// `Transceiver` with a `SampledSerialIO` adapter. A period strobe which divides
// the current clock down to the desired baud rate is to be provided by external
// logic. The `serial` interface is already synchronized by the IO adapter and
// can be connected directly to a top interface/external pins.
//
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

//
// This test sends all possible frame values back to back through both the
// serializer and deserializer and makes sure a burst of data or specific data
// values do not cause control bits to be skipped.
//
module mkSerializerDeserializerTest (Empty);
    mkTestWatchdog(15000);

    Serializer ser <- mkSerializer();
    Deserializer des <- mkDeserializer();

    // A probe to make it easier to observe the "transmitted" bits.
    Probe#(Bit#(1)) b <- mkProbe();

    Reg#(UInt#(9)) i <- mkRegU();
    Reg#(UInt#(9)) j <- mkRegU();

    // The `half_rate` flag allows runs the "serial link" at half the rate of
    // the test bench providing back pressure on the `in` interface of the
    // `Serializer`. This is the common mode in which this module is expected to
    // run. The result is maximum utilization of the link with STOP/START bits
    // back to back between frames. Setting this flag to false causes a one
    // cycle gap between enqueued bytes, simulating what happens if the link is
    // faster than the data is supplied. The expected result is additional IDLE
    // bits inserted between frames.
    Reg#(Bool) half_rate <- mkReg(True);
    Reg#(Bool) next_byte <- mkReg(False);

    (* fire_when_enabled *)
    rule do_tx;
        if (!half_rate || (half_rate && next_byte)) begin
            let b_ <- ser.out.get;
            des.in.put(b_);
            b <= b_;

            next_byte <= False;
        end
        else begin
            next_byte <= True;
        end
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_monitor_errors;
        assert_eq(des.error, error_none, "expected no errors");
    endrule

    mkAutoFSM(seq
        // Serialize all values 0..255 in order and expect them to be
        // deserialized in the same order on the other end.
        half_rate <= True;
        par
            for (i <= 0; i < 256; i <= i + 1)
                ser.in.put(truncate(pack(i)));

            for (j <= 0; j < 256; j <= j + 1)
                assert_get_eq(des.out, truncate(pack(j)), "unexpected data");
        endpar

        // Demonstrate that the link can go idle for some number of cycles and
        // continue.
        repeat(100) noAction;

        // Repeat the test pattern above but run as fast as the deserializer
        // allows enqueueing bytes. Because the guard on that interface is
        // flopped an extra IDLE bit is inserted between every frame.
        half_rate <= False;
        par
            for (i <= 0; i < 256; i <= i + 1)
                ser.in.put(truncate(pack(i)));

            for (j <= 0; j < 256; j <= j + 1)
                assert_get_eq(des.out, truncate(pack(j)), "unexpected data");
        endpar
    endseq);
endmodule

endpackage

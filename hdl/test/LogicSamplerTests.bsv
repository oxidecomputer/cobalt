package LogicSamplerTests;

export UInt16SamplingMemory(..);
export UInt16SamplerByteProtocolFrontend(..);
export mkUInt16SamplingMemory;

import Assert::*;
import BRAM::*;
import Connectable::*;
import StmtFSM::*;
import Vector::*;

import LogicSampler::*;
import TestUtils::*;


typedef LogicSamplingMemory#(16, UInt#(16)) UInt16SamplingMemory;

module mkUInt16SamplingMemory (UInt16SamplingMemory);
    let n_samples_pre_trigger = 3;
    let n_samples_post_trigger = 3;
    let n_samples = n_samples_pre_trigger + n_samples_post_trigger;

    function Bool eq_hex10(UInt#(16) s) = s == 'h10;

    (* hide *) LogicSamplingMemory#(16, UInt#(16)) _memory <-
        mkLogicSamplingBRAM(
            eq_hex10,
            n_samples_pre_trigger,
            n_samples_post_trigger,
            defaultValue); // BRAM config.

    // Sample source, a simple 16 bit counter which counts up and rolls over.
    Reg#(UInt#(16)) c <- mkReg(0);

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_sample;
        _memory.sample.put(c);
        c <= c + 1;
    endrule

    return _memory;
endmodule

(* synthesize *)
module mkLogicSamplingMemoryTest (Empty);
    UInt16SamplingMemory memory <- mkUInt16SamplingMemory();

    function Action send_request(CommandRequest r) =
        action
            memory.control.request.put(r);
        endaction;

    //
    // Assertion helpers.
    //

    function Action assert_response_eq(ControlResponse expected, String msg) =
        assert_get_eq(memory.control.response, expected, msg);

    function Action assert_notification_eq(Notification n, String msg) =
        assert_response_eq(tagged Notification n, msg);

    function Action assert_recording_header_display(String msg) =
        action
            memory.data.deq();

            case (memory.data.first) matches
                tagged Header .header:
                    $display(fshow(header));
                default:
                    assert_fail(msg);
            endcase
        endaction;

    function Action assert_sample_display(String msg) =
        action
            memory.data.deq();

            case (memory.data.first) matches
                tagged Sample .s:
                    $display(fshow(s));
                default:
                    assert_fail(msg);
            endcase
        endaction;

    //
    // Rules and test script.
    //

    mkAutoFSM(seq
        send_request(Record);
        assert_response_eq(tagged Command Ok, "expected Ok");

        // Some time later a trigger notification should be received.
        assert_notification_eq(TriggerMatch, "expected TriggerMatch");
        assert_notification_eq(RecordingComplete, "expected RecordingComplete");

        // Play back recording.
        send_request(Playback);
        assert_response_eq(tagged Command Ok, "expected Ok");
        assert_recording_header_display("expected RecordingHeader");

        assert_sample_display("expected sample");
        assert_sample_display("expected sample");
        assert_sample_display("expected sample");
        assert_sample_display("expected sample");
        assert_sample_display("expected sample");
        assert_sample_display("expected sample");

        assert_notification_eq(PlaybackComplete, "expected PlaybackComplete");
    endseq);

    mkTestWatchdog(200);
endmodule

typedef ProtocolFrontend#(16, UInt#(16), Bit#(8), Bit#(8)) UInt16SamplerByteProtocolFrontend;
typedef Vector#(12, Bit#(8)) ByteBuffer;

(* synthesize *)
module mkByteProtocolFrontendTest (Empty);
    UInt16SamplingMemory memory <- mkUInt16SamplingMemory();
    UInt16SamplerByteProtocolFrontend frontend <- mkByteProtocolFrontend();

    mkConnection(frontend, memory);

    Reg#(UInt#(4)) i <- mkRegU();
    Reg#(ByteBuffer) header <- mkRegU();
    Reg#(ByteBuffer) samples <- mkRegU();

    function Action send_request(RequestByte request) =
        frontend.protocol.request.put(extend(pack(request)));

    function Action read_byte_into(Reg#(ByteBuffer) r, UInt#(any_sz) i_) =
        action
            let b <- frontend.protocol.response.get;
            r[i_] <= b;
        endaction;

    function Action assert_response_eq(ResponseByte response, String msg) =
        assert_get_eq(frontend.protocol.response, extend(pack(response)), msg);

    function Action assert_notification_eq(NotificationByte notification, String msg) =
        assert_get_eq(frontend.protocol.response, extend(pack(notification)), msg);

    mkAutoFSM(seq
        send_request(Nop);
        assert_response_eq(Ok, "expected Ok");

        frontend.protocol.request.put('hff);
        assert_response_eq(Invalid, "expected Invalid");

        send_request(Record);
        assert_response_eq(Ok, "expected start of recording");
        // Some time later a trigger notification should be received.
        assert_notification_eq(TriggerMatch, "expected TriggerMatch");
        assert_notification_eq(RecordingComplete, "expected RecordingComplete");

        send_request(Playback);
        assert_response_eq(Ok, "expected start of playback");

        // Read the header.
        for (i <= 0; i < 12; i <= i + 1) read_byte_into(asIfc(header), i);
        // Read the samples.
        for (i <= 0; i < 12; i <= i + 1) read_byte_into(asIfc(samples), i);

        assert_notification_eq(PlaybackComplete, "expected PlaybackComplete");

        $display(fshow(Vector#(3, UInt#(32))'(unpack(pack(header)))));
        $display(fshow(Vector#(6, UInt#(16))'(unpack(pack(samples)))));
    endseq);

    mkTestWatchdog(200);
endmodule

endpackage

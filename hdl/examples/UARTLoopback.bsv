package UARTLoopback;

import Assert::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import BitSampling::*;
import Strobe::*;
import TestUtils::*;
import UART::*;


interface UARTLoopback#(
        numeric type clk_freq,
        numeric type baud_rate,
        numeric type bit_period);
    (* always_ready, always_enabled *)
    interface Serial serial;
    method Bool sample_strobe;
    method Bool tx_strobe;
endinterface

module mkUARTLoopback (UARTLoopback#(clk_freq, baud_rate, bit_period))
        provisos (
            Add#(a__, 1, bit_period),         // bit_period > 0.
            Log#(bit_period, bit_period_sz)); // Make bit_period a power of two.
    staticAssert(
        valueof(clk_freq) >= valueof(baud_rate) * valueof(bit_period),
        "clk_freq < baud_rate * bit_period");

    // The bit size for this strobe is picked a bit arbitrarily. For baud rates/bit periods which do
    // not wholly divide into the clock frequency, adding more bits will reduce strobe jitter.
    // Adding more bits to a strobe will increase the addition carry chain, which limits the maximum
    // frequency of this design.
    Strobe#(16) sample_strobe_ <-
        mkFractionalStrobe(valueof(clk_freq) / valueof(baud_rate) / valueof(bit_period), 0);
    SamplingTransceiver#(bit_period) transceiver <- mkSamplingTransceiver(sample_strobe_);

    mkConnection(transceiver.receive, transceiver.send);

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_tick;
        sample_strobe_.send();
    endrule

    interface Serial serial;
        method Action rx(Bit#(1) val);
            if (sample_strobe_) begin
                transceiver.serial.rx(val);
            end
        endmethod
        method tx = transceiver.serial.tx;
    endinterface

    method sample_strobe = sample_strobe_._read;
    method tx_strobe = transceiver.tx_strobe;
endmodule

module mkUARTLoopbackTest (Empty);
    UARTLoopback#(25_000_000, 115200, 8) loopback <- mkUARTLoopback();

    // Use another SerDes as source/sink.
    Serializer ser <- mkSerializer();
    Deserializer des <- mkDeserializer();

    Reg#(Bit#(1)) tx_bit <- mkRegA(1);
    PulseWire latch_tx_bit <- mkPulseWire();

    // Delay register for receive pulse.
    Reg#(Bool) latch_rx_bit <- mkRegA(False);

    // Count the number of samples taken by the loopback
    // SerDes to establish a strobe for this test.
    Reg#(int) samples <- mkRegA(0);

    rule do_count_sample_pulses (loopback.sample_strobe());
        samples <= samples + 1;

        let tx_delay = 6;

        if (samples % 8 == tx_delay) begin
            latch_tx_bit.send();
        end
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_latch_next_bit;
        if (latch_tx_bit) begin
            let b <- ser.out.get();
            tx_bit <= b;
        end

        loopback.serial.rx(tx_bit);
    endrule

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_receive_bit;
        latch_rx_bit <= loopback.tx_strobe();

        if (latch_rx_bit) begin
            des.in.put(loopback.serial.tx());
        end
    endrule

    mkAutoFSM(seq
        ser.in.put('h55);
        ser.in.put('hAA);
        display_get_and_assert(des.out, 'h55, "expected 0x55");
        display_get_and_assert(des.out, 'hAA, "expected 0xAA");
        $finish;
    endseq);

    mkTestTimeout(10000);
endmodule

endpackage

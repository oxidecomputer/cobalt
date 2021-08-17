package UInt16Sampler;

import ClientServer::*;
import Connectable::*;
import GetPut::*;

import Board::*;
import ECP5::*;
import InitialReset::*;
import Strobe::*;
import UART::*;

import LogicSampler::*;
import LogicSamplerTests::*;

(* synthesize, default_clock_osc="clk_25mhz", default_reset="btn_pwr" *)
module mkUInt16Sampler (Top);
    Reset reset_sync <- mkInitialReset(2);

    // UART
    Strobe#(16) rx_strobe <- mkFractionalStrobe(25_000_000 / 115200 / 8, 0, reset_by reset_sync);
    SamplingTransceiver#(8) transceiver <- mkSamplingTransceiver(rx_strobe, reset_by reset_sync);

    // UInt16 Sampling Memory
    UInt16SamplingMemory memory <- mkUInt16SamplingMemory(reset_by reset_sync);
    UInt16SamplerByteProtocolFrontend frontend <- mkByteProtocolFrontend(reset_by reset_sync);

    mkConnection(frontend, memory);
    mkConnection(transceiver.receive, frontend.protocol.request);
    mkConnection(transceiver.send, frontend.protocol.response);

    mkFreeRunningStrobe(rx_strobe);

    // RX/TX sync registers. The rx register compbined with the sampler provides
    // two flops, guarding against metastability. The tx sync provides a
    // registered output for placement and allows the signal to cross the reset
    // boundary without a compiler warning.
    Reg#(Bit#(1)) rx_sync <- mkRegU();
    Reg#(Bit#(1)) tx_sync <- mkRegU();

    (* fire_when_enabled *)
    rule do_tx_sync;
        tx_sync <= transceiver.serial.tx;
    endrule

    (* fire_when_enabled *)
    rule do_rx (rx_strobe);
        transceiver.serial.rx(rx_sync);
    endrule

    interface FTDI ftdi;
        method rxd = tx_sync;
        method txd = rx_sync._write;
    endinterface

    interface ESP32 wifi;
        // Tie this high to keep board from resetting.
        method gpio0 = 1;
    endinterface

    method led = 0;

    method Action btn(Bit#(6) val);
        // Ignore buttons.
    endmethod

    method Action sw(Bit#(4) val);
        // Ignore switches.
    endmethod
endmodule

endpackage

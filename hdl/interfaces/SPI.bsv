// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package SPI;

// BSV-provided
import Clocks::*;
import ClientServer::*;
import Connectable::*;
import FIFO::*;
import FIFOF::*;
import GetPut::*;
import StmtFSM::*;
import Vector::*;

// Cobalt modules
import RegCommon::*;

interface SpiDecodeIF;
    interface Server#(SpiRx, Bit#(8)) spi_byte;
    interface Client#(RegRequest#(16, 8), RegResp#(8)) reg_con;
endinterface


typedef struct {
    Maybe#(Bit#(8)) spi_rx_byte;
    Bool done;
} SpiRx deriving (Bits, Eq);

typedef enum {
    OPCODE,
    ADDR1,
    ADDR2,
    DO_READ,
    DO_WRITE,
    READ_WAIT,
    WRITE_WAIT
} State deriving (Eq, Bits);

//
// This module provides a Client/Server interface
// That takes byte-wise SPI payloads over its Server interface,
// decodes the multi-byte spi protocol and issues Client transactions
// to the register block and recieves responses from the register block.
//
// The SPI protocol looks like this:
// <1byte Opcode> <1byte AddrH> <1byte AddrL> <n_bytes DATA>
//
module mkSpiRegDecode(SpiDecodeIF);
    // Registers
    Reg#(State) state <- mkReg(OPCODE);
    Reg#(Bit#(16)) address <- mkRegU();
    Reg#(RegOps) operation <- mkRegU();
    Reg#(Maybe#(Bit#(8))) reg_read_data <- mkReg(tagged Invalid);
    Reg#(Maybe#(Bit#(8))) reg_write_data <- mkReg(tagged Invalid);

    // comb signals
    RWire#(Bit#(8)) data <- mkRWire();
    PulseWire spi_deselected <- mkPulseWire();
    PulseWire got_data <- mkPulseWire();
    let my_data = fromMaybe(?, data.wget());

    // Store first byte which is the opcode
    rule store_op (state == OPCODE);
        if (spi_deselected) begin
            state <= OPCODE;
        end else if (got_data) begin
            // Turn opcode byte into an actual opcode
            operation <= unpack(truncate(my_data));
             state <= ADDR1;
        end
    endrule

    // Store second byte which is the MSB of address
    rule do_addr1 (state == ADDR1);
        if (spi_deselected) begin
            state <= OPCODE;
        end else if (got_data) begin
            state <= ADDR2;
            address <= {pack(my_data), address[7:0]};
        end
    endrule

    // Store third byte which is the LSB of address
    // If we're doing a read, we need to prime the pump by fetching a read
    // at this address immediately since we'll need to shift it out starting
    // at the next SPI clock cycle
    rule do_addr2 (state == ADDR2);
        let next_state = operation == READ ? DO_READ : WRITE_WAIT;
        if (spi_deselected) begin
            state <= OPCODE;
        end else if (got_data) begin
            state <= next_state;
            address <= {address[15:8], pack(my_data)};
        end
    endrule

    // This is a single-cycle state where the Client request
    // is "executed" by sending the request to the register block
    // This is also the last state in which the current address is
    // needed so we'll increment the address here for contiguous blocks
    // of reads or writes.
    rule do_register_request (state == DO_READ || state == DO_WRITE);
        if (spi_deselected) begin
            state <= OPCODE;
        end else begin
            let next_state = operation == READ ? READ_WAIT : WRITE_WAIT;
            state <= next_state;
            // We've consumed the curent address and we're done with it so increment
            // to get ready for the next read or write
            address <= address + 1;
            // Clear valid flag since this write data was consumed.
            reg_write_data <= tagged Invalid;
        end
    endrule

    // When doing reads or writes, we're going to auto-increment the address
    // Wait for the next byte to come in from the SPI block.
    rule do_wait (state == READ_WAIT || state == WRITE_WAIT);
        let next_state = operation == READ ? DO_READ : DO_WRITE;
        if (spi_deselected) begin
            state <= OPCODE;
        end else if (got_data) begin
            state <= next_state;
            // We got data while waiting. If this is a read, we don't care what happens
            // to the data here as it is dummy data. If this is a write
            // we store the data to build the transaction.
            reg_write_data <= tagged Valid my_data;
        end
    endrule

    // The Server interface to/from the shifter.
    // This is a server interface since the shifter drives this interface as a Client
    // Request spi_rx_structs come in, 8bit bytes go out.
    interface Server spi_byte;
        interface Put request;
            method Action put(spi_rx_struct);
                got_data.send();
                if (spi_rx_struct.done) begin
                    spi_deselected.send();
                end
                if (isValid(spi_rx_struct.spi_rx_byte)) begin
                    data.wset(fromMaybe(?, spi_rx_struct.spi_rx_byte));
                end
            endmethod
        endinterface
        // Return the read value
        interface Get response;
            method ActionValue#(Bit#(8)) get() if (isValid(reg_read_data));
                let ret_data = fromMaybe(?, reg_read_data);
                reg_read_data <= tagged Invalid;
                return ret_data;
            endmethod
        endinterface
    endinterface

    // Do the interface to the register block
    interface Client reg_con;
        // Request for register command
        // TODO: How do we specify that this must fire when enabled? If we don't require that
        // we could lose data in a larger system.
        interface Get request;
            method ActionValue#(RegRequest#(16, 8)) get() if (state == DO_READ || state == DO_WRITE);
                let ret = RegRequest {
                    address: address,
                    wdata: fromMaybe(?, reg_write_data),
                    op: operation
                };
                return ret;
            endmethod
        endinterface
        // Storage of the read-data is allowed anytime we don't currently have valid readdata.
        interface Put response;
            method Action put(resp) if (!isValid(reg_read_data));
                reg_read_data <= tagged Valid resp.readdata;
            endmethod
        endinterface
    endinterface


endmodule

interface SpiPeripheralSync;
    interface SpiPeripheralPins in_pins;
    interface SpiControllerPins syncd_pins;
endinterface


module mkSpiPeripheralPinSync(SpiPeripheralSync);
    Clock clk_sys <- exposeCurrentClock();
    Reset rst_sys <- exposeCurrentReset();
    // This is an output from the FPGA so we just bypass through here, no need to delay or synchronize.
    Wire#(Bit#(1)) cipo <- mkBypassWire();
    Wire#(Bool) output_en <- mkBypassWire();

    SyncBitIfc#(Bit#(1)) copi_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) csn_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);
    SyncBitIfc#(Bit#(1)) sclk_sync <- mkSyncBit1(clk_sys, rst_sys, clk_sys);


    interface SpiPeripheralPins in_pins;
         // Chip select pin, always sampled
        method csn = csn_sync.send;
        // sclk pin, always sampled
        method sclk = sclk_sync.send;
        // Input data pin latched on appropriate sclk detected edge
        method copi = copi_sync.send;
        // Output pin, always valid, shifts on appropriate sclk detected edge
        method cipo = cipo._read;
        method output_en = output_en._read;
    endinterface

    interface SpiControllerPins syncd_pins;
        method csn = csn_sync.read;  // CSN output
        method sclk = sclk_sync.read; // sclk output
        method copi = copi_sync.read; // data output
        method cipo = cipo._write;
        method output_en = output_en._write;
    endinterface

endmodule

//
// This is a server instance meant to be used in testing  the SPI
// decode block by acting like a register server interface.
//
// It has a single register that stores the results of the last write
// and can be operated on. The address written don't matter to this
// block.
// Any read will return the data currently in the single register.
//
module mkTestRegResponder(Server#(RegRequest#(16, 8), RegResp#(8)));
    PulseWire do_read <- mkPulseWire();
    PulseWire do_write <- mkPulseWire();
    PulseWire do_bitset <- mkPulseWire();
    PulseWire do_bitclear <- mkPulseWire();
    Reg#(Bit#(8)) only_reg <- mkReg(06);

    RWire#(Bit#(8)) rd_reg <- mkRWire();

    interface Put request;
            method Action put(request);
                if (request.op == WRITE) begin
                    only_reg <= request.wdata;
                    do_write.send();
                end else if (request.op == BITSET) begin
                    only_reg <= only_reg | request.wdata;
                    do_bitset.send();
                end else if (request.op == BITCLEAR) begin
                    only_reg <= only_reg & (~request.wdata);
                    do_bitclear.send();
                end else if (request.op == READ) begin
                    do_read.send();
                    rd_reg.wset(only_reg);
                end

            endmethod
        endinterface
        interface Get response;
            method ActionValue#(RegResp#(8)) get() if (isValid(rd_reg.wget()));
                return RegResp {readdata: fromMaybe(?, rd_reg.wget())};
            endmethod
        endinterface
endmodule

// Test bench
module mkSpiDecodeTest(Empty);
    SpiDecodeIF decode <- mkSpiRegDecode();
    Server#(RegRequest#(16, 8), RegResp#(8)) fake_reg <- mkTestRegResponder();
    mkConnection(decode.reg_con, fake_reg);

    let a_byte = tagged Valid ('hff);
    let read_byte = SpiRx {spi_rx_byte:  tagged Valid (zeroExtend(pack(READ))), done: False};
    let write_byte = SpiRx {spi_rx_byte:  tagged Valid (zeroExtend(pack(WRITE))), done: False};
    let zero_byte = SpiRx {spi_rx_byte: tagged Valid 'hff, done:False};
    let done_byte = SpiRx {spi_rx_byte: a_byte, done: True};

    function SpiRx make_byte (Bit#(8) data, Bool last);
        return SpiRx {spi_rx_byte: tagged Valid (data), done: last};
    endfunction

    // Simple function to do spi wites (or bitset, bitclears)
    function Stmt do_write(RegOps opcode, Bit#(16) address, Bit#(8) data);
        return seq
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(opcode)), False));  // OPCODE
            decode.spi_byte.request.put(make_byte(address[15:8], False));  // Addr1
            decode.spi_byte.request.put(make_byte(address[7:0], False));  // Addr2
            decode.spi_byte.request.put(make_byte(data, False)); // Data word
            decode.spi_byte.request.put(make_byte(data, True)); // Dummy data word
        endseq;
    endfunction

    // Simple function to test bitset
    function Stmt do_bitset();
        return seq
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(WRITE)), False));  // OPCODE
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(BITSET)), False));  // OPCODE
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h50, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
        endseq;
    endfunction
    // Simple function to test bitclear
    function Stmt do_bitclear();
        return seq
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(WRITE)), False));  // OPCODE
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
            decode.spi_byte.request.put(make_byte(zeroExtend(pack(BITCLEAR)), False));  // OPCODE
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
        endseq;
    endfunction

    function Stmt do_read();
        return seq
             decode.spi_byte.request.put(make_byte(zeroExtend(pack(WRITE)), False));  // OPCODE
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte('h05, False)); // Data word
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});

            decode.spi_byte.request.put(make_byte(zeroExtend(pack(READ)), False));  // OPCODE
            decode.spi_byte.request.put(make_byte(0, False));  // Addr1
            decode.spi_byte.request.put(make_byte(0, False));  // Addr2
            decode.spi_byte.request.put(make_byte(0, False)); // Data word
            // We should read a 'h05
            //$display(decode.spi_byte.response.get());
            decode.spi_byte.request.put(SpiRx {spi_rx_byte: tagged Invalid, done: True});
        endseq;
    endfunction

    mkAutoFSM(
        do_read()
    );

endmodule

// Physical pins interface for a SPI peripheral
interface SpiPeripheralPins;
    (* prefix = "" *)
    method Action csn((* port = "csn" *) Bit#(1) value);   // Chip select pin, always sampled
    (* prefix = "" *)
    method Action sclk((* port = "sclk" *) Bit#(1) value);  // sclk pin, always sampled
    (* prefix = "" *)
    method Action copi((* port = "copi" *) Bit#(1) data);   // Input data pin sampled on appropriate sclk detected edge
    (* prefix = "" *)
    method Bit#(1) cipo; // Output pin, always valid, shifts on appropriate sclk detected edge
    (* prefix = "" *)
    method Bool output_en; // Output Enable for CIPO, always valid
endinterface

// Physical pins interface for a SPI controller
interface SpiControllerPins;
    method Bit#(1) csn;  // CSN output
    method Bit#(1) sclk; // sclk output
    method Bit#(1) copi; // data output
    method Action cipo(Bit#(1) data);
    method Action output_en(Bool data);
endinterface

instance Connectable#(SpiControllerPins, SpiPeripheralPins);
        module mkConnection#(SpiControllerPins cpin, SpiPeripheralPins ppin) (Empty);
            mkConnection(cpin.csn, ppin.csn);
            mkConnection(cpin.sclk, ppin.sclk);
            mkConnection(cpin.cipo, ppin.cipo);
            mkConnection(cpin.copi, ppin.copi);
            mkConnection(cpin.output_en, ppin.output_en);
        endmodule
    endinstance

interface SpiPeripheralPhy;
    (* prefix = "" *)
    interface SpiPeripheralPins pins;  // Physical pins interface
    // Interface to decoderinterface Server#(SpiRx, Bit#(8)) spi_byte;
    interface Client#(SpiRx, Bit#(8)) decoder_if;
endinterface

// Main shift registers for a SPI peripheral
module mkSpiPeripheralPhy(SpiPeripheralPhy);
    //
    // SPI Mode notation: CPOL, CPHA:
    // SPI devices have two bits that determine their functionality CPOL (clock polarity)
    // and CPHA (clock phase).
    // CPOL=0: Clock idles at 0, clock cycle is a pulse of 1. Leading edge is rising, trailing edge is falling
    // CPOL=1: Clock idles at 1, clock cycle is a pulse of 0. Leading edge is falling, trailing edge is rising.
    // CPHA=0: "out" side changes data on trailing edge of preceding clock cycle, in side captures data on leading edge.
    //    The out side must hold data valid until the trailing edge of current clock cycle.
    //    First cycle, the first bit must be on COPI *before* the leading edge of first clock.
    // CPHA=1: "out" side changes data on leading edge of current clock cycle, "in" side captures data on trailing edge
    //    of clock cycle.
    //    Last cycle: the peripheral holds the CIPO line valid until deselected.
    //
    // Note: This module is currently designed to function in mode 0 (CPOL=0, CPHA=0).
    // Note: There isn't currently function to put valid data out on the CIPO wire for
    // the first byte after being selected. Typical SPI peripherals don't have valid data
    // to return the first cycle since the usually require a command byte/address byte to
    // present the requested data.

    // Module registers
    // For the TX and RX shift registers we're using 9 bit vectors: the "extra" bit is
    // "done shifting" flag vs using counters
    Reg#(Vector#(9, Bit#(1))) tx_shift <- mkReg(unpack('h01));
    Reg#(Vector#(9, Bit#(1))) rx_shift <- mkReg(unpack('h01));
    Reg#(Bit#(1)) sclk_last <- mkRegU();
    Reg#(Bit#(1)) csn_last <- mkRegU();
    Reg#(Bit#(1)) rx_shifter_msb_last <- mkReg(0);
    // We want unguarded deq here because we don't want to pass a deq implicit condition up to the shifter rule generally.
    // It will manually check for empty before dequeing when appropriate.
    FIFOF#(Bit#(8)) new_tx_data <- mkGFIFOF(False, True);

    // Module combo things
    PulseWire sclk_leading_edge <- mkPulseWire();   // Single cycle pulse for leading edge
    PulseWire sclk_trailing_edge <- mkPulseWire();  // Single cycle pulse for trailing edge
    PulseWire deselected  <- mkPulseWire();         // Single cycle pulse for losing bus selection
    PulseWire selected  <- mkPulseWire();           // Single cycle pulse for gaining bus selection
    PulseWire rx_byte_done  <- mkPulseWire();

    RWire#(Bit#(1)) cur_sclk <- mkRWire();
    RWire#(Bit#(1)) cur_csn  <- mkRWire();
    RWire#(Bit#(1)) cur_copi <- mkRWire();

    // csn and sclk edge detectors making combo flags on edge conditions.
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_edge_detectors;
        let sclk =  fromMaybe(sclk_last, cur_sclk.wget());
        let csn = fromMaybe(csn_last, cur_csn.wget());
        // csn edge detector
        if (csn == 1) begin
            deselected.send();
        end else if (csn_last == 1 && csn == 0) begin
            selected.send();
        end
        // sclk edge detector (only when selected ie: CSN=0)
        if (csn == 0 && sclk_last == 0 && sclk == 1) begin
            sclk_leading_edge.send();
        end
        if (csn == 0 && sclk_last == 1 && sclk == 0) begin
            sclk_trailing_edge.send();
        end
        csn_last <= csn;
        sclk_last <= sclk;
    endrule

    // Use the extra flag to know when we've shifted in a valid byte.
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_done_rx;
        rx_shifter_msb_last <= rx_shift[8];
        if (rx_shifter_msb_last == 0 && rx_shift[8] == 1) begin
            rx_byte_done.send();
        end
    endrule

    // Upon gaining bus selection, reset the tx and rx shifters.
    // Note that the sclk_trailing_edge and sclk_leading_edge can't really happen this
    // cycle in a normal system but we put them here to help the compiler prove that there is
    // rule exclusivity since we're writing to the tx_shift and rx_shift registers in multiple rules.
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_shifter_reset (selected && !sclk_trailing_edge && !sclk_leading_edge);
        // TODO: Note we could check to see if we have valid tx data here to solve the first clock problem.
        tx_shift <= unpack('h01);
        rx_shift <= unpack('h01);
    endrule

    (* fire_when_enabled, no_implicit_conditions*)
    rule do_tx_shifter (sclk_trailing_edge);
        // Accept new data into the the tx shift register before the first clock if we're done shifting
        // and there's new data available in the FIFO.
        if (pack(tx_shift)[7:0] == 'h80 && new_tx_data.notEmpty()) begin
            // TODO: is there a function list that makes this prettier.
            tx_shift <= unpack({pack(new_tx_data.first), 1});  // New data needs to be here
            new_tx_data.deq();
        end else if (pack(tx_shift)[7:0] == 'h80) begin
            tx_shift <= unpack('h01);  //TODO: Can declare a constant
        end else begin
            tx_shift <= shiftInAt0(tx_shift, 0);
        end
    endrule

    // SPI mode 0,0 so shift in sampled on rising edge
    (* fire_when_enabled, no_implicit_conditions *)
    rule do_shift_in (sclk_leading_edge);
        if (rx_shift[8] == 1) begin
            rx_shift <= shiftInAt0(unpack('h01), fromMaybe(?, cur_copi.wget()));
        end else begin
            rx_shift <= shiftInAt0(rx_shift, fromMaybe(?, cur_copi.wget()));
        end
    endrule

    interface SpiPeripheralPins pins;
        // Chip select pin, always sampled
        method csn = cur_csn.wset;
        // sclk pin, always sampled
        method sclk = cur_sclk.wset;
        // Input data pin latched on appropriate sclk detected edge
        method copi = cur_copi.wset;
        // Output pin, always valid, shifts on appropriate sclk detected edge
        method Bit#(1) cipo;
            return tx_shift[8];
        endmethod
        method Bool output_en;
            // output enable is active when we're selected
            return (fromMaybe(1, cur_csn.wget()) == 0);
        endmethod
    endinterface

    interface Client decoder_if;
        // Send byte to the decoder when we have a new valid byte or
        interface Get request;
            // TODO: could build a protocol
            method ActionValue#(SpiRx) get() if (rx_byte_done || deselected);
                Maybe#(Bit#(8)) data_byte = !deselected ? tagged Valid (pack(rx_shift)[7:0]) : tagged Invalid;
                let ret = SpiRx {spi_rx_byte: data_byte, done: deselected};
                return ret;
            endmethod
        endinterface
        // accept byte from the decoder when it hands one to us.
        interface Put response;
            method Action put(resp);  // implicit condition here is fifo is empty
                new_tx_data.enq(resp);
            endmethod
        endinterface
    endinterface

endmodule

interface ModelSpiController;
    interface SpiControllerPins pins;
    interface Server#(Vector#(4, Bit#(8)),Vector#(4, Bit#(8))) bfm;
endinterface

typedef enum {IDLE, CS_START, SHIFTING, CS_STOP} ContState deriving (Eq, Bits);
typedef struct {
    Vector#(arrayWidth, Bit#(8)) data;
} ContData#(numeric type arrayWidth);

module mkModelSpiController(ModelSpiController);

    Reg#(Vector#(4, Bit#(8))) tx_buffer <- mkRegU();
    Reg#(Vector#(4, Bit#(8))) rx_buffer <- mkRegU();
    Reg#(UInt#(4)) sclk_cntr <- mkRegU();
    Reg#(Bit#(1)) sclk <- mkReg(0);
    Reg#(Bit#(1)) sclk_last <- mkReg(0);
    Reg#(Bit#(1)) csn <- mkReg(1);
    Reg#(Bit#(1)) cipo <- mkReg(0);
    Reg#(Bool) output_en <- mkReg(False);
    Reg#(Bit#(8)) rem_bytes <- mkReg(0);
    Reg#(UInt#(4)) cs_cntr   <- mkReg(0);
    Reg#(ContState) state <- mkReg(IDLE);

    Reg#(Vector#(9, Bit#(1))) out_shifter <- mkReg(unpack('h00));
    Reg#(Vector#(9, Bit#(1))) in_shifter <- mkReg(unpack('h01));

    PulseWire start <- mkPulseWire();
    PulseWire sclk_redge <- mkPulseWire();
    PulseWire sclk_fedge <- mkPulseWire();

    rule do_csn;
        if (state != IDLE) begin
            csn <= 0;
        end else begin
            csn <= 1;
        end
    endrule

    rule do_sclk (state == SHIFTING);
        sclk_cntr <= sclk_cntr + 1;
        if (sclk_cntr == 1) begin
            sclk <= 1;
        end
        if (sclk_cntr == 9) begin
            sclk <= 0;
        end
        sclk_last <= sclk;
    endrule

    rule do_edges (state == SHIFTING);
        if (sclk_last == 0 && sclk == 1) begin
           sclk_redge.send();
       end
        if (sclk_last == 1 && sclk == 0) begin
            sclk_fedge.send();
        end
    endrule

    rule do_idle (state == IDLE);
        if (start) begin
          sclk_cntr <= 0;
          state <= CS_START;
        end
    endrule

    rule do_cs_start (state == CS_START);
        cs_cntr <= cs_cntr + 1;
        if (cs_cntr == 'h0f) begin
            state <= SHIFTING;
        end
        // Load the first word
        out_shifter <= unpack({pack(tx_buffer[0]), 1});
    endrule

    rule do_shift_out (state == SHIFTING && sclk_fedge);
        // Done with bytes?
        if (rem_bytes == 0) begin
            state <= CS_STOP;
            cs_cntr <= 0;
        end
        // Load data to be tx'd
        if (pack(out_shifter)[7:0] == 'h80) begin
            let head_data = tx_buffer[4-rem_bytes+1];
            out_shifter <= unpack({pack(head_data), 1});
            rem_bytes <= rem_bytes - 1;
        end else begin
            // On falling edge, shift until done (== 'h100).
            out_shifter <= shiftInAt0(out_shifter, 0);
        end

    endrule

    rule do_shift_in (state == SHIFTING && sclk_redge);
        if (in_shifter[8] == 1) begin
            in_shifter <= shiftInAt0(unpack('h01), cipo);
        end else begin
            in_shifter <= shiftInAt0(in_shifter, cipo);
            if (pack(in_shifter)[8:7] == 'b01) begin
                rx_buffer[4-rem_bytes] <= pack(shiftInAt0(in_shifter, cipo))[7:0];
            end
        end
    endrule

    rule do_cs_stop (state == CS_STOP);
        if (cs_cntr == 'h0f) begin
            state <= IDLE;
            cs_cntr <= 0;
            out_shifter <= unpack('h00);
            in_shifter <= unpack('h01);
        end else begin
            cs_cntr <= cs_cntr + 1;
        end
    endrule

    interface SpiControllerPins pins;

        method csn = csn._read;  // CSN output
        method sclk = sclk._read; // sclk output
        method Bit#(1) copi(); // data output
            return out_shifter[8];
        endmethod
        method cipo = cipo._write;
        method output_en = output_en._write;
    endinterface

    interface Server bfm;
        interface Get response;
            method ActionValue#(Vector#(4, Bit#(8))) get() if (state == CS_STOP);
                return rx_buffer;
            endmethod
        endinterface

        interface Put request;
            method Action put(request) if (state == IDLE);
                tx_buffer <= request;
                rem_bytes <= 4;
                start.send();
            endmethod
        endinterface
    endinterface

endmodule

// Want: a SPI Controller BFM with the following functionality:
// Read address method, takes address, byte_number, returns a list of byte_number bytes
// Read check method, takes address, list of bytes, returns true if bytes returned match
// Request interface looks like this:
// Address, operation, list{bytes}
// Write address method, takes address, byte buffer


// Test bench
module mkSpiPhyTest(Empty);
    ModelSpiController controller <- mkModelSpiController();
    SpiDecodeIF decode <- mkSpiRegDecode();
    SpiPeripheralPhy phy <- mkSpiPeripheralPhy();
    Server#(RegRequest#(16, 8), RegResp#(8)) fake_reg <- mkTestRegResponder();

    mkConnection(decode.reg_con, fake_reg); // client-server interface between decoder and reg
    mkConnection(decode.spi_byte, phy.decoder_if); // client-server interface between phy and decoder
    // connect all the gpio pins
    mkConnection(phy.pins.csn, controller.pins.csn);
    mkConnection(phy.pins.cipo, controller.pins.cipo);
    mkConnection(phy.pins.copi, controller.pins.copi);
    mkConnection(phy.pins.sclk, controller.pins.sclk);


    mkAutoFSM(
        seq
            action
                Vector#(4, Bit#(8)) tx =  newVector();
                tx[0] = unpack(zeroExtend(pack(READ)));
                tx[1] = unpack('h00);
                tx[2] = unpack('h00);
                tx[3] = unpack('h00);
                controller.bfm.request.put(tx);
            endaction
            action
                let rx <- controller.bfm.response.get();
                $display(rx[0]);
                $display(rx[1]);
                $display(rx[2]);
                $display(rx[3]);
            endaction
            delay(20);
            $display("Next");
            action
                Vector#(4, Bit#(8)) tx =  newVector();
                tx[0] = unpack(zeroExtend(pack(READ)));
                tx[1] = unpack('h00);
                tx[2] = unpack('h00);
                tx[3] = unpack('h00);
                controller.bfm.request.put(tx);
            endaction
            action
                let rx <- controller.bfm.response.get();
                $display(rx[0]);
                $display(rx[1]);
                $display(rx[2]);
                $display(rx[3]);
            endaction
        endseq
    );

endmodule
endpackage

// Copyright 2022 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package SchmittReg;

export SchmittReg(..);
export EdgePatterns(..);
export mkSchmittReg, mkSchmittRegA, mkSchmittRegU;

import Assert::*;
import StmtFSM::*;
import Vector::*;


//
// A schmitt trigger with Reg#(..) interface, intended to clean up noisy
// signals by being a filter at whatever frequency `_write` is called. The
// register can be used with any single bit type. If a more robust, less glitch
// tolerant behavior is desired, consider the `Debouncer` package.
//

interface SchmittReg #(numeric type n_samples, type one_bit_type);
    method one_bit_type _read();
    method Action _write(one_bit_type val);
endinterface

typedef struct {
    Bit#(n_samples) negative_edge;
    Bit#(n_samples) positive_edge;
    Bit#(n_samples) mask;
} EdgePatterns#(numeric type n_samples);

function Action update(
        Reg#(one_bit_type) q,
        Reg#(Vector#(n_samples, one_bit_type)) ds,
        one_bit_type d,
        EdgePatterns#(n_samples) edge_patterns)
            provisos (
                Bits#(one_bit_type, 1)) =
    action
        let ds_next = shiftInAt0(ds, d);
        let negative_edge = edge_patterns.negative_edge & edge_patterns.mask;
        let positive_edge = edge_patterns.positive_edge & edge_patterns.mask;

        ds <= ds_next;
        q <= case (pack(ds_next))
            negative_edge: unpack(0);
            positive_edge: unpack(1);
            default: q;
        endcase;
    endaction;

function Vector#(n_samples, one_bit_type) init_vector(one_bit_type init)
        provisos (Bits#(one_bit_type, 1));
    let v = pack(init) == 1 ? unpack(1) : unpack(0);
    return replicate(v);
endfunction

module mkSchmittReg#(
        one_bit_type init,
        EdgePatterns#(n_samples) edge_patterns)
            (SchmittReg#(n_samples, one_bit_type))
            provisos (
                Bits#(one_bit_type, 1));
    Reg#(one_bit_type) q <- mkReg(init);
    Reg#(Vector#(n_samples, one_bit_type)) ds <- mkReg(init_vector(init));

    method _read = q._read;
    method Action _write(one_bit_type d) = update(q, ds, d, edge_patterns);
endmodule

module mkSchmittRegA#(
        one_bit_type init,
        EdgePatterns#(n_samples) edge_patterns)
            (SchmittReg#(n_samples, one_bit_type))
            provisos (
                Bits#(one_bit_type, 1));
    Reg#(one_bit_type) q <- mkRegA(init);
    Reg#(Vector#(n_samples, one_bit_type)) ds <- mkRegA(init_vector(init));

    method _read = q._read;
    method Action _write(one_bit_type d) = update(q, ds, d, edge_patterns);
endmodule

module mkSchmittRegU
        #(EdgePatterns#(n_samples) edge_patterns)
            (SchmittReg#(n_samples, one_bit_type))
            provisos (
                Bits#(one_bit_type, 1));
    Reg#(one_bit_type) q <- mkRegU();
    Reg#(Vector#(n_samples, one_bit_type)) ds <- mkRegU();

    method _read = q._read;
    method Action _write(one_bit_type d) = update(q, ds, d, edge_patterns);
endmodule

// `mkSlowEdgeSchmittRegTest` tests a filter where three consequitive 0's or 1's
// are required before the output generates a positive or negative edge.
module mkSlowEdgeSchmittRegTest (Empty);
    let edge_patterns = EdgePatterns {
        negative_edge: 'b000,
        positive_edge: 'b111,
        mask: 'b111};

    SchmittReg#(3, Bit#(1)) r <- mkSchmittReg(0, edge_patterns);

    mkAutoFSM(seq
        repeat(3) r <= 0;
        dynamicAssert(r == 0, "Expected no change");
        repeat(3) r <= 1;
        dynamicAssert(r == 1, "Expected positive edge");
        repeat(3) r <= 1;
        dynamicAssert(r == 1, "Expected no change");
        repeat(3) r <= 0;
        dynamicAssert(r == 0, "Expected negative edge");
    endseq);
endmodule


// `mkFastPositiveEdgeSchmittRegTest` tests a filter where the output
// immediately reflects a positive edge on the input but requires three
// consequitive 0's before showing a falling edge.
module mkFastPositiveEdgeSchmittRegTest (Empty);
    let edge_patterns = EdgePatterns {
        negative_edge: 'b000,
        positive_edge: 'b001,
        mask: 'b111};

    SchmittReg#(3, Bit#(1)) r <- mkSchmittReg(0, edge_patterns);

    mkAutoFSM(seq
        r <= 0;
        r <= 0;
        r <= 0;
        dynamicAssert(r == 0, "Expected no change");
        r <= 1;
        dynamicAssert(r == 1, "Expected positive edge");
        r <= 1;
        r <= 1;
        r <= 1;
        dynamicAssert(r == 1, "Expected no change");
        r <= 0;
        r <= 0;
        r <= 0;
        dynamicAssert(r == 0, "Expected negative edge");
    endseq);
endmodule

module mkLongBounceSchmittRegTest (Empty);
    let edge_patterns = EdgePatterns {
        negative_edge: 'b000,
        positive_edge: 'b001,
        mask: 'b111};

    SchmittReg#(3, Bit#(1)) r <- mkSchmittReg(0, edge_patterns);

    mkAutoFSM(seq
        r <= 1;
        dynamicAssert(r == 1, "Expected positive edge");
        // Bounce ten times.
        repeat(10) seq
            r <= 0;
            r <= 1;
            dynamicAssert(r == 1, "Expected no change");
        endseq
        repeat(3) r <= 0;
        dynamicAssert(r == 0, "Expected negative edge");
    endseq);
endmodule

endpackage: SchmittReg

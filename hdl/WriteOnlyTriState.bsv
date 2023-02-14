// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package WriteOnlyTriState;

import TriState::*;

//
// `WriteOnlyTriState(..)` is an interface which can be used to represent an
// output buffer with enable pin connecting to an IO pin. This primitive could
// for example be used for the SO signal of a SPI peripheral which is expected
// to not drive the pin unless CS is asserted.
//
// The `TriState` interface can serve this function, but because of the `_read`
// method it requires its `io` member to be associated with a clock domain,
// which poses some ergonomic challenges when dealing with clock and reset
// domains in the top of designs.
//
interface WriteOnlyTriState #(type bits_type);
    interface Inout#(bits_type) o;
endinterface

module mkWriteOnlyTriState #(Bool en, bits_type val)
        (WriteOnlyTriState#(bits_type))
            provisos(Bits#(bits_type, sz));
    (* hide *) TriState#(bits_type) _pad <- mkTriState(en, val);

    interface Inout o = _pad.io;
endmodule

//
// `mkNullCrossingWriteOnlyTriState` is similar to `mkNullCrossingWire` and
// allows the `o` subinterface to be connected to another clock domain (and by
// virtue of lacking a reset, another reset domain). This allows the `Inout` to
// be connected directly to an `Inout` in a top level interface without
// triggering warnings about crossing clock or reset domains.
//
// Note that this should only be used for output signals connecting to `Inout`
// subinterfaces in a top interface, without any additional logic in the middle.
// In all other cases the resulting behavior is likely not what is intended and
// proper synchronisation primitives should be used prior to using this
// primitive.
//
import "BVI" TriState =
module mkNullCrossingWriteOnlyTriState #(
        Bool en,
        bits_type val)
            (WriteOnlyTriState#(bits_type))
                provisos(Bits#(bits_type, sz));
   default_clock clk();
   default_reset no_reset;

   parameter width = valueof(sz);

   ifc_inout o(IO) clocked_by(no_clock);

   port I = val;
   port OE = en;

   path (I,  IO);
   path (OE, IO);
endmodule

endpackage

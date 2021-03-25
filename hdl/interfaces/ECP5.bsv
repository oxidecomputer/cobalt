// Copyright 2021 Oxide Computer Company
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

package ECP5;

//
// GSR primitive, which provides a global reset of the fabric using a user signal. This is
// effectively the same as a PoR and can be used for external reset.
//
// Note: this currently uses the default reset of the module instantiating this primitive.
//

interface GSR;
endinterface

import "BVI" GSR =
    module mkGSR (GSR ifc);
        default_clock no_clock;
        default_reset gsr (GSR);
    endmodule

endpackage : ECP5

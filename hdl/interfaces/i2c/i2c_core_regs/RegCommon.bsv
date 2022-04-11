// This module will take spi bytes via a server interface
// And pass out requests via a client interface.

package RegCommon;

import GetPut::*;
import ClientServer::*;
import Connectable::*;


typedef enum {WRITE, READ, BITSET, BITCLEAR, NOOP} RegOps deriving (Eq, Bits);

typedef struct {
   Bit#(addrWidth) address;
   Bit#(dataWidth) wdata;
   RegOps   op;
} RegRequest#(numeric type addrWidth, numeric type dataWidth) deriving (Bits);

typedef struct {
   Bit#(dataWidth) readdata;
} RegResp#(numeric type dataWidth) deriving (Bits);

// This function deals with the write, bitset, bitclear etc
// TODO, would like to better deal with software enables etc or generate this whole thing
function treg reg_update(treg current_value, treg next_value, taddr address, Integer my_address, RegOps operation, Bit#(bitSize) writedata)
    provisos(Bits#(treg, bitSize), Eq#(taddr), Literal#(taddr), Bits#(taddr, addrSize));
    let reg_out = current_value;  // Default to hold current value
    if (address == fromInteger(my_address)) begin
        if (operation == WRITE) begin
            reg_out = unpack(writedata);
        end else if (operation == BITSET) begin
            reg_out = unpack(writedata | pack(current_value));
        end else if  (operation == BITCLEAR) begin
            reg_out = unpack(~writedata & pack(current_value));
        end else begin
            reg_out = next_value;
        end
    end else begin
        reg_out = next_value;
    end
        return reg_out;
endfunction

endpackage
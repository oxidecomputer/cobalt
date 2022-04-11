
// This is a generated file using the RDL tooling. Do not edit by hand.
package I2cCoreRegs;

import Reserved::*;
import RegCommon::*;

// Register PRESCALE definitions
typedef struct {
        Bit#(16)           prescale;  // bit 15:0
    
} Prescale deriving (Eq, FShow);
// Register offsets
Integer prescaleOffset = 0;
// Field mask definitions
    Bit#(16) prescalePrescale = 'hffff;
// Register PRESCALE custom type-classes
instance Bits#(Prescale, 16);
    function Bit#(16) pack (Prescale r);
        Bit#(16) bts =  'h00;
        bts[15:0] = r.prescale;
        return bts;
    endfunction: pack
    function Prescale unpack (Bit#(16) b);
        let r = Prescale {
        prescale: b[15:0] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(Prescale);
    function Prescale \& (Prescale i1, Prescale i2) =
        unpack(pack(i1) & pack(i2));
    function Prescale \| (Prescale i1, Prescale i2) =
        unpack(pack(i1) | pack(i2));
    function Prescale \^ (Prescale i1, Prescale i2) =
        unpack(pack(i1) ^ pack(i2));
    function Prescale \~^ (Prescale i1, Prescale i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Prescale \^~ (Prescale i1, Prescale i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Prescale invert (Prescale i) =
        unpack(invert(pack(i)));
    function Prescale \<< (Prescale i, t x) =
        error("Left shift operation is not supported with type Prescale");
    function Prescale \>> (Prescale i, t x) =
        error("Right shift operation is not supported with type Prescale");
    function Bit#(1) msb (Prescale i) =
        error("msb operation is not supported with type Prescale");
    function Bit#(1) lsb (Prescale i) =
        error("lsb operation is not supported with type Prescale");
endinstance

// Register CONTROL definitions
typedef struct {
        Bit#(1)            en    ;  // bit 7
    
        Bit#(1)            ien   ;  // bit 6
    
    
} Control deriving (Eq, FShow);
// Register offsets
Integer controlOffset = 2;
// Field mask definitions
    Bit#(8) controlEn     = 'h80;
    Bit#(8) controlIen    = 'h40;
// Register CONTROL custom type-classes
instance Bits#(Control, 8);
    function Bit#(8) pack (Control r);
        Bit#(8) bts =  'h00;
        bts[7] = r.en;
        bts[6] = r.ien;
        return bts;
    endfunction: pack
    function Control unpack (Bit#(8) b);
        let r = Control {
        en: b[7] , 
        ien: b[6] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(Control);
    function Control \& (Control i1, Control i2) =
        unpack(pack(i1) & pack(i2));
    function Control \| (Control i1, Control i2) =
        unpack(pack(i1) | pack(i2));
    function Control \^ (Control i1, Control i2) =
        unpack(pack(i1) ^ pack(i2));
    function Control \~^ (Control i1, Control i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Control \^~ (Control i1, Control i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Control invert (Control i) =
        unpack(invert(pack(i)));
    function Control \<< (Control i, t x) =
        error("Left shift operation is not supported with type Control");
    function Control \>> (Control i, t x) =
        error("Right shift operation is not supported with type Control");
    function Bit#(1) msb (Control i) =
        error("msb operation is not supported with type Control");
    function Bit#(1) lsb (Control i) =
        error("lsb operation is not supported with type Control");
endinstance

// Register TRANSMIT definitions
typedef struct {
        Bit#(7)            tx_data;  // bit 7:1
    
        Bit#(1)            rw     ;  // bit 0
    
} Transmit deriving (Eq, FShow);
// Register offsets
Integer transmitOffset = 3;
// Field mask definitions
    Bit#(8) transmitTxData = 'hfe;
    Bit#(8) transmitRw      = 'h01;
// Register TRANSMIT custom type-classes
instance Bits#(Transmit, 8);
    function Bit#(8) pack (Transmit r);
        Bit#(8) bts =  'h00;
        bts[7:1] = r.tx_data;
        bts[0] = r.rw;
        return bts;
    endfunction: pack
    function Transmit unpack (Bit#(8) b);
        let r = Transmit {
        tx_data: b[7:1] , 
        rw: b[0] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(Transmit);
    function Transmit \& (Transmit i1, Transmit i2) =
        unpack(pack(i1) & pack(i2));
    function Transmit \| (Transmit i1, Transmit i2) =
        unpack(pack(i1) | pack(i2));
    function Transmit \^ (Transmit i1, Transmit i2) =
        unpack(pack(i1) ^ pack(i2));
    function Transmit \~^ (Transmit i1, Transmit i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Transmit \^~ (Transmit i1, Transmit i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Transmit invert (Transmit i) =
        unpack(invert(pack(i)));
    function Transmit \<< (Transmit i, t x) =
        error("Left shift operation is not supported with type Transmit");
    function Transmit \>> (Transmit i, t x) =
        error("Right shift operation is not supported with type Transmit");
    function Bit#(1) msb (Transmit i) =
        error("msb operation is not supported with type Transmit");
    function Bit#(1) lsb (Transmit i) =
        error("lsb operation is not supported with type Transmit");
endinstance

// Register RECEIVE definitions
typedef struct {
        Bit#(8)            rx_data;  // bit 7:0
    
} Receive deriving (Eq, FShow);
// Register offsets
Integer receiveOffset = 4;
// Field mask definitions
    Bit#(8) receiveRxData = 'hff;
// Register RECEIVE custom type-classes
instance Bits#(Receive, 8);
    function Bit#(8) pack (Receive r);
        Bit#(8) bts =  'h00;
        bts[7:0] = r.rx_data;
        return bts;
    endfunction: pack
    function Receive unpack (Bit#(8) b);
        let r = Receive {
        rx_data: b[7:0] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(Receive);
    function Receive \& (Receive i1, Receive i2) =
        unpack(pack(i1) & pack(i2));
    function Receive \| (Receive i1, Receive i2) =
        unpack(pack(i1) | pack(i2));
    function Receive \^ (Receive i1, Receive i2) =
        unpack(pack(i1) ^ pack(i2));
    function Receive \~^ (Receive i1, Receive i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Receive \^~ (Receive i1, Receive i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Receive invert (Receive i) =
        unpack(invert(pack(i)));
    function Receive \<< (Receive i, t x) =
        error("Left shift operation is not supported with type Receive");
    function Receive \>> (Receive i, t x) =
        error("Right shift operation is not supported with type Receive");
    function Bit#(1) msb (Receive i) =
        error("msb operation is not supported with type Receive");
    function Bit#(1) lsb (Receive i) =
        error("lsb operation is not supported with type Receive");
endinstance

// Register COMMAND definitions
typedef struct {
        Bit#(1)            start ;  // bit 7
    
        Bit#(1)            stop  ;  // bit 6
    
        Bit#(1)            read  ;  // bit 5
    
        Bit#(1)            write ;  // bit 4
    
        Bit#(1)            ack   ;  // bit 3
    
    
        Bit#(1)            iack  ;  // bit 0
    
} Command deriving (Eq, FShow);
// Register offsets
Integer commandOffset = 5;
// Field mask definitions
    Bit#(8) commandStart  = 'h80;
    Bit#(8) commandStop   = 'h40;
    Bit#(8) commandRead   = 'h20;
    Bit#(8) commandWrite  = 'h10;
    Bit#(8) commandAck    = 'h08;
    Bit#(8) commandIack   = 'h01;
// Register COMMAND custom type-classes
instance Bits#(Command, 8);
    function Bit#(8) pack (Command r);
        Bit#(8) bts =  'h00;
        bts[7] = r.start;
        bts[6] = r.stop;
        bts[5] = r.read;
        bts[4] = r.write;
        bts[3] = r.ack;
        bts[0] = r.iack;
        return bts;
    endfunction: pack
    function Command unpack (Bit#(8) b);
        let r = Command {
        start: b[7] , 
        stop: b[6] , 
        read: b[5] , 
        write: b[4] , 
        ack: b[3] , 
        iack: b[0] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(Command);
    function Command \& (Command i1, Command i2) =
        unpack(pack(i1) & pack(i2));
    function Command \| (Command i1, Command i2) =
        unpack(pack(i1) | pack(i2));
    function Command \^ (Command i1, Command i2) =
        unpack(pack(i1) ^ pack(i2));
    function Command \~^ (Command i1, Command i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Command \^~ (Command i1, Command i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Command invert (Command i) =
        unpack(invert(pack(i)));
    function Command \<< (Command i, t x) =
        error("Left shift operation is not supported with type Command");
    function Command \>> (Command i, t x) =
        error("Right shift operation is not supported with type Command");
    function Bit#(1) msb (Command i) =
        error("msb operation is not supported with type Command");
    function Bit#(1) lsb (Command i) =
        error("lsb operation is not supported with type Command");
endinstance

// Register STATUS definitions
typedef struct {
        Bit#(1)            rx_ack  ;  // bit 7
    
        Bit#(1)            bus_busy;  // bit 6
    
    
        Bit#(1)            tip     ;  // bit 1
    
        Bit#(1)            ifl     ;  // bit 0
    
} Status deriving (Eq, FShow);
// Register offsets
Integer statusOffset = 6;
// Field mask definitions
    Bit#(8) statusRxAck   = 'h80;
    Bit#(8) statusBusBusy = 'h40;
    Bit#(8) statusTip      = 'h02;
    Bit#(8) statusIfl      = 'h01;
// Register STATUS custom type-classes
instance Bits#(Status, 8);
    function Bit#(8) pack (Status r);
        Bit#(8) bts =  'h00;
        bts[7] = r.rx_ack;
        bts[6] = r.bus_busy;
        bts[1] = r.tip;
        bts[0] = r.ifl;
        return bts;
    endfunction: pack
    function Status unpack (Bit#(8) b);
        let r = Status {
        rx_ack: b[7] , 
        bus_busy: b[6] , 
        tip: b[1] , 
        ifl: b[0] 
        };
        
        return r;
    endfunction: unpack

endinstance

instance Bitwise#(Status);
    function Status \& (Status i1, Status i2) =
        unpack(pack(i1) & pack(i2));
    function Status \| (Status i1, Status i2) =
        unpack(pack(i1) | pack(i2));
    function Status \^ (Status i1, Status i2) =
        unpack(pack(i1) ^ pack(i2));
    function Status \~^ (Status i1, Status i2) =
        unpack(pack(i1) ~^ pack(i2));
    function Status \^~ (Status i1, Status i2) =
        unpack(pack(i1) ^~ pack(i2));
    function Status invert (Status i) =
        unpack(invert(pack(i)));
    function Status \<< (Status i, t x) =
        error("Left shift operation is not supported with type Status");
    function Status \>> (Status i, t x) =
        error("Right shift operation is not supported with type Status");
    function Bit#(1) msb (Status i) =
        error("msb operation is not supported with type Status");
    function Bit#(1) lsb (Status i) =
        error("lsb operation is not supported with type Status");
endinstance

endpackage: I2cCoreRegs
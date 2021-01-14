package Blinky;


interface Blinky #(numeric type clk_f);
    (* always_ready, always_enabled *)
    method Bit#(2) led();
    method Action button_pressed();
endinterface

module mkBlinky (Blinky#(clk_f))
        provisos (Log#(clk_f, count_sz),
                  Add#(reload_sz, 1, count_sz));
    let reload = fromInteger(valueof(clk_f) / 2 - 1);

    Reg#(UInt#(reload_sz)) c <- mkRegA(reload);
    Reg#(Bit#(1)) d0 <- mkRegA(0);
    Reg#(Bit#(1)) d1 <- mkRegA(0);

    PulseWire button_pressed_ <- mkPulseWire();

    (* no_implicit_conditions, fire_when_enabled *)
    rule do_blink;
        let zero = c == 0;
        c <= zero ? reload : c - 1;

        // Write the LED bits.
        d0 <= zero ? ~d0 : d0;
        d1 <= button_pressed_ ? 1 : 0;
    endrule

    method led = {d1, d0};
    method button_pressed = button_pressed_.send;
endmodule

endpackage : Blinky

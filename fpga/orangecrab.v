/*
 * OrangeCrab ECP5-85F wrapper for tt_um_kilian_interference
 * Generates 25.2 MHz VGA pixel clock from 48 MHz oscillator via PLL.
 * VGA PMOD directly maps to uo_out[7:0] on GPIO pins.
 */

`default_nettype none

module top (
    input  wire clk48,      // 48 MHz oscillator
    input  wire usr_btn,    // User button (directly active high after DDR IO pad)
    output wire led_r,      // RGB LED red (active low)
    output wire led_g,       // RGB LED green (active low)
    output wire led_b,      // RGB LED blue (active low)
    output wire [7:0] pmod  // VGA PMOD: directly maps to uo_out
);

    wire clk_25m;
    wire pll_locked;

    // PLL: 48 MHz -> 25.2 MHz
    // VCO = 48 * 21 / 2 = 504 MHz, CLKOP = 504 / 20 = 25.2 MHz
    pll_25m pll_inst (
        .clki(clk48),
        .clko(clk_25m),
        .locked(pll_locked)
    );

    wire [7:0] uo_out;

    tt_um_kilian_interference demo (
        .ui_in  (8'b0000_0000),
        .uo_out (uo_out),
        .uio_in (8'h00),
        .uio_out(),
        .uio_oe (),
        .ena    (1'b1),
        .clk    (clk_25m),
        .rst_n  (pll_locked)
    );

    assign pmod = uo_out;

    // LED: green when PLL locked, off otherwise
    assign led_r = 1'b1;            // off (active low)
    assign led_g = ~pll_locked;     // on when locked
    assign led_b = 1'b1;            // off

endmodule


// ECP5 PLL: 48 MHz -> 25.2 MHz
module pll_25m (
    input  wire clki,
    output wire clko,
    output wire locked
);

    (* ICP_CURRENT="12" *)
    (* LPF_RESISTOR="8" *)
    (* MFG_ENABLE_FILTEROPAMP="1" *)
    (* MFG_GMCREF_SEL="2" *)
    EHXPLLL #(
        .PLLRST_ENA       ("DISABLED"),
        .INTFB_WAKE       ("DISABLED"),
        .STDBY_ENABLE      ("DISABLED"),
        .DPHASE_SOURCE     ("DISABLED"),
        .OUTDIVIDER_MUXA   ("DIVA"),
        .OUTDIVIDER_MUXB   ("DIVB"),
        .OUTDIVIDER_MUXC   ("DIVC"),
        .OUTDIVIDER_MUXD   ("DIVD"),
        .CLKI_DIV          (2),
        .CLKOP_ENABLE      ("ENABLED"),
        .CLKOP_DIV         (20),
        .CLKOP_CPHASE      (9),
        .CLKOP_FPHASE      (0),
        .FEEDBK_PATH       ("CLKOP"),
        .CLKFB_DIV         (21)
    ) pll_i (
        .RST       (1'b0),
        .STDBY     (1'b0),
        .CLKI      (clki),
        .CLKOP     (clko),
        .CLKFB     (clko),
        .CLKINTFB  (),
        .PHASESEL0 (1'b0),
        .PHASESEL1 (1'b0),
        .PHASEDIR  (1'b0),
        .PHASESTEP (1'b0),
        .PHASELOADREG (1'b0),
        .PLLWAKESYNC (1'b0),
        .ENCLKOP   (1'b0),
        .LOCK      (locked)
    );

endmodule

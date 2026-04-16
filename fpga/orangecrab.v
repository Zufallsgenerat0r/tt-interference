/*
 * OrangeCrab ECP5-85F wrapper for tt_um_kilian_interference
 * Divides 48 MHz to ~24 MHz for VGA pixel clock (close enough for VGA tolerance).
 */

`default_nettype none

module top (
    input  wire clk48,
    input  wire usr_btn,
    output wire led_r,
    output wire led_g,
    output wire led_b,
    output wire [7:0] pmod
);

    // Simple clock divider: 48 MHz / 2 = 24 MHz
    // VGA spec is 25.175 MHz, but monitors tolerate ~5% deviation.
    // 24 MHz = 4.7% slow — within tolerance for most monitors.
    reg clk_24m;
    always @(posedge clk48)
        clk_24m <= ~clk_24m;

    // Power-on reset
    reg [3:0] reset_cnt = 4'hF;
    wire rst_n = (reset_cnt == 0);
    always @(posedge clk_24m)
        if (reset_cnt != 0)
            reset_cnt <= reset_cnt - 1;

    wire [7:0] uo_out;

    tt_um_kilian_interference demo (
        .ui_in  (8'b0000_0000),
        .uo_out (uo_out),
        .uio_in (8'h00),
        .uio_out(),
        .uio_oe (),
        .ena    (1'b1),
        .clk    (clk_24m),
        .rst_n  (rst_n)
    );

    // Invert HSYNC[7] and VSYNC[3] for active-low VGA sync.
    assign pmod = uo_out ^ 8'b1000_1000;

    assign led_r = 1'b1;
    assign led_g = ~rst_n;  // green when running
    assign led_b = 1'b1;

endmodule

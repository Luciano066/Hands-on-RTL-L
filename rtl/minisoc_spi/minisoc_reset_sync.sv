`timescale 1ns/1ps
`default_nettype none

// D21: asynchronous assertion; release after two LOCAL rising edges.
// A stopped domain remains in reset. No clocks are manufactured here.
module minisoc_reset_sync (
    input wire clk, input wire arst_n, output wire rst_n
);
    (* ASYNC_REG = "TRUE" *) logic meta_q, release_q;
    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin meta_q <= 0; release_q <= 0; end
        else begin meta_q <= 1; release_q <= meta_q; end
    end
    assign rst_n = release_q;
endmodule
`default_nettype wire

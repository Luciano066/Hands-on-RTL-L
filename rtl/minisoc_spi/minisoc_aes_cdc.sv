`timescale 1ns/1ps
`default_nettype none

// D23: interface adapter only, NOT an AES/PLL integration. Engine consumes
// cfg_valid && cfg_ready once; it must retain status_valid/data until ready.
// Status acknowledgements must complete before stopping sys_clk (P23).
module minisoc_aes_cdc (
    input wire clk, input wire sys_clk, input wire rst_n,
    input wire cfg_valid_i, output wire cfg_ready_o,
    input wire [355:0] cfg_i,
    output wire cfg_valid_o, input wire cfg_ready_i,
    output wire [355:0] cfg_o,
    input wire status_valid_i, output wire status_ready_o,
    input wire [11:0] status_i,
    output wire status_valid_o, input wire status_ready_i,
    output wire [11:0] status_o
);
    wire clk_rst_n, sys_rst_n;
    minisoc_reset_sync ctrl_reset (.clk(clk), .arst_n(rst_n), .rst_n(clk_rst_n));
    minisoc_reset_sync aes_reset (.clk(sys_clk), .arst_n(rst_n), .rst_n(sys_rst_n));
    minisoc_cdc_mailbox #(.WIDTH(356)) config_box (
        .src_clk(clk), .src_rst_n(clk_rst_n),
        .src_valid_i(cfg_valid_i), .src_ready_o(cfg_ready_o), .src_data_i(cfg_i),
        .dst_clk(sys_clk), .dst_rst_n(sys_rst_n),
        .dst_valid_o(cfg_valid_o), .dst_ready_i(cfg_ready_i), .dst_data_o(cfg_o)
    );
    minisoc_cdc_mailbox #(.WIDTH(12)) status_box (
        .src_clk(sys_clk), .src_rst_n(sys_rst_n),
        .src_valid_i(status_valid_i), .src_ready_o(status_ready_o), .src_data_i(status_i),
        .dst_clk(clk), .dst_rst_n(clk_rst_n),
        .dst_valid_o(status_valid_o), .dst_ready_i(status_ready_i), .dst_data_o(status_o)
    );
endmodule
`default_nettype wire

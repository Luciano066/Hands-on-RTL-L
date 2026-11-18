`timescale 1ns/1ps
`default_nettype none

// One outstanding transfer. Bundled data stays frozen until destination
// CONSUMPTION is acknowledged. Both resets must assert together; release may
// occur independently. Physical max-delay/skew constraints are still required.
module minisoc_cdc_mailbox #(parameter integer WIDTH = 32) (
    input wire src_clk, input wire src_rst_n,
    input wire src_valid_i, output wire src_ready_o,
    input wire [WIDTH-1:0] src_data_i,
    input wire dst_clk, input wire dst_rst_n,
    output logic dst_valid_o, input wire dst_ready_i,
    output logic [WIDTH-1:0] dst_data_o
);
    logic [WIDTH-1:0] hold_q;
    logic req_q, ack_q;
    (* ASYNC_REG = "TRUE" *) logic [1:0] ack_sync_q, req_sync_q;
    logic guard_q;
    assign src_ready_o = src_rst_n && (req_q == ack_sync_q[1]);
    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            req_q <= 0; hold_q <= 0; ack_sync_q <= 0;
        end else begin
            ack_sync_q <= {ack_sync_q[0], ack_q};
            if (src_valid_i && src_ready_o) begin
                hold_q <= src_data_i;
                req_q <= ~req_q;
            end
        end
    end
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            req_sync_q <= 0; ack_q <= 0; guard_q <= 0;
            dst_valid_o <= 0; dst_data_o <= 0;
        end else begin
            req_sync_q <= {req_sync_q[0], req_q};
            if (dst_valid_o) begin
                if (dst_ready_i) begin
                    dst_valid_o <= 0;
                    ack_q <= req_sync_q[1];
                end
            end else if (req_sync_q[1] != ack_q) begin
                if (guard_q) begin
                    dst_data_o <= hold_q;
                    dst_valid_o <= 1;
                    guard_q <= 0;
                end else guard_q <= 1;
            end else guard_q <= 0;
        end
    end
endmodule
`default_nettype wire

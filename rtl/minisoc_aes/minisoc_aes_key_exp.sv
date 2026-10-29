`timescale 1ns/1ps
`default_nettype none

// AES-128 schedule: K0 captured at acceptance, K1..K10 one per cycle.
// Indexed reads permit both forward and reverse traversal of unmodified keys.
module minisoc_aes_key_exp (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start_i,
    input  logic [127:0] key_i,
    input  logic [3:0]   round_i,
    output logic [127:0] round_key_o,
    output logic         busy_o,
    output logic         done_o,
    output logic         valid_o
);
    import aes_transforms_pkg::*;

    logic [127:0] keys_q [0:10];
    logic [127:0] current_q, next_key;
    logic [3:0] index_q;
    logic [7:0] rcon_q;
    logic [31:0] substituted, w0, w1, w2, w3;

    // RotWord of the final word, SubWord, then the round constant.
    assign substituted = {aes_sbox(current_q[23:16]), aes_sbox(current_q[15:8]),
                          aes_sbox(current_q[7:0]), aes_sbox(current_q[31:24])};
    assign w0 = current_q[127:96] ^ substituted ^ {rcon_q, 24'h0};
    assign w1 = current_q[95:64] ^ w0;
    assign w2 = current_q[63:32] ^ w1;
    assign w3 = current_q[31:0] ^ w2;
    assign next_key = {w0, w1, w2, w3};

    // Unreset bank is inaccessible until all eleven keys have been written.
    // This is validity masking, not a claim of physical key zeroization.
    assign round_key_o = (valid_o && round_i <= 4'd10) ? keys_q[round_i] : 128'h0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_q <= 0;
            index_q <= 1;
            rcon_q <= 8'h01;
            busy_o <= 0;
            done_o <= 0;
            valid_o <= 0;
        end else begin
            done_o <= 0;
            if (busy_o) begin
                // start_i while busy has no effect, including the last edge.
                keys_q[index_q] <= next_key;
                current_q <= next_key;
                if (index_q == 4'd10) begin
                    busy_o <= 0;
                    done_o <= 1;
                    valid_o <= 1;
                end else begin
                    index_q <= index_q + 1'b1;
                    rcon_q <= xtime(rcon_q);
                end
            end else if (start_i) begin
                keys_q[0] <= key_i;
                current_q <= key_i;
                index_q <= 1;
                rcon_q <= 8'h01;
                busy_o <= 1;
                valid_o <= 0;
            end
        end
    end
endmodule

`default_nettype wire

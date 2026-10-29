`timescale 1ns/1ps
`default_nettype none

// Single-block primitive, internal helper for the future minisoc_aes_top engine.
// No modes, RAM, PLL, SPI or system-level status semantics are implemented here.
module minisoc_aes_core (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start_i,
    input  logic         decrypt_i,
    input  logic [127:0] key_i,
    input  logic [127:0] data_i,
    output logic         busy_o,
    output logic         done_o,
    output logic [127:0] data_o
);
    typedef enum logic [1:0] {IDLE, WAIT_KEYS, ROUND, FINAL_ROUND} phase_t;
    phase_t phase_q;
    logic [127:0] state_q, round_result, round_key;
    logic [3:0] round_q;
    logic decrypt_q, key_start, keys_busy, keys_done, keys_valid;

    assign busy_o = (phase_q != IDLE);
    assign key_start = start_i && !busy_o;

    minisoc_aes_key_exp key_exp (
        .clk(clk), .rst_n(rst_n), .start_i(key_start), .key_i(key_i),
        .round_i(round_q), .round_key_o(round_key),
        .busy_o(keys_busy), .done_o(keys_done), .valid_o(keys_valid)
    );

    minisoc_aes_dp datapath (
        .state_i(state_q), .round_key_i(round_key), .decrypt_i(decrypt_q),
        .initial_round_i(phase_q == WAIT_KEYS),
        .final_round_i(phase_q == FINAL_ROUND), .state_o(round_result)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_q <= IDLE;
            state_q <= 0;
            round_q <= 0;
            decrypt_q <= 0;
            data_o <= 0;
            done_o <= 0;
        end else begin
            done_o <= 0;
            case (phase_q)
                IDLE: if (start_i) begin
                    // Key expansion captures key_i on this same edge.
                    state_q <= data_i;
                    decrypt_q <= decrypt_i;
                    round_q <= decrypt_i ? 4'd10 : 4'd0;
                    phase_q <= WAIT_KEYS;
                end
                WAIT_KEYS: if (keys_done && keys_valid && !keys_busy) begin
                    state_q <= round_result; // Initial AddRoundKey.
                    round_q <= decrypt_q ? 4'd9 : 4'd1;
                    phase_q <= ROUND;
                end
                ROUND: begin
                    state_q <= round_result;
                    round_q <= decrypt_q ? round_q - 1'b1 : round_q + 1'b1;
                    if ((!decrypt_q && round_q == 4'd9) ||
                        (decrypt_q && round_q == 4'd1))
                        phase_q <= FINAL_ROUND;
                end
                FINAL_ROUND: begin
                    // Publish the NEW final result, never the preceding State.
                    state_q <= round_result;
                    data_o <= round_result;
                    done_o <= 1;
                    phase_q <= IDLE;
                end
                default: phase_q <= IDLE;
            endcase
        end
    end
endmodule

`default_nettype wire

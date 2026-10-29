`timescale 1ns/1ps
`default_nettype none

// One combinational round, reused by a future sequential AES controller.
// Standard INVCIPHER ordering: inverse keys are NOT pre-transformed.
module minisoc_aes_dp (
    input  logic [127:0] state_i,
    input  logic [127:0] round_key_i,
    input  logic         decrypt_i,
    input  logic         initial_round_i,
    input  logic         final_round_i,
    output logic [127:0] state_o
);
    import aes_transforms_pkg::*;

    logic [127:0] transformed;

    // Explicit combinational sensitivity also supports Icarus versions that
    // conservatively warn about constant selects inside always_comb functions.
    always @* begin
        transformed = state_i;
        if (initial_round_i) begin
            // K0 for CIPHER, K10 for INVCIPHER. Has priority over final.
            state_o = add_round_key(state_i, round_key_i);
        end else if (decrypt_i) begin
            transformed = inv_sub_bytes(inv_shift_rows(state_i));
            transformed = add_round_key(transformed, round_key_i);
            state_o = final_round_i ? transformed : inv_mix_columns(transformed);
        end else begin
            transformed = shift_rows(sub_bytes(state_i));
            if (!final_round_i)
                transformed = mix_columns(transformed);
            state_o = add_round_key(transformed, round_key_i);
        end
    end
endmodule

`default_nettype wire

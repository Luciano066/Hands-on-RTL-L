`timescale 1ns/1ps
`default_nettype none

// Forward AES ShiftRows: row r rotates left by r columns.
// Byte i = state[127-8*i -: 8]; s[row,col] = byte[row+4*col].
module minisoc_aes_shift_rows (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);
    assign state_o = aes_transforms_pkg::shift_rows(state_i);
endmodule

`default_nettype wire

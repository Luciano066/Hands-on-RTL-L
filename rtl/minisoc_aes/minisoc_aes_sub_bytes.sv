`timescale 1ns/1ps
`default_nettype none

// Forward AES SubBytes, applied independently to all sixteen bytes.
// Byte i = state[127-8*i -: 8]; byte 0 is state[127:120].
module minisoc_aes_sub_bytes (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);
    assign state_o = aes_transforms_pkg::sub_bytes(state_i);
endmodule

`default_nettype wire

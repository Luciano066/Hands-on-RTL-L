`timescale 1ns/1ps
`default_nettype none

// Forward AES S-box, FIPS 197 section 5.1.1. Pure combinational lookup.
module minisoc_aes_sbox (
    input  logic [7:0] byte_i,
    output logic [7:0] byte_o
);
    assign byte_o = aes_transforms_pkg::aes_sbox(byte_i);
endmodule

`default_nettype wire

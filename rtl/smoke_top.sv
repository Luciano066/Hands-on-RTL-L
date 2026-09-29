`timescale 1ns/1ps
`default_nettype none

// XOR combinacional: apenas um teste do ambiente, nao um bloco AES.
module smoke_top (
    input  logic a,
    input  logic b,
    output logic y
);
    assign y = a ^ b;
endmodule

`default_nettype wire

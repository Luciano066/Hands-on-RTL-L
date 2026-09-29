`timescale 1ns/1ps
`default_nettype none

module tb_smoke_top;
    logic a;
    logic b;
    logic y;

    smoke_top dut (
        .a(a),
        .b(b),
        .y(y)
    );

    task automatic check(input logic ta, input logic tb, input logic expected);
        begin
            a = ta;
            b = tb;
            // Aguarda a propagacao do assign antes de comparar a tabela-verdade.
            #1;
            if (y !== expected) begin
                $fatal(1, "FAIL: a=%0b b=%0b y=%0b expected=%0b", a, b, y, expected);
            end
        end
    endtask

    initial begin
        // Resultados explicitos e independentes da expressao usada no DUT.
        check(1'b0, 1'b0, 1'b0);
        check(1'b0, 1'b1, 1'b1);
        check(1'b1, 1'b0, 1'b1);
        check(1'b1, 1'b1, 1'b0);

        $display("SMOKE TEST PASS");
        $finish;
    end

    // Limite de tempo de simulacao para futuras alteracoes no testbench.
    initial begin
        #100;
        $fatal(1, "TIMEOUT: smoke test nao terminou em 100 ns");
    end
endmodule

`default_nettype wire

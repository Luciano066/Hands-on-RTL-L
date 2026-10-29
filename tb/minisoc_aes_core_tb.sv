`timescale 1ns/1ps
`default_nettype none

// Black-box tests: official KATs and local handshake/reset contract.
// Neither the datapath nor Key Expansion is used to compute expected values.
module minisoc_aes_core_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0, start_i = 0, decrypt_i = 0;
    logic [127:0] key_i = 0, data_i = 0;
    logic busy_o, done_o;
    logic [127:0] data_o;
    logic [127:0] plain [0:4];
    logic [127:0] cipher [0:4];
    logic [127:0] key_values [0:4];
    int checks = 0, completed = 0, cycle = 0;
    always @(posedge clk) cycle++;

    minisoc_aes_core dut (.*);

    task automatic check(input logic condition, input string label_text);
        if (condition !== 1'b1)
            $fatal(1, "CORE: cycle=%0d %s data=%032h", cycle, label_text, data_o);
        checks++;
    endtask

    task automatic tick;
        @(posedge clk); #1;
    endtask

    task automatic reset_now;
        @(negedge clk); #2;
        rst_n = 0; start_i = 0;
        #1;
        check({busy_o, done_o} === 2'b00, "asynchronous reset flags");
        check(data_o === 0, "reset clears published result");
        @(negedge clk); rst_n = 1;
    endtask

    task automatic launch(input int vector_index, input bit inverse_mode);
        logic [127:0] previous_result;
        previous_result = data_o;
        @(negedge clk);
        key_i = key_values[vector_index];
        data_i = inverse_mode ? cipher[vector_index] : plain[vector_index];
        decrypt_i = inverse_mode;
        start_i = 1;
        tick();
        check({busy_o, done_o} === 2'b10, "accepted only when idle; done cleared");
        check(data_o === previous_result, "acceptance retains prior result");
    endtask

    task automatic run_case(input int vector_index, input bit inverse_mode);
        logic [127:0] previous_result, expected_result;
        int accepted_cycle;
        previous_result = data_o;
        expected_result = inverse_mode ? plain[vector_index] : cipher[vector_index];
        launch(vector_index, inverse_mode);
        accepted_cycle = cycle;
        for (int n = 1; n <= 21; n++) begin
            @(negedge clk);
            // Inputs and direction are deliberately changed after capture.
            key_i = ~key_values[vector_index];
            data_i = 128'h0123456789abcdef0123456789abcdef ^ 128'(n);
            decrypt_i = !inverse_mode;
            start_i = (n == 1 || n == 10 || n == 11 || n == 12 || n == 20 || n == 21);
            tick();
            if (n < 21) begin
                check({busy_o, done_o} === 2'b10, "BUSY/no early DONE");
                check(data_o === previous_result, "output stable during operation");
            end else begin
                check({busy_o, done_o} === 2'b01, "publication at E21");
                check(data_o === expected_result, "official encrypt/decrypt KAT");
                check(cycle-accepted_cycle == 21, "exact latency in cycles");
            end
        end
        completed++;
    endtask

    task automatic idle_check(input int cycles_to_check);
        logic [127:0] held_result;
        held_result = data_o;
        repeat (cycles_to_check) begin
            @(negedge clk); start_i = 0; key_i = ~key_i; data_i = ~data_i;
            tick();
            check({busy_o, done_o} === 0, "done pulse; no queued busy START");
            check(data_o === held_result, "stable result until completion/reset");
        end
    endtask

    initial begin
        // NIST AES_Core128.pdf: four distinct blocks with the A.1 key.
        plain[0] = 128'h6bc1bee22e409f96e93d7e117393172a;
        plain[1] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        plain[2] = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
        plain[3] = 128'hf69f2445df4f9b17ad2b417be66c3710;
        cipher[0] = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
        cipher[1] = 128'hf5d3d58503b9699de785895a96fdbaaf;
        cipher[2] = 128'h43b1cd7f598ece23881b00e3ed030688;
        cipher[3] = 128'h7b0c785e27e8ad3f8223207104725dd4;
        for (int n = 0; n < 4; n++) key_values[n] = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        // FIPS 197 (2001) Appendix C.1, different key and byte-distinct input.
        key_values[4] = 128'h000102030405060708090a0b0c0d0e0f;
        plain[4] = 128'h00112233445566778899aabbccddeeff;
        cipher[4] = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

        reset_now();
        // Consecutive operations: next acceptance on the first idle edge E22.
        for (int n = 0; n < 5; n++) begin
            run_case(n, 0);
            run_case(n, 1);
        end
        idle_check(24);

        // Sweep reset after acceptance, every expansion step, initial ARK,
        // and each intermediate round in BOTH directions. No hierarchical peeks.
        for (int direction = 0; direction < 2; direction++)
            for (int cut = 0; cut < 21; cut++) begin
                launch(0, 1'(direction));
                for (int n = 1; n <= cut; n++) begin
                    @(negedge clk); start_i = 0; key_i = 0; data_i = 0;
                    tick();
                    check({busy_o, done_o} === 2'b10, "operation pending before abort");
                end
                reset_now();
                idle_check(24); // More than the full latency: no ghost result.
                run_case(4, 1'(direction)); // Recovery with a different key.
                idle_check(1);
            end
        reset_now(); // Also clear a previously completed/published result.
        idle_check(24);
        $display("AES SEQUENTIAL CORE TEST PASS: %0d checks, %0d completed KATs, 42 reset cuts, latency=21 cycles", checks, completed);
        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "TIMEOUT: sequential AES core");
    end
endmodule

`default_nettype wire

`timescale 1ns/1ps
`default_nettype none

// Independent oracle: static official keys, no DUT functions or recurrence.
module minisoc_aes_key_exp_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst_n = 0, start_i = 0;
    logic [127:0] key_i = 0;
    logic [3:0] round_i = 0;
    logic [127:0] round_key_o;
    logic busy_o, done_o, valid_o;
    logic [127:0] reference_a [0:10];
    logic [127:0] reference_b [0:10];
    int checks = 0;

    minisoc_aes_key_exp dut (.*);

    task automatic check(input logic condition, input string label_text);
        if (condition !== 1'b1) $fatal(1, "KEY: %s", label_text);
        checks++;
    endtask

    task automatic tick;
        @(posedge clk); #1;
    endtask

    task automatic reset_now;
        @(negedge clk); #2;
        rst_n = 0; start_i = 0;
        #1;
        check({busy_o, done_o, valid_o} === 3'b000, "asynchronous reset flags");
        check(round_key_o === 128'h0, "reset hides every old key");
        @(negedge clk); rst_n = 1;
    endtask

    task automatic launch(input logic [127:0] new_key);
        @(negedge clk); key_i = new_key; start_i = 1;
        tick();
        check({busy_o, done_o, valid_o} === 3'b100, "acceptance flags");
        check(round_key_o === 128'h0, "no partial schedule exposed");
    endtask

    task automatic run_schedule(input bit dataset_b);
        launch(dataset_b ? reference_b[0] : reference_a[0]);
        for (int n = 1; n <= 10; n++) begin
            @(negedge clk);
            key_i = 128'hfeedface00000000123456789abcdef0 ^ 128'(n);
            start_i = (n == 3 || n == 10); // Including completion while BUSY.
            round_i = 4'(n);
            tick();
            if (n < 10) begin
                check({busy_o, done_o, valid_o} === 3'b100, "ten-cycle expansion");
                check(round_key_o === 0, "partial schedule masked");
            end else begin
                check({busy_o, done_o, valid_o} === 3'b011, "valid and done after E10");
                check(round_key_o === (dataset_b ? reference_b[10] : reference_a[10]), "K10");
            end
        end
        @(negedge clk); start_i = 0;
        tick();
        check({busy_o, done_o, valid_o} === 3'b001, "done pulse, retained validity");
        for (int n = 0; n <= 10; n++) begin
            round_i = 4'(n); #1;
            check(round_key_o === (dataset_b ? reference_b[n] : reference_a[n]), "K0..K10 official");
        end
        for (int n = 10; n >= 0; n--) begin
            round_i = 4'(n); #1;
            check(round_key_o === (dataset_b ? reference_b[n] : reference_a[n]), "K10..K0 official");
        end
        for (int n = 11; n < 16; n++) begin
            round_i = 4'(n); #1;
            check(round_key_o === 0, "invalid index has no alias");
        end
        // A pulse on E10 must not cause a queued expansion later.
        repeat (12) begin
            tick();
            check({busy_o, done_o, valid_o} === 3'b001, "no queued START");
        end
    endtask

    initial begin
        $readmemh("tb/vectors/aes128_round_keys_a.mem", reference_a);
        $readmemh("tb/vectors/aes128_round_keys_b.mem", reference_b);
        for (int n = 0; n <= 10; n++) begin
            check((^reference_a[n]) !== 1'bx, "fixture A loaded");
            check((^reference_b[n]) !== 1'bx, "fixture B loaded");
        end
        reset_now();
        run_schedule(0);
        run_schedule(1); // New key must replace the previous complete bank.
        for (int cut = 0; cut < 10; cut++) begin
            launch(reference_a[0]);
            for (int n = 1; n <= cut; n++) begin
                @(negedge clk); start_i = 0;
                tick();
                check(busy_o === 1, "busy before reset");
            end
            reset_now();
            repeat (12) begin
                tick();
                check({busy_o, done_o, valid_o} === 3'b000, "no completion after abort");
                check(round_key_o === 0, "aborted bank remains inaccessible");
            end
        end
        run_schedule(1);
        $display("AES KEY EXPANSION TEST PASS: %0d checks, 22 official keys, forward/reverse, latency=10 cycles", checks);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "TIMEOUT: key expansion");
    end
endmodule

`default_nettype wire

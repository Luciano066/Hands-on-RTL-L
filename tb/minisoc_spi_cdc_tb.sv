`timescale 1ns/1ps
`default_nettype none

// Independent transaction queues, no hierarchical DUT references or AES mock.
module minisoc_spi_cdc_tb;
    logic clk=0, sys_clk=0, run_clk=1, run_sys=1;
    int sys_half=7;
    always #5 if(run_clk) clk=~clk; else clk=0;
    always begin #(sys_half); if(run_sys) sys_clk=~sys_clk; else sys_clk=0; end
    logic rst_n=0;
    logic cfg_valid_i=0, cfg_ready_i=1, status_valid_i=0, status_ready_i=1;
    logic [355:0] cfg_i=0;
    logic [11:0] status_i=0;
    wire cfg_ready_o, cfg_valid_o, status_ready_o, status_valid_o;
    wire [355:0] cfg_o;
    wire [11:0] status_o;
    logic [355:0] cfg_queue [0:255];
    logic [11:0] status_queue [0:255];
    int cfg_put=0,cfg_get=0,status_put=0,status_get=0,checks=0;
    logic cfg_stalled=0, status_stalled=0;
    logic [355:0] cfg_previous;
    logic [11:0] status_previous;
    logic [31:0] rng=32'h5926abcd;
    minisoc_aes_cdc dut (.*);
    task automatic check(input logic ok,input string label_text);
        if(ok !== 1'b1) $fatal(1,"CDC t=%0t %s",$time,label_text);
        checks++;
    endtask
    always @(posedge sys_clk) begin
        if(rst_n) begin
            if(cfg_stalled) check(cfg_valid_o && cfg_o===cfg_previous,"cfg stable while stalled");
            cfg_stalled=cfg_valid_o && !cfg_ready_i;
            cfg_previous=cfg_o;
            if(cfg_valid_o && cfg_ready_i) begin
                check(cfg_get<cfg_put,"no unsolicited/duplicate config");
                check(cfg_o===cfg_queue[cfg_get],"config queue coherent/in order");
                cfg_get++;
            end
        end else cfg_stalled=0;
    end
    always @(posedge clk) begin
        if(rst_n) begin
            if(status_stalled) check(status_valid_o && status_o===status_previous,"status stable while stalled");
            status_stalled=status_valid_o && !status_ready_i;
            status_previous=status_o;
            if(status_valid_o && status_ready_i) begin
                check(status_get<status_put,"no unsolicited/duplicate status");
                check(status_o===status_queue[status_get],"all status fields captured atomically");
                status_get++;
            end
        end else status_stalled=0;
    end
    task automatic reset_both;
        rst_n=0; cfg_valid_i=0; status_valid_i=0;
        cfg_stalled=0; status_stalled=0;
        #21;
        cfg_put=0;cfg_get=0;status_put=0;status_get=0;
        rst_n=1; #100;
    endtask
    task automatic push_cfg(input logic [355:0] value);
        @(negedge clk);
        while(!cfg_ready_o) @(negedge clk);
        cfg_queue[cfg_put]=value;cfg_put++;
        cfg_i=value;cfg_valid_i=1;
        @(negedge clk); cfg_valid_i=0;cfg_i=~value;
    endtask
    task automatic push_status(input logic [11:0] value);
        @(negedge sys_clk);
        while(!status_ready_o) @(negedge sys_clk);
        status_queue[status_put]=value;status_put++;
        status_i=value;status_valid_i=1;
        @(negedge sys_clk); status_valid_i=0;status_i=~value;
    endtask
    task automatic drain;
        wait(cfg_get==cfg_put && status_get==status_put);
        #200;
        check(cfg_ready_o && status_ready_o,"ack returned after consumption");
    endtask
    initial begin #2000000; $fatal(1,"CDC timeout"); end
    initial begin
        logic [355:0] v;
        reset_both();
        cfg_ready_i=0;
        push_cfg({4'h1,{11{32'h23456789}}});
        wait(cfg_valid_o); #200;
        check(!cfg_ready_o,"no second config event while slot occupied");
        cfg_ready_i=1; drain();

        // sys_clk can stop before capture. Producer retains entire bundle.
        @(negedge sys_clk); run_sys=0;
        push_cfg({356{1'b1}}); #500;
        check(cfg_get==1 && !cfg_ready_o,"paused AES domain cannot lose pending request");
        run_sys=1; drain();

        status_ready_i=0; push_status(12'hab6);
        wait(status_valid_o); #100;
        check(!status_ready_o,"status backpressure reaches source");
        // Consume coherent held status while source clock is stopped.
        @(negedge sys_clk); run_sys=0;
        status_ready_i=1; #200;
        check(status_get==status_put,"status delivered with source stopped");
        check(!status_ready_o,"ack needs source clocks");
        run_sys=1; drain();

        // Destination clk paused for status; both source and phase independent.
        @(negedge clk); run_clk=0;
        push_status(12'h802); #400;
        check(!status_ready_o,"clk pause holds status mailbox busy");
        run_clk=1; drain();

        // Both directions simultaneously; changing frequency and arbitrary data.
        fork
            begin
                for(int n=0;n<100;n++) begin
                    for(int lane=0;lane<11;lane++) begin
                        rng=(rng<<1) ^ (rng[31] ? 32'h04c11db7 : 32'b0);
                        v[lane*32 +:32]=rng;
                    end
                    v[355:352]=4'(n);
                    push_cfg(v);
                    #((n%9)*3+1);
                end
            end
            begin
                for(int n=0;n<100;n++) begin
                    push_status(12'((n*613)^12'h5a6));
                    #((n%7)*11+3);
                end
            end
            begin
                repeat(20) begin #137; sys_half=(sys_half==7)?3:((sys_half==3)?11:7); end
            end
        join
        drain();
        check(cfg_get==102 && status_get==102,"102 complete snapshots in each direction");

        // Coordinated reset during every synchronization/guard/valid phase.
        // Releases happen with a stopped domain as well as with running clocks.
        for(int cut=0;cut<9;cut++) begin
            cfg_ready_i=0;status_ready_i=0;
            fork
                push_cfg(356'(cut+1));
                push_status(12'(cut+1));
            join
            repeat(cut) @(negedge clk);
            reset_both();
            check(!cfg_valid_o && !status_valid_o,"reset removes pending/in-flight snapshots");
            cfg_ready_i=1;status_ready_i=1;
            push_cfg(356'(cut+91));push_status(12'(cut+103));drain();
        end
        @(negedge sys_clk); run_sys=0;
        push_cfg(356'hfeed);
        reset_both();
        check(!cfg_valid_o,"stopped sys_clk remains safely reset");
        run_sys=1; #200;
        check(cfg_get==0,"no phantom config after reset release");
        push_cfg(356'hbeef);push_status(12'h802);drain();
        $display("SPI CDC TEST PASS: %0d checks; bidirectional queues, backpressure, paused clocks, 9 reset phases",checks);
        $finish;
    end
endmodule
`default_nettype wire

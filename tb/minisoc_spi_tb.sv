`timescale 1ns/1ps
`default_nettype none

// Black-box register scoreboard. D21..D24 expectations are explicitly LOCAL,
// not an oracle for unresolved P14/P21/P22/P24/P25 official requirements.
module minisoc_spi_tb;
    logic clk=0, run_clk=1;
    always #5 if (run_clk) clk=~clk; else clk=0;
    logic rst_n=0, spi_sclk=0, spi_cs_n=1, spi_mosi=0;
    wire spi_miso;
    logic cfg_ready_i=1, status_valid_i=0, pll_locked_i=0;
    logic [11:0] status_i=0;
    wire cfg_valid_o, overrun_o, command_reject_o;
    wire [355:0] cfg_o;
    wire mem_sel_aes_o, pll_enable_o;
    wire [1:0] pll_div_sel_o;
    logic [31:0] model [0:15];
    logic [39:0] sampled;
    logic [355:0] last_cfg, frozen;
    int checks=0, launches=0, rejects=0, frames=0;
    int before_launch, before_reject;
    minisoc_spi dut (.*);

    always @(posedge clk) begin
        if (cfg_valid_o && cfg_ready_i) begin launches++; last_cfg=cfg_o; end
        if (command_reject_o) rejects++;
        if ($test$plusargs("trace") && dut.frame_valid)
            $display("RX %010h pending=%b response=%08h",dut.frame,dut.response_pending_q,dut.response_q);
    end
    always @(negedge spi_sclk)
        if ($test$plusargs("trace")) begin
            if(dut.bit_count==8)
                $display("TX header=%02h pending_sync=%b data=%08h",dut.header,dut.response_sync_q,dut.response_q);
            if(dut.bit_count==40)
                $display("FULL req=%b ack=%b hold=%010h phase=%d rst=%b",dut.rx.req_q,dut.rx.ack_sync_q,dut.rx.hold_q,dut.rx.phase_q,dut.clk_rst_n);
        end
    task automatic check(input logic ok, input string label_text);
        if (ok !== 1'b1) $fatal(1,"SPI t=%0t %s",$time,label_text);
        checks++;
    endtask
    task automatic bit_io(input logic value, input int half_ns, output logic received);
        logic previous_miso;
        spi_mosi=value;
        #(half_ns-1); previous_miso=spi_miso; spi_sclk=1;
        #1; received=spi_miso;
        check(spi_miso === previous_miso,"Mode 0: no MISO change on rising edge");
        #(half_ns-1); spi_sclk=0;
        #1;
    endtask
    task automatic send(input logic [39:0] frame, input int nbits,
                        input int half_ns, input int gap_ns, output logic [39:0] received);
        logic b;
        received=0;
        spi_cs_n=0; #3;
        for(int i=0;i<nbits;i++) begin
            bit_io(i<40 ? frame[39-i] : 1'b1,half_ns,b);
            received={received[38:0],b};
        end
        #3; spi_cs_n=1; spi_mosi=0;
        #(gap_ns); frames++;
    endtask
    task automatic write_reg(input logic [5:0] a, input logic [31:0] d);
        send({1'b0,a,1'b0,d},40,20,150,sampled);
    endtask
    task automatic read_check(input logic [5:0] a, input logic [31:0] expected);
        send({1'b1,a,1'b0,32'b0},40,23,150,sampled);
        send(40'h7e00000000,40,20,150,sampled);
        if(sampled !== {8'b0,expected})
            $fatal(1,"read a=%02h expected=%08h got=%010h",a,expected,sampled);
        checks++;
    endtask
    task automatic prime_serial;
        logic b;
        spi_cs_n=1;
        repeat(2) bit_io(0,20,b);
        #150;
    endtask
    task automatic reset_all;
        spi_cs_n=1; spi_sclk=0; rst_n=1; #1; rst_n=0; status_valid_i=0;
        cfg_ready_i=1; run_clk=1;
        #31; rst_n=1;
        prime_serial();
        for(int i=0;i<16;i++) model[i]=0;
        model[14]=2;
    endtask
    task automatic complete_op(input logic [8:0] blocks, input bit error_bit);
        @(negedge clk); status_i={blocks,error_bit,1'b1,1'b0}; status_valid_i=1;
        @(negedge clk); status_valid_i=0;
        repeat(3) @(negedge clk);
    endtask
    task automatic check_launch(input logic [2:0] mode_value, input bit decrypt_value);
        logic [355:0] expected_cfg;
        before_launch=launches;
        write_reg(11,{27'b0,mode_value,decrypt_value,1'b1});
        expected_cfg={model[0],model[1],model[2],model[3],model[4],model[5],
                      model[6],model[7],model[8],model[9],model[10],mode_value,decrypt_value};
        check(launches==before_launch+1,"one config handshake per accepted START");
        check(last_cfg === expected_cfg,"atomic KEY/IV/COUNTER/N/MODE/DECRYPT snapshot");
        read_check(12,1);
        complete_op(9'(model[10]),0);
        read_check(12,(model[10]<<3)|2);
        read_check(12,(model[10]<<3)|2);
    endtask

    initial begin
        #20000000; $fatal(1,"SPI global timeout");
    end
    initial begin
        reset_all();
        check({mem_sel_aes_o,pll_enable_o,pll_div_sel_o}===4'b0100,"D24 reset PLL bootstrap");
        // Every R/W word, distinctive MSB/LSB/word ordering.
        for(int a=0;a<11;a++) begin
            model[a]=32'h81234567 ^ (32'h1020305 * 32'(a));
            write_reg(6'(a),model[a]);
        end
        for(int a=0;a<11;a++) read_check(6'(a),model[a]);
        write_reg(11,32'hfffffffe); read_check(11,30);
        write_reg(14,32'hffffffff); read_check(14,15);
        check({pll_div_sel_o,pll_enable_o,mem_sel_aes_o}===4'hf,"SYSTEM_CONTROL outputs");
        pll_locked_i=1; read_check(15,1); pll_locked_i=0;
        read_check(13,0); read_check(12,0);

        // D24 malformed/RO writes produce only a local reject, no register write.
        before_reject=rejects;
        write_reg(12,32'hffffffff); write_reg(13,32'hffffffff); write_reg(15,32'hffffffff);
        write_reg(16,32'habcd); send({1'b0,6'h00,1'b1,32'habcd},40,20,150,sampled);
        send({1'b1,6'h30,1'b0,32'b0},40,20,150,sampled);
        check(rejects==before_reject+6,"RO/invalid address/RSV rejection");
        read_check(0,model[0]); read_check(12,0); read_check(13,0); read_check(15,0);

        // Exhaust every shorter frame length; partial commands never commit.
        for(int n=0;n<40;n++) begin
            send({1'b0,6'h00,1'b0,32'hdeadbeef},n,20,150,sampled);
            read_check(0,model[0]);
        end
        for(int n=41;n<=48;n++) begin
            send({1'b0,6'h00,1'b0,32'hbad0cafe},n,20,150,sampled);
            read_check(0,model[0]);
        end

        // Consecutive frames at declared 12-clk high minimum (120ns).
        for(int n=0;n<24;n++) begin
            model[n%11]=32'h01020304 ^ (32'habcdef * 32'(n+1));
            send({1'b0,6'(n%11),1'b0,model[n%11]},40,20+(n%13),120,sampled);
        end
        for(int a=0;a<11;a++) read_check(6'(a),model[a]);

        // Read snapshots survive intervening writes, aborted/long NOPs and a
        // second pending read. These are provisional P14 semantics.
        send({1'b1,6'h00,1'b0,32'b0},40,20,150,sampled);
        write_reg(0,~model[0]);
        send({1'b1,6'h01,1'b0,32'b0},40,20,150,sampled);
        send(40'h7e00000000,18,20,150,sampled);
        send(40'h7e00000000,44,20,150,sampled);
        send(40'h7e00000000,40,20,150,sampled);
        check(sampled==={8'b0,model[0]},"read held until COMPLETE valid NOP; no overwrite");
        model[0]=~model[0]; read_check(0,model[0]);
        send(40'h7e00000000,40,20,150,sampled);
        check(sampled===0,"D22 no pending response -> dummy zero");

        // Pause SCLK halfway through frame; clk alone cannot commit it.
        begin
            logic b;
            logic [39:0] f;
            f={1'b0,6'h00,1'b0,32'h12345678};
            spi_cs_n=0; #3;
            for(int i=39;i>=0;i--) begin
                bit_io(f[i],20,b);
                if(i==20) begin #1000; end
            end
            spi_cs_n=1; #150;
            model[0]=32'h12345678; read_check(0,model[0]);
        end

        // Stop the receiver clk: only one retained command, second dropped.
        @(negedge clk); run_clk=0;
        send({1'b0,6'h00,1'b0,32'hac012345},40,20,150,sampled);
        send({1'b0,6'h01,1'b0,32'hbad12345},40,20,150,sampled);
        run_clk=1; #300;
        check(overrun_o===1,"slot occupied -> sticky overrun, no second toggle");
        model[0]=32'hac012345;
        read_check(0,model[0]); read_check(1,model[1]);
        write_reg(1,32'hff00ff00); model[1]=32'hff00ff00; read_check(1,model[1]);

        // Full 32-bit validation: zero, 1, 256, 257, and aliases of 1.
        write_reg(10,0); model[10]=0; before_launch=launches;
        write_reg(11,1); check(launches==before_launch,"N=0 rejected"); read_check(12,4);
        write_reg(10,32'h00010001); read_check(10,32'h00010001);
        write_reg(11,1); check(launches==before_launch,"N high bits preserved, no alias to 1");
        write_reg(10,513); write_reg(11,1); check(launches==before_launch,"N=513 no 9-bit alias");
        write_reg(10,257); write_reg(11,1); check(launches==before_launch,"N=257 rejected");
        write_reg(10,1); model[10]=1;
        for(int m=0;m<6;m++) check_launch(3'(m),1'(m%2));
        write_reg(10,256); model[10]=256; check_launch(5,1);
        before_launch=launches;
        write_reg(11,25); write_reg(11,29);
        check(launches==before_launch,"modes 110/111 invalid");
        read_check(12,(256<<3)|6); // Prior DONE retained on invalid START.

        // Snapshot remains stable under downstream backpressure/config writes.
        cfg_ready_i=0; write_reg(10,1); model[10]=1;
        write_reg(11,1); frozen=cfg_o;
        check(cfg_valid_o===1,"config request retained with stopped consumer");
        write_reg(0,32'h99887766); model[0]=32'h99887766;
        write_reg(11,3); write_reg(11,3);
        check(cfg_valid_o && cfg_o===frozen,"no snapshot overwrite or duplicate occupied START");
        read_check(11,2); // START always reads zero (D24).
        before_launch=launches;
        @(negedge clk); cfg_ready_i=1;
        #150; check(launches==before_launch+1,"one downstream consumption");
        complete_op(1,0); read_check(12,10);
        // Repeated identical accepted commands are DISTINCT host commands.
        before_launch=launches;
        write_reg(11,1); complete_op(1,1); read_check(12,14);
        write_reg(11,1); complete_op(1,0);
        check(launches==before_launch+2,"identical frames each execute once when idle");
        read_check(12,10);

        // Progress/status is a synchronous snapshot interface, no AES engine.
        write_reg(10,256); write_reg(11,1);
        @(negedge clk); status_i={9'd127,3'b001}; status_valid_i=1;
        @(negedge clk); status_valid_i=0;
        read_check(12,(127<<3)|1);
        // A START arriving on the same clk edge as completion is rejected;
        // completion has priority (provisional P25 policy).
        before_launch=launches; before_reject=rejects;
        fork
            write_reg(11,1);
            begin
                wait(dut.frame_valid===1'b1);
                @(negedge clk); status_i={9'd256,3'b010}; status_valid_i=1;
                @(negedge clk); status_valid_i=0;
            end
        join
        check(launches==before_launch && rejects==before_reject+1,"completion wins simultaneous START");
        read_check(12,(256<<3)|2);
        @(negedge clk); status_i=12'hfff; status_valid_i=1;
        @(negedge clk); status_valid_i=0;
        read_check(12,(256<<3)|2); // Ignore unsolicited idle status (D24).

        // Reset at EVERY receive bit and after a complete pending frame,
        // with both clk and SCLK stopped. No phantom writes/START after reset.
        for(int cut=0;cut<=40;cut++) begin
            logic b;
            logic [39:0] f;
            f={1'b0,6'h00,1'b0,32'hdeadbeef};
            @(negedge clk); run_clk=0;
            spi_cs_n=0; #3;
            for(int i=0;i<cut;i++) bit_io(f[39-i],20,b);
            rst_n=0; #13; spi_cs_n=1;
            rst_n=1; #150;
            check(cfg_valid_o===0,"async reset with clocks stopped cancels config");
            run_clk=1; prime_serial();
            read_check(0,0);
            write_reg(0,32'h55aa00ff); read_check(0,32'h55aa00ff);
        end
        // Reset in each clk-side req synchronization/guard/CS qualification phase.
        for(int cut=0;cut<9;cut++) begin
            @(negedge clk); run_clk=0;
            send({1'b0,6'h00,1'b0,32'hbeefbeef},40,20,0,sampled);
            run_clk=1;
            repeat(cut) @(negedge clk);
            reset_all(); read_check(0,0);
        end
        for(int cut=1;cut<=40;cut+=19) begin
            logic b;
            spi_cs_n=0; #3;
            repeat(cut-1) bit_io(1,20,b);
            spi_mosi=1; #20; spi_sclk=1; #5;
            rst_n=0; #1;
            check(spi_miso===0,"reset clears MISO during SCLK high");
            spi_cs_n=1; spi_sclk=0; #11; rst_n=1; prime_serial();
            read_check(0,0);
        end
        // Reset clears an unconsumed config and pending MISO response.
        cfg_ready_i=0; write_reg(10,1); write_reg(11,1);
        send({1'b1,6'h00,1'b0,32'b0},40,20,150,sampled);
        reset_all();
        send(40'h7e00000000,40,20,150,sampled); check(sampled===0,"reset cancels response");
        read_check(12,0);
        $display("SPI TEST PASS: %0d checks, %0d frames, %0d config consumptions; D21-D24 provisional",checks,frames,launches);
        $finish;
    end
endmodule
`default_nettype wire

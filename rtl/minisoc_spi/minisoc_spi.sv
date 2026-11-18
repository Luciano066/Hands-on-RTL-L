`timescale 1ns/1ps
`default_nettype none

// Week 5 internal peripheral. D21..D24 are PROVISIONAL; see spi_semana_05.md.
// No payload RAM, AES modes, PLL or top-level system is emulated here.
module minisoc_spi #(
    parameter logic [31:0] VERSION_VALUE = 32'h00000000 // P24 placeholder
) (
    input wire clk, input wire rst_n,
    input wire spi_sclk, input wire spi_cs_n, input wire spi_mosi,
    output wire spi_miso,
    output logic cfg_valid_o, input wire cfg_ready_i,
    // Atomic snapshot: {KEY, IV, COUNTER, NUM_BLOCKS, MODE, DECRYPT}.
    output logic [355:0] cfg_o,
    input wire status_valid_i, input wire [11:0] status_i,
    input wire pll_locked_i, // Must already be synchronous to clk.
    output wire mem_sel_aes_o, output wire pll_enable_o,
    output wire [1:0] pll_div_sel_o,
    output wire overrun_o, output logic command_reject_o
);
    wire clk_rst_n, spi_rst_n;
    wire [39:0] frame;
    wire frame_valid, frame_reject;
    wire [5:0] bit_count;
    wire [7:0] header;
    logic [31:0] words_q [0:10];
    logic [3:0] aes_control_q, system_control_q;
    logic [11:0] status_q;
    logic [31:0] response_q;
    logic response_pending_q;
    (* ASYNC_REG = "TRUE" *) logic [2:0] response_sync_q;
    logic [31:0] tx_q;
    logic miso_q;
    wire frame_rst_n = spi_rst_n && !spi_cs_n;
    wire [5:0] addr = frame[38:33];
    wire [31:0] wdata = frame[31:0];
    logic [31:0] rdata;
    logic addr_valid;

    minisoc_reset_sync ctrl_reset (.clk(clk), .arst_n(rst_n), .rst_n(clk_rst_n));
    minisoc_reset_sync serial_reset (.clk(spi_sclk), .arst_n(rst_n), .rst_n(spi_rst_n));
    minisoc_spi_rx rx (
        .clk(clk), .clk_rst_n(clk_rst_n), .spi_sclk(spi_sclk), .spi_rst_n(spi_rst_n),
        .spi_cs_n(spi_cs_n), .spi_mosi(spi_mosi), .frame_o(frame),
        .frame_valid_o(frame_valid), .frame_reject_o(frame_reject),
        .overrun_o(overrun_o), .bit_count_o(bit_count), .header_o(header)
    );
    assign mem_sel_aes_o = system_control_q[0];
    assign pll_enable_o = system_control_q[1];
    assign pll_div_sel_o = system_control_q[3:2];

    // D22 return format: {8'h00, DATA}. The eight header clocks let the
    // persistent response event synchronize even when SCLK was stopped.
    // A complete valid NOP in clk is the response acknowledgement. Aborted
    // or long NOPs never consume it. A second read while pending is rejected.
    always_ff @(posedge spi_sclk or negedge spi_rst_n) begin
        if (!spi_rst_n) response_sync_q <= 0;
        else response_sync_q <= {response_sync_q[1:0], response_pending_q};
    end
    always_ff @(negedge spi_sclk or negedge frame_rst_n) begin
        if (!frame_rst_n) begin tx_q <= 0; miso_q <= 0; end
        else if (bit_count == 6'd8) begin
            if (header == 8'h7e && response_sync_q[2]) begin
                tx_q <= {response_q[30:0], 1'b0};
                miso_q <= response_q[31];
            end else begin tx_q <= 0; miso_q <= 0; end
        end else if (bit_count > 6'd8 && bit_count < 6'd40) begin
            miso_q <= tx_q[31];
            tx_q <= {tx_q[30:0], 1'b0};
        end else miso_q <= 0;
    end
    assign spi_miso = spi_cs_n ? 1'b0 : miso_q;

    assign addr_valid = (addr <= 6'h0f || addr == 6'h3f);
    assign rdata = addr <= 6'h0a ? words_q[addr[3:0]] :
                   addr == 6'h0b ? {27'b0, aes_control_q, 1'b0} :
                   addr == 6'h0c ? {20'b0, status_q} :
                   addr == 6'h0d ? VERSION_VALUE :
                   addr == 6'h0e ? {28'b0, system_control_q} :
                   addr == 6'h0f ? {31'b0, pll_locked_i} : 32'b0;

    always_ff @(posedge clk or negedge clk_rst_n) begin
        if (!clk_rst_n) begin
            for (integer i=0; i<11; i=i+1) words_q[i] <= 0;
            aes_control_q <= 0;
            system_control_q <= 4'b0010; // D24: PLL bootstrap independent of SCLK.
            status_q <= 0; response_q <= 0; response_pending_q <= 0;
            cfg_o <= 0; cfg_valid_o <= 0; command_reject_o <= 0;
        end else begin
            command_reject_o <= frame_reject;
            if (cfg_valid_o && cfg_ready_i) cfg_valid_o <= 0;
            // D24: status published only while an accepted operation is busy.
            // DONE/ERROR sticky; completion wins over a simultaneous START.
            if (status_valid_i && status_q[0]) begin
                status_q[11:3] <= status_i[11:3];
                status_q[0] <= status_i[0] && !status_i[1] && !status_i[2];
                status_q[1] <= status_q[1] | status_i[1];
                status_q[2] <= status_q[2] | status_i[2];
            end
            if (frame_valid) begin
                if (frame[32] || !addr_valid) command_reject_o <= 1;
                else if (addr == 6'h3f) begin
                    // Only write-form NOP is the provisional read ACK.
                    if (!frame[39]) response_pending_q <= 0;
                    else command_reject_o <= 1;
                end else if (frame[39]) begin
                    if (response_pending_q) command_reject_o <= 1;
                    else begin response_q <= rdata; response_pending_q <= 1; end
                end else begin
                    case (addr)
                        6'h00,6'h01,6'h02,6'h03,6'h04,6'h05,6'h06,6'h07,6'h08,6'h09,6'h0a:
                            words_q[addr[3:0]] <= wdata;
                        6'h0b: begin
                            aes_control_q <= wdata[4:1];
                            if (wdata[0]) begin
                                if (status_q[0] || cfg_valid_o || status_valid_i)
                                    command_reject_o <= 1;
                                else if (wdata[4:2] > 3'd5 || words_q[10] == 0 || words_q[10] > 32'd256)
                                    status_q[2] <= 1;
                                else begin
                                    cfg_o <= {words_q[0],words_q[1],words_q[2],words_q[3],
                                              words_q[4],words_q[5],words_q[6],words_q[7],
                                              words_q[8],words_q[9],words_q[10],wdata[4:1]};
                                    cfg_valid_o <= 1;
                                    status_q <= 12'b001; // BUSY, clear sticky flags/count.
                                end
                            end
                        end
                        6'h0e: system_control_q <= wdata[3:0];
                        default: command_reject_o <= 1; // Read-only.
                    endcase
                end
            end
        end
    end
endmodule
`default_nettype wire

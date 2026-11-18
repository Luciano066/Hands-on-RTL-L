`timescale 1ns/1ps
`default_nettype none

// D21/D22: publish a candidate at bit 40; defer its acceptance until CS high
// is observed and qualified in clk. This allows rejecting 41+ bit frames.
// CS high must span >=12 running clk cycles (provisional host contract).
// No slot overwrite: a complete frame while occupied is dropped, sticky
// overrun records that condition. There is no external ready pin or FIFO.
module minisoc_spi_rx (
    input wire clk, input wire clk_rst_n,
    input wire spi_sclk, input wire spi_rst_n,
    input wire spi_cs_n, input wire spi_mosi,
    output logic [39:0] frame_o, output logic frame_valid_o,
    output logic frame_reject_o, output wire overrun_o,
    output wire [5:0] bit_count_o, output wire [7:0] header_o
);
    logic [38:0] shift_q;
    logic [39:0] hold_q;
    logic [5:0] count_q;
    logic req_q, ack_q, accepted_q, long_q, overrun_q;
    (* ASYNC_REG = "TRUE" *) logic [1:0] ack_sync_q, req_sync_q;
    (* ASYNC_REG = "TRUE" *) logic [1:0] cs_sync_q, overrun_sync_q;
    typedef enum logic [1:0] {IDLE, GUARD, WAIT_END} phase_t;
    phase_t phase_q;
    logic [1:0] high_q;
    wire frame_rst_n = spi_rst_n && !spi_cs_n;
    assign bit_count_o = count_q;
    assign header_o = shift_q[7:0]; // At edge 8 the shift register holds header.
    assign overrun_o = overrun_sync_q[1];

    // CS resets only per-frame state, never the mailbox/toggles.
    always_ff @(posedge spi_sclk or negedge frame_rst_n) begin
        if (!frame_rst_n) begin
            count_q <= 0; shift_q <= 0; accepted_q <= 0;
        end else begin
            shift_q <= {shift_q[37:0], spi_mosi};
            if (count_q < 6'd41) count_q <= count_q + 1'b1;
            if (count_q == 6'd39) accepted_q <= (req_q == ack_sync_q[1]);
        end
    end
    always_ff @(posedge spi_sclk or negedge spi_rst_n) begin
        if (!spi_rst_n) begin
            hold_q <= 0; req_q <= 0; ack_sync_q <= 0;
            long_q <= 0; overrun_q <= 0;
        end else begin
            ack_sync_q <= {ack_sync_q[0], ack_q};
            if (!spi_cs_n && count_q == 6'd39) begin
                if (req_q == ack_sync_q[1]) begin
                    hold_q <= {shift_q[38:0], spi_mosi};
                    long_q <= 0;
                    req_q <= ~req_q;
                end else overrun_q <= 1;
            end
            if (!spi_cs_n && count_q == 6'd40 && accepted_q) long_q <= 1;
        end
    end
    always_ff @(posedge clk or negedge clk_rst_n) begin
        if (!clk_rst_n) begin
            req_sync_q <= 0; cs_sync_q <= 2'b11; overrun_sync_q <= 0;
            phase_q <= IDLE; high_q <= 0; ack_q <= 0;
            frame_o <= 0; frame_valid_o <= 0; frame_reject_o <= 0;
        end else begin
            req_sync_q <= {req_sync_q[0], req_q};
            cs_sync_q <= {cs_sync_q[0], spi_cs_n};
            overrun_sync_q <= {overrun_sync_q[0], overrun_q};
            frame_valid_o <= 0; frame_reject_o <= 0;
            case (phase_q)
                IDLE: if (req_sync_q[1] != ack_q) phase_q <= GUARD;
                GUARD: begin high_q <= 0; phase_q <= WAIT_END; end
                WAIT_END: begin
                    if (!cs_sync_q[1]) high_q <= 0;
                    else if (high_q == 2) begin
                        frame_o <= hold_q;
                        frame_valid_o <= !long_q;
                        frame_reject_o <= long_q;
                        ack_q <= req_sync_q[1];
                        phase_q <= IDLE;
                    end else high_q <= high_q + 1'b1;
                end
                default: phase_q <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire

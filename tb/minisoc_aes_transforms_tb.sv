`timescale 1ns/1ps
`default_nettype none

// Standalone modules required on 30/10/2026. No DUT functions form the oracle.
// Official sources, packing and vector boundaries: tb/vectors/README.md.
module minisoc_aes_transforms_tb;
    logic [7:0] byte_i, byte_o;
    logic [127:0] sub_state_i, sub_state_o, sub_expected;
    logic [127:0] shift_state_i, shift_state_o;
    int checks = 0;

    // FIPS 197 Table 4, rows 0..f, columns 0..f. Input 00 is at the MSB.
    localparam logic [2047:0] FIPS_SBOX = {
        128'h637c777bf26b6fc53001672bfed7ab76,
        128'hca82c97dfa5947f0add4a2af9ca472c0,
        128'hb7fd9326363ff7cc34a5e5f171d83115,
        128'h04c723c31896059a071280e2eb27b275,
        128'h09832c1a1b6e5aa0523bd6b329e32f84,
        128'h53d100ed20fcb15b6acbbe394a4c58cf,
        128'hd0efaafb434d338545f9027f503c9fa8,
        128'h51a3408f929d38f5bcb6da2110fff3d2,
        128'hcd0c13ec5f974417c4a77e3d645d1973,
        128'h60814fdc222a908846eeb814de5e0bdb,
        128'he0323a0a4906245cc2d3ac629195e479,
        128'he7c8376d8dd54ea96c56f4ea657aae08,
        128'hba78252e1ca6b4c6e8dd741f4bbd8b8a,
        128'h703eb5664803f60e613557b986c11d9e,
        128'he1f8981169d98e949b1e87e9ce5528df,
        128'h8ca1890dbfe6426841992d0fb054bb16
    };

    minisoc_aes_sbox dut_sbox (.byte_i(byte_i), .byte_o(byte_o));
    minisoc_aes_sub_bytes dut_sub_bytes (
        .state_i(sub_state_i), .state_o(sub_state_o)
    );
    minisoc_aes_shift_rows dut_shift_rows (
        .state_i(shift_state_i), .state_o(shift_state_o)
    );

    task automatic check128(input string label_text,
                            input logic [127:0] actual, expected);
        if (actual !== expected)
            $fatal(1, "%s: got=%032h expected=%032h", label_text, actual, expected);
        checks++;
    endtask

    // Explicit byte wiring, independent of the RTL row/column loop.
    function automatic logic [127:0] ref_shift(input logic [127:0] value);
        return {value[127:120], value[87:80], value[47:40], value[7:0],
                value[95:88], value[55:48], value[15:8], value[103:96],
                value[63:56], value[23:16], value[111:104], value[71:64],
                value[31:24], value[119:112], value[79:72], value[39:32]};
    endfunction

    task automatic check_fips_round(input int round_number,
                                   input logic [127:0] start_state,
                                   after_sub_bytes, after_shift_rows);
        sub_state_i = start_state;
        // ShiftRows receives an OFFICIAL constant, not the SubBytes output.
        shift_state_i = after_sub_bytes;
        #1;
        check128($sformatf("FIPS Appendix B round %0d SubBytes", round_number),
                 sub_state_o, after_sub_bytes);
        check128($sformatf("FIPS Appendix B round %0d ShiftRows", round_number),
                 shift_state_o, after_shift_rows);
        $display("FIPS APPENDIX B ROUND %0d PASS: SubBytes and ShiftRows", round_number);
    endtask

    initial begin
        byte_i = 0;
        sub_state_i = 0;
        shift_state_i = 0;

        for (int i = 0; i < 256; i++) begin
            byte_i = 8'(i);
            // Distinct lanes detect accidental byte reordering as well as
            // exercising every S-box input at every SubBytes position.
            for (int lane = 0; lane < 16; lane++) begin
                sub_state_i[127-8*lane -: 8] = 8'((i+lane)%256);
                sub_expected[127-8*lane -: 8] = FIPS_SBOX[2047-8*((i+lane)%256) -: 8];
            end
            #1;
            if (byte_o !== FIPS_SBOX[2047-8*i -: 8])
                $fatal(1, "S-box input=%02h got=%02h expected=%02h",
                       byte_i, byte_o, FIPS_SBOX[2047-8*i -: 8]);
            checks++;
            check128("SubBytes exhaustive, distinct lanes", sub_state_o, sub_expected);
        end
        $display("SBOX EXHAUSTIVE PASS: 256 inputs; SubBytes: 256 states, all 16 lanes");

        // FIPS 197-upd1 Appendix B, printed pp. 34-35 (PDF pp. 42-43).
        // Plaintext 3243f6a8885a308d313198a2e0370734, key 2b7e...4f3c.
        // The start of round 1 is AFTER the initial AddRoundKey.
        check_fips_round(1,
            128'h193de3bea0f4e22b9ac68d2ae9f84808,
            128'hd42711aee0bf98f1b8b45de51e415230,
            128'hd4bf5d30e0b452aeb84111f11e2798e5);
        check_fips_round(10,
            128'heb40f21e592e38848ba113e71bc342d2,
            128'he9098972cb31075f3d327d94af2e2cb5,
            128'he9317db5cb322c723d2e895faf090794);

        shift_state_i = 128'h000102030405060708090a0b0c0d0e0f;
        #1;
        check128("ShiftRows byte 0 at MSB, column order", shift_state_o,
                 128'h00050a0f04090e03080d02070c01060b);
        for (int i = 0; i < 128; i++) begin
            shift_state_i = 128'h1 << i;
            #1;
            check128("ShiftRows one-hot basis", shift_state_o, ref_shift(shift_state_i));
        end
        shift_state_i = '0;
        #1;
        check128("ShiftRows zero after one-hot", shift_state_o, 128'b0);
        shift_state_i = '1;
        #1;
        check128("ShiftRows all ones", shift_state_o, {128{1'b1}});

        $display("AES TRANSFORMS TEST PASS: %0d checks, S-box 256/256, FIPS B rounds 1 and 10", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "TIMEOUT: AES transforms test");
    end
endmodule

`default_nettype wire

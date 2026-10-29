`timescale 1ns/1ps
`default_nettype none

// Sources and vector boundaries: tb/vectors/README.md.
module minisoc_aes_dp_tb;
    import aes_transforms_pkg::*;

    logic [127:0] state_i, round_key_i, state_o;
    logic decrypt_i, initial_round_i, final_round_i;
    logic [127:0] keys [0:10];
    logic [127:0] plaintext [0:3];
    logic [127:0] ciphertext [0:3];
    logic [127:0] enc_trace [0:10];
    logic [127:0] dec_trace [0:10];
    logic [7:0] inverse_reference [0:255];
    logic [127:0] sample, key_sample, basis, current;
    logic [31:0] rng;
    int checks = 0;

    minisoc_aes_dp dut (.*);

    task automatic check128(input string label_text,
                            input logic [127:0] actual, expected);
        if (actual !== expected)
            $fatal(1, "%s: got=%032h expected=%032h", label_text, actual, expected);
        checks++;
    endtask

    // Test-only polynomial multiplication and reduction, independent of xtime
    // and the optimized inverse preconditioning used by the RTL.
    function automatic logic [7:0] ref_mul(input logic [7:0] a, b);
        logic [15:0] product;
        product = 0;
        for (int i = 0; i < 8; i++)
            if (b[i]) product ^= {8'h00, a} << i;
        for (int j = 14; j >= 8; j--)
            if (product[j]) product ^= 16'h011b << (j-8);
        return product[7:0];
    endfunction

    // FIPS 197 equations 5.2/5.3: exponentiation to 254 then affine map.
    // No table is imported from the DUT to form expected S-box values.
    function automatic logic [7:0] ref_sbox(input logic [7:0] value);
        logic [7:0] power_value, inverse_value, result_value;
        power_value = value;
        inverse_value = 1;
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            if ((254 >> bit_index) & 1)
                inverse_value = ref_mul(inverse_value, power_value);
            power_value = ref_mul(power_value, power_value);
        end
        result_value = 8'h63;
        for (int i = 0; i < 8; i++)
            result_value[i] ^= inverse_value[i] ^ inverse_value[(i+4)%8] ^
                               inverse_value[(i+5)%8] ^ inverse_value[(i+6)%8] ^
                               inverse_value[(i+7)%8];
        return result_value;
    endfunction

    function automatic logic [127:0] ref_mix(input logic [127:0] value,
                                            input bit inverse_mode);
        logic [7:0] coefficients [0:3];
        logic [7:0] result_byte;
        if (inverse_mode) begin
            coefficients[0]=8'h0e; coefficients[1]=8'h0b;
            coefficients[2]=8'h0d; coefficients[3]=8'h09;
        end else begin
            coefficients[0]=8'h02; coefficients[1]=8'h03;
            coefficients[2]=8'h01; coefficients[3]=8'h01;
        end
        for (int col = 0; col < 4; col++)
            for (int row = 0; row < 4; row++) begin
                result_byte = 0;
                for (int k = 0; k < 4; k++)
                    result_byte ^= ref_mul(value[127-8*(4*col+k) -: 8],
                                           coefficients[(k+4-row)%4]);
                ref_mix[127-8*(4*col+row) -: 8] = result_byte;
            end
    endfunction

    task automatic run_round(input logic [127:0] block_value, key_value,
                             input bit inverse_mode, first_round, last_round);
        state_i = block_value;
        round_key_i = key_value;
        decrypt_i = inverse_mode;
        initial_round_i = first_round;
        final_round_i = last_round;
        #1;
    endtask

    initial begin
        // FIPS 197-upd1 Appendix A.1, externally supplied round keys.
        // Key Expansion is deliberately not implemented by this test or DUT.
        keys[0] = 128'h2b7e151628aed2a6abf7158809cf4f3c;
        keys[1] = 128'ha0fafe1788542cb123a339392a6c7605;
        keys[2] = 128'hf2c295f27a96b9435935807a7359f67f;
        keys[3] = 128'h3d80477d4716fe3e1e237e446d7a883b;
        keys[4] = 128'hef44a541a8525b7fb671253bdb0bad00;
        keys[5] = 128'hd4d1c6f87c839d87caf2b8bc11f915bc;
        keys[6] = 128'h6d88a37a110b3efddbf98641ca0093fd;
        keys[7] = 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f;
        keys[8] = 128'head27321b58dbad2312bf5607f8d292f;
        keys[9] = 128'hac7766f319fadc2128d12941575c006e;
        keys[10] = 128'hd014f9a8c9ee2589e13f0cc8b6630ca6;
        // NIST AES_Core128.pdf, four independent input/output pairs.
        plaintext[0] = 128'h6bc1bee22e409f96e93d7e117393172a;
        plaintext[1] = 128'hae2d8a571e03ac9c9eb76fac45af8e51;
        plaintext[2] = 128'h30c81c46a35ce411e5fbc1191a0a52ef;
        plaintext[3] = 128'hf69f2445df4f9b17ad2b417be66c3710;
        ciphertext[0] = 128'h3ad77bb40d7a3660a89ecaf32466ef97;
        ciphertext[1] = 128'hf5d3d58503b9699de785895a96fdbaaf;
        ciphertext[2] = 128'h43b1cd7f598ece23881b00e3ed030688;
        ciphertext[3] = 128'h7b0c785e27e8ad3f8223207104725dd4;
        enc_trace[0] = 128'h40bfabf406ee4d3042ca6b997a5c5816;
        enc_trace[1] = 128'hf265e8d51fd2397bc3b9976d9076505c;
        enc_trace[2] = 128'hfdf37cdb4b0c8c1bf7fcd8e94aa9bbf8;
        enc_trace[3] = 128'hacd1ec9ca242e2c31f690f7ab704b90f;
        enc_trace[4] = 128'ha2616e5f44a54d39c029e20092b764e9;
        enc_trace[5] = 128'h2c4af31432c3efc9c8a9b87b252ecda7;
        enc_trace[6] = 128'hcd4dc0137eb3ba1993b939ff2bd3bcf7;
        enc_trace[7] = 128'he26dbb7d40d22134e3b7fda26b9b077c;
        enc_trace[8] = 128'h41d7c6537d669140dd2f179d02acc51b;
        enc_trace[9] = 128'hbb36c7eb88334d49a4e7112e74f182c4;
        enc_trace[10] = ciphertext[0];
        // Boundaries after initial ARK, each inverse round, final ARK.
        dec_trace[0] = 128'heac3821cc49413e949a1c63b9205e331;
        dec_trace[1] = 128'h8333f0afff15a6edc191b409770e815e;
        dec_trace[2] = 128'h98b5541009a9c5ff1114ea187f3cfd3a;
        dec_trace[3] = 128'hbd6d1268f356657ddc66bad4f1e3f416;
        dec_trace[4] = 128'h712e6c5c23d3bdfae8310ddd3fd6df21;
        dec_trace[5] = 128'h3a06981e1ba543cfbaa99f124fefe363;
        dec_trace[6] = 128'h912c76763af956dec0f2ce2ea93e98da;
        dec_trace[7] = 128'h54fe6141b3b0eab968d310afd60d641e;
        dec_trace[8] = 128'h89b5884ac05653032e389b21604d123c;
        dec_trace[9] = 128'h09287f476f746abf2c4a6204da08e3ee;
        dec_trace[10] = plaintext[0];

        for (int i = 0; i < 256; i++) inverse_reference[ref_sbox(8'(i))] = 8'(i);
        for (int i = 0; i < 256; i++) begin
            check128("SubBytes exhaustive, all lanes", sub_bytes({16{8'(i)}}),
                     {16{ref_sbox(8'(i))}});
            check128("InvSubBytes exhaustive, all lanes", inv_sub_bytes({16{8'(i)}}),
                     {16{inverse_reference[i]}});
        end

        // Independent official intermediate states, NIST first forward round.
        check128("NIST SubBytes", sub_bytes(enc_trace[0]),
                 128'h090862bf6f28e3042c747feeda4a6a47);
        check128("NIST ShiftRows", shift_rows(128'h090862bf6f28e3042c747feeda4a6a47),
                 128'h09287f476f746abf2c4a6204da08e3ee);
        check128("NIST MixColumns", mix_columns(128'h09287f476f746abf2c4a6204da08e3ee),
                 128'h529f16c2978615cae01aae54ba1a2659);
        check128("NIST AddRoundKey", add_round_key(plaintext[0], keys[0]), enc_trace[0]);
        check128("NIST InvSubBytes", inv_sub_bytes(128'h090862bf6f28e3042c747feeda4a6a47),
                 enc_trace[0]);
        check128("NIST InvShiftRows", inv_shift_rows(128'h09287f476f746abf2c4a6204da08e3ee),
                 128'h090862bf6f28e3042c747feeda4a6a47);
        check128("NIST InvMixColumns", inv_mix_columns(128'h529f16c2978615cae01aae54ba1a2659),
                 128'h09287f476f746abf2c4a6204da08e3ee);
        check128("State column order", shift_rows(128'h000102030405060708090a0b0c0d0e0f),
                 128'h00050a0f04090e03080d02070c01060b);
        check128("State inverse column order", inv_shift_rows(128'h000102030405060708090a0b0c0d0e0f),
                 128'h000d0a0704010e0b0805020f0c090603);

        // Linear basis exercises each input bit against an independent matrix.
        for (int i = 0; i < 128; i++) begin
            basis = 128'h1 << i;
            check128("MixColumns basis", mix_columns(basis), ref_mix(basis, 0));
            check128("InvMixColumns basis", inv_mix_columns(basis), ref_mix(basis, 1));
        end

        // Deterministic LFSR, no simulator-dependent random seed.
        rng = 32'h1970abcd;
        for (int n = 0; n < 256; n++) begin
            for (int w = 0; w < 4; w++) begin
                rng = {rng[30:0], rng[31]^rng[21]^rng[1]^rng[0]};
                sample[127-32*w -: 32] = rng;
                key_sample[127-32*w -: 32] = ~rng;
            end
            check128("SubBytes inverse", inv_sub_bytes(sub_bytes(sample)), sample);
            check128("ShiftRows inverse", inv_shift_rows(shift_rows(sample)), sample);
            check128("MixColumns inverse", inv_mix_columns(mix_columns(sample)), sample);
            check128("MixColumns independent matrix", mix_columns(sample), ref_mix(sample, 0));
            check128("InvMixColumns independent matrix", inv_mix_columns(sample), ref_mix(sample, 1));
            check128("AddRoundKey self inverse", add_round_key(add_round_key(sample, key_sample), key_sample), sample);
        end

        // Compose full CIPHER/INVCIPHER in the TESTBENCH with external keys.
        // This validates reuse of the datapath, not a sequential AES engine.
        for (int block_index = 0; block_index < 4; block_index++) begin
            run_round(plaintext[block_index], keys[0], 0, 1, 0);
            if (block_index == 0) check128("NIST encrypt initial", state_o, enc_trace[0]);
            current = state_o;
            for (int r = 1; r <= 10; r++) begin
                run_round(current, keys[r], 0, 0, r == 10);
                if (block_index == 0) check128("NIST encrypt round", state_o, enc_trace[r]);
                current = state_o;
            end
            check128("NIST encrypt KAT", current, ciphertext[block_index]);
            run_round(ciphertext[block_index], keys[10], 1, 1, 0);
            if (block_index == 0) check128("NIST decrypt initial", state_o, dec_trace[0]);
            current = state_o;
            for (int r = 9; r >= 0; r--) begin
                run_round(current, keys[r], 1, 0, r == 0);
                if (block_index == 0) check128("NIST decrypt round", state_o, dec_trace[10-r]);
                current = state_o;
            end
            check128("NIST decrypt KAT", current, plaintext[block_index]);
        end

        // Defined precedence if a future controller asserts both selectors.
        for (int direction = 0; direction < 2; direction++) begin
            run_round(plaintext[0], keys[0], 1'(direction), 1, 1);
            check128("initial has priority over final", state_o, enc_trace[0]);
        end
        $display("AES DATAPATH TEST PASS: %0d checks, 4 encrypt + 4 decrypt KATs", checks);
        $finish;
    end

    initial begin
        #10000;
        $fatal(1, "TIMEOUT: AES datapath test");
    end
endmodule

`default_nettype wire

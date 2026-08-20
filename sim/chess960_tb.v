`timescale 1ns/1ps
`include "chess960_defs.vh"

module chess960_tb;
    reg         clk, rst;
    reg  [9:0]  seed_in;
    reg         gen_start;
    wire [23:0] board_out;
    wire        gen_valid;
    wire        seed_error;
    wire        gen_busy;
    reg  [23:0] board_in;
    reg         decode_start;
    wire [9:0]  seed_out;
    wire        decode_valid;

    chess960_top dut (
        .clk(clk), .rst(rst),
        .seed_in(seed_in), .gen_start(gen_start), .board_out(board_out),
        .gen_valid(gen_valid), .seed_error(seed_error), .gen_busy(gen_busy),
        .board_in(board_in), .decode_start(decode_start),
        .seed_out(seed_out), .decode_valid(decode_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Reference data: the same, already-validated encoding the C++ core
    // produced (data/chess960_positions.mem). This testbench proves the RTL
    // matches already-proven data; it does not re-derive correctness from
    // scratch (see tests/chess960_tests.cpp and its python-chess cross-check
    // for that).
    reg [63:0] ref_mem [0:959];
    initial $readmemh("data/chess960_positions.mem", ref_mem);

    integer seeds [0:29];
    initial begin
        seeds[0]=0;    seeds[1]=1;    seeds[2]=2;
        seeds[3]=517;  seeds[4]=518;  seeds[5]=519;
        seeds[6]=957;  seeds[7]=958;  seeds[8]=959;
        seeds[9]=40;   seeds[10]=80;  seeds[11]=120;
        seeds[12]=160; seeds[13]=200; seeds[14]=240;
        seeds[15]=280; seeds[16]=320; seeds[17]=360;
        seeds[18]=400; seeds[19]=440; seeds[20]=480;
        seeds[21]=520; seeds[22]=560; seeds[23]=600;
        seeds[24]=640; seeds[25]=680; seeds[26]=720;
        seeds[27]=760; seeds[28]=800; seeds[29]=840;
    end

    task run_generate;
        input  [9:0]    s;
        output [23:0]   got_board;
        output integer  cycles;
        begin
            // Same NBA-region hazards as sim/tb_generate_path.v, which drives
            // this exact input_interface -> control_logic -> output_interface
            // chain: (1) inputs are set with a #1 delay after the edge so the
            // DUT samples them cleanly on the *next* edge, not this one; (2)
            // `gen_busy` is control_logic's own registered `busy`, one
            // pipeline stage behind `gen_start` because it passes through
            // chess960_input_interface first, so a naive "while (gen_busy)"
            // poll starting right after gen_start drops would see gen_busy
            // still 0 and exit immediately -- we must wait for it to *rise*
            // first; (3) board_out is itself a register in
            // chess960_output_interface latched one edge after busy falls,
            // so an extra settle edge is needed before reading it.
            @(posedge clk); #1;
            seed_in = s; gen_start = 1'b1;
            @(posedge clk); #1;
            gen_start = 1'b0;

            while (!gen_busy) begin @(posedge clk); #1; end

            cycles = 0;
            while (gen_busy) begin
                @(posedge clk); #1;
                cycles = cycles + 1;
            end
            @(posedge clk); #1; // let output interface latch settle
            got_board = board_out;
        end
    endtask

    task run_decode;
        input  [23:0]  board;
        output [9:0]   got_seed;
        output         got_valid;
        begin
            // Same fix as sim/tb_decoder.v: decode_valid/seed_out are regs
            // updated via nonblocking assignment in the DUT's clocked always
            // block triggered by the same posedge that samples `start`, so a
            // #1 delay is required after that edge before reading them --
            // otherwise the read observes the pre-edge (stale) value.
            @(posedge clk);
            board_in = board; decode_start = 1'b1;
            @(posedge clk); #1;
            decode_start = 1'b0;
            got_seed  = seed_out;
            got_valid = decode_valid;
        end
    endtask

    integer i;
    integer total_tests, pass_count, fail_count;
    integer gen_cycles_sum, gen_cycles_min, gen_cycles_max;
    reg [23:0] gen_board;
    integer    gen_cyc;
    reg [9:0]  dec_seed;
    reg        dec_valid;

    initial begin
        rst = 1;
        seed_in = 0; gen_start = 0;
        board_in = 0; decode_start = 0;
        total_tests = 0; pass_count = 0; fail_count = 0;
        gen_cycles_sum = 0; gen_cycles_min = 999; gen_cycles_max = 0;

        repeat (3) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Positive tests: generate then decode each sampled seed.
        for (i = 0; i < 30; i = i + 1) begin
            run_generate(seeds[i][9:0], gen_board, gen_cyc);
            total_tests = total_tests + 1;
            gen_cycles_sum = gen_cycles_sum + gen_cyc;
            if (gen_cyc < gen_cycles_min) gen_cycles_min = gen_cyc;
            if (gen_cyc > gen_cycles_max) gen_cycles_max = gen_cyc;

            if (gen_cyc !== 6) begin
                fail_count = fail_count + 1;
                $display("FAIL generate: seed=%0d expected 6-cycle fixed latency, got %0d cycles", seeds[i], gen_cyc);
            end else if (gen_board !== ref_mem[seeds[i]][23:0]) begin
                fail_count = fail_count + 1;
                $display("FAIL generate: seed=%0d expected=%h got=%h", seeds[i], ref_mem[seeds[i]][23:0], gen_board);
            end else begin
                run_decode(gen_board, dec_seed, dec_valid);
                total_tests = total_tests + 1;
                if (!dec_valid || dec_seed !== seeds[i][9:0]) begin
                    fail_count = fail_count + 1;
                    $display("FAIL decode: seed=%0d valid=%b got_seed=%0d", seeds[i], dec_valid, dec_seed);
                end else begin
                    pass_count = pass_count + 2;
                end
            end
        end

        // Negative seed tests. seed_error is chess960_input_interface's own
        // registered output: it pulses high for exactly the one cycle after
        // the edge that samples (start=1, seed_in>=960), then falls back to
        // 0 on the very next edge (see the always block's unconditional
        // `seed_error <= 1'b0` at the top of the else branch). So the check
        // must land inside that one-cycle window: drive the input with the
        // same #1-after-edge setup as run_generate, then sample seed_error
        // right after the edge that latches it (with its own settling #1)
        // -- an extra third edge, as a literal reading of the plan text
        // would do, overshoots the pulse and always reads back 0. Verified
        // empirically against this exact hazard below.
        @(posedge clk); #1;
        seed_in = 10'd960; gen_start = 1'b1;
        @(posedge clk); #1;
        gen_start = 1'b0;
        total_tests = total_tests + 1;
        if (seed_error !== 1'b1 || gen_busy !== 1'b0) begin
            fail_count = fail_count + 1;
            $display("FAIL: seed 960 should be rejected (seed_error=%b busy=%b)", seed_error, gen_busy);
        end else pass_count = pass_count + 1;

        @(posedge clk); #1;
        seed_in = 10'd1023; gen_start = 1'b1;
        @(posedge clk); #1;
        gen_start = 1'b0;
        total_tests = total_tests + 1;
        if (seed_error !== 1'b1 || gen_busy !== 1'b0) begin
            fail_count = fail_count + 1;
            $display("FAIL: seed 1023 should be rejected (seed_error=%b busy=%b)", seed_error, gen_busy);
        end else pass_count = pass_count + 1;

        // Negative decode tests.
        begin : negative_decode_tests
            reg [23:0] invalid_same_color_bishops;
            reg [23:0] invalid_king_outside_rooks;
            reg [23:0] invalid_wrong_multiset;
            reg [23:0] invalid_all_zero;

            invalid_same_color_bishops = { `PIECE_ROOK, `PIECE_KING, `PIECE_ROOK, `PIECE_KNIGHT,
                                            `PIECE_KNIGHT, `PIECE_BISHOP, `PIECE_QUEEN, `PIECE_BISHOP };
            invalid_king_outside_rooks = { `PIECE_ROOK, `PIECE_BISHOP, `PIECE_KNIGHT, `PIECE_ROOK,
                                            `PIECE_KNIGHT, `PIECE_QUEEN, `PIECE_BISHOP, `PIECE_KING };
            invalid_wrong_multiset     = { `PIECE_ROOK, `PIECE_ROOK, `PIECE_BISHOP, `PIECE_KING,
                                            `PIECE_QUEEN, `PIECE_QUEEN, `PIECE_BISHOP, `PIECE_ROOK };
            invalid_all_zero           = 24'd0;

            run_decode(invalid_same_color_bishops, dec_seed, dec_valid);
            total_tests = total_tests + 1;
            if (dec_valid) begin fail_count = fail_count + 1; $display("FAIL: same-color bishops should be rejected"); end
            else pass_count = pass_count + 1;

            run_decode(invalid_king_outside_rooks, dec_seed, dec_valid);
            total_tests = total_tests + 1;
            if (dec_valid) begin fail_count = fail_count + 1; $display("FAIL: king outside rooks should be rejected"); end
            else pass_count = pass_count + 1;

            run_decode(invalid_wrong_multiset, dec_seed, dec_valid);
            total_tests = total_tests + 1;
            if (dec_valid) begin fail_count = fail_count + 1; $display("FAIL: wrong piece multiset should be rejected"); end
            else pass_count = pass_count + 1;

            run_decode(invalid_all_zero, dec_seed, dec_valid);
            total_tests = total_tests + 1;
            if (dec_valid) begin fail_count = fail_count + 1; $display("FAIL: all-zero board should be rejected"); end
            else pass_count = pass_count + 1;
        end

        $display("========================================================");
        $display("CHESS960 RTL SIMULATION RESULTS (ModelSim, no board)");
        $display("========================================================");
        $display("Total tests:     %0d", total_tests);
        $display("Passed:          %0d", pass_count);
        $display("Failed:          %0d", fail_count);
        $display("Generate cycles: min=%0d max=%0d (fixed-latency design; min should equal max)", gen_cycles_min, gen_cycles_max);
        $display("========================================================");
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("TESTS FAILED");

        $finish;
    end
endmodule

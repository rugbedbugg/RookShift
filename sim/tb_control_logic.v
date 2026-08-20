`timescale 1ns/1ps
`include "../hdl/chess960_defs.vh"

module tb_control_logic;
    reg         clk, rst;
    reg  [9:0]  seed;
    reg         seed_valid;
    wire [23:0] board_result;
    wire        latch_en;
    wire        busy;

    integer errors;
    integer cyc;

    chess960_control_logic dut (
        .clk(clk), .rst(rst), .seed(seed), .seed_valid(seed_valid),
        .board_result(board_result), .latch_en(latch_en), .busy(busy)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task run_seed;
        input [9:0] s;
        input [23:0] expected;
        begin
            // The #1 after each @(posedge clk) below is required: `busy` is
            // combinational off a register the DUT updates with a
            // nonblocking assign on this same edge, so a same-delta read
            // (no delay) always observes the pre-edge value per Verilog's
            // active-vs-NBA region ordering -- not a simulator quirk, a
            // guaranteed-deterministic one-cycle-stale read. The same
            // zero-delay gap also races the `seed` write against the DUT's
            // S_PARSE sampling of it. Offsetting reads/writes by #1 avoids
            // both; see tb_input_interface.v for the same codebase's
            // equivalent fix (there, done with a spare @(posedge clk)).
            @(posedge clk); #1;
            seed = s; seed_valid = 1'b1;
            @(posedge clk); #1;
            seed_valid = 1'b0;
            cyc = 0;
            while (busy) begin
                @(posedge clk); #1;
                cyc = cyc + 1;
            end
            if (cyc !== 6) begin
                errors = errors + 1;
                $display("FAIL seed %0d: expected 6 cycles, got %0d", s, cyc);
            end
            if (board_result !== expected) begin
                errors = errors + 1;
                $display("FAIL seed %0d: expected board=%h got=%h", s, expected, board_result);
            end else begin
                $display("PASS seed %0d: board=%h in %0d cycles", s, board_result, cyc);
            end
        end
    endtask

    initial begin
        errors = 0;
        rst = 1; seed = 0; seed_valid = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // Expected boards built from the piece codes directly (RNBQKBNR
        // for seed 518, BBQNNRKR for seed 0, RKRNNQBB for seed 959 --
        // the same checkpoints used in tests/chess960_tests.cpp).
        // seed 518 backrank RNBQKBNR (sq0=R..sq7=R) -> {sq7..sq0} concatenation.
        run_seed(10'd518, { `PIECE_ROOK, `PIECE_KNIGHT, `PIECE_BISHOP, `PIECE_KING,
                             `PIECE_QUEEN, `PIECE_BISHOP, `PIECE_KNIGHT, `PIECE_ROOK });
        // seed 0 backrank BBQNNRKR (sq0=B..sq7=R) -> {sq7..sq0} concatenation.
        run_seed(10'd0,   { `PIECE_ROOK, `PIECE_KING, `PIECE_ROOK, `PIECE_KNIGHT,
                             `PIECE_KNIGHT, `PIECE_QUEEN, `PIECE_BISHOP, `PIECE_BISHOP });

        if (errors == 0) $display("tb_control_logic: ALL PASSED");
        else $display("tb_control_logic: %0d FAILURES", errors);
        $finish;
    end
endmodule

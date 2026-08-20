`timescale 1ns/1ps
`include "../hdl/chess960_defs.vh"

module tb_position_generator;
    reg  [23:0] board_in;
    reg  [1:0]  step;
    reg  [2:0]  r3;
    reg  [3:0]  n4;
    wire [23:0] board_out;

    integer errors;

    chess960_position_generator dut (
        .board_in (board_in),
        .step     (step),
        .r3       (r3),
        .n4       (n4),
        .board_out(board_out)
    );

    task check;
        input [23:0] got;
        input [23:0] expected;
        input [255:0] label;
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("FAIL %0s: expected=%h got=%h", label, expected, got);
            end else begin
                $display("PASS %0s", label);
            end
        end
    endtask

    initial begin
        errors = 0;

        // Seed 518: bishops already placed at square 2 (dark) and square 5
        // (light) -- board_in reflects that starting state for this test.
        board_in = 24'd0;
        board_in[3*2 +: 3] = `PIECE_BISHOP;
        board_in[3*5 +: 3] = `PIECE_BISHOP;

        // QUEEN step, r3=2 -> vacant ascending {0,1,3,4,6,7}, index 2 = square 3.
        step = 2'd0; r3 = 3'd2; n4 = 4'd0;
        #1;
        check(board_out[3*3 +: 3], `PIECE_QUEEN, "seed518_queen_at_d1");

        // KNIGHTS step on board with bishops+queen, n4=5 -> pair (1,3) ->
        // vacant5 ascending {0,1,4,6,7}, ranks 1 and 3 = squares 1 and 6.
        board_in = board_out;
        step = 2'd1; n4 = 4'd5;
        #1;
        check(board_out[3*1 +: 3], `PIECE_KNIGHT, "seed518_knight_at_b1");
        check(board_out[3*6 +: 3], `PIECE_KNIGHT, "seed518_knight_at_g1");

        // ROOKS_KING step on board with bishops+queen+knights -> vacant3
        // ascending {0,4,7} -> Rook,King,Rook.
        board_in = board_out;
        step = 2'd2;
        #1;
        check(board_out[3*0 +: 3], `PIECE_ROOK, "seed518_rook_at_a1");
        check(board_out[3*4 +: 3], `PIECE_KING, "seed518_king_at_e1");
        check(board_out[3*7 +: 3], `PIECE_ROOK, "seed518_rook_at_h1");

        if (errors == 0) $display("tb_position_generator: ALL PASSED");
        else $display("tb_position_generator: %0d FAILURES", errors);
        $finish;
    end
endmodule

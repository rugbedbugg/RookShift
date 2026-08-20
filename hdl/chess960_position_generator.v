`include "chess960_defs.vh"

// Position Generation Logic: combinational placement functions used by
// chess960_control_logic at its QUEEN/KNIGHTS/ROOKS_KING states. Given the
// board as committed so far and which step is active, returns the board
// with that step's piece(s) added. Mirrors generate_position() in
// src/chess960.hpp one step at a time instead of all at once.
module chess960_position_generator (
    input  wire [23:0] board_in,
    input  wire [1:0]  step,
    input  wire [2:0]  r3,
    input  wire [3:0]  n4,
    output reg  [23:0] board_out
);
    localparam STEP_QUEEN      = 2'd0;
    localparam STEP_KNIGHTS    = 2'd1;
    localparam STEP_ROOKS_KING = 2'd2;

    function [7:0] occupied_mask;
        input [23:0] board;
        integer sq;
        begin
            occupied_mask = 8'b0;
            for (sq = 0; sq < 8; sq = sq + 1)
                occupied_mask[sq] = (board[3*sq +: 3] != `PIECE_NONE);
        end
    endfunction

    // Rank (0-indexed, ascending) of the k-th square NOT set in `occupied`.
    function [2:0] kth_vacant;
        input [7:0] occupied;
        input [2:0] k;
        integer sq;
        integer count;
        begin
            count = 0;
            kth_vacant = 3'd0;
            for (sq = 0; sq < 8; sq = sq + 1) begin
                if (!occupied[sq]) begin
                    if (count == k) kth_vacant = sq[2:0];
                    count = count + 1;
                end
            end
        end
    endfunction

    // Lexicographic "choose 2 of 5" table -- the same one documented as
    // kKnightPairs in src/chess960.hpp.
    function [5:0] knight_pair;
        input [3:0] n4;
        begin
            case (n4)
                4'd0: knight_pair = {3'd0, 3'd1};
                4'd1: knight_pair = {3'd0, 3'd2};
                4'd2: knight_pair = {3'd0, 3'd3};
                4'd3: knight_pair = {3'd0, 3'd4};
                4'd4: knight_pair = {3'd1, 3'd2};
                4'd5: knight_pair = {3'd1, 3'd3};
                4'd6: knight_pair = {3'd1, 3'd4};
                4'd7: knight_pair = {3'd2, 3'd3};
                4'd8: knight_pair = {3'd2, 3'd4};
                4'd9: knight_pair = {3'd3, 3'd4};
                default: knight_pair = 6'd0;
            endcase
        end
    endfunction

    reg [7:0] occ;
    reg [2:0] sq_q;
    reg [2:0] rank_k1, rank_k2;
    reg [2:0] sq_k1, sq_k2;
    reg [2:0] sq_r0, sq_r1, sq_r2;

    always @(*) begin
        occ = occupied_mask(board_in);
        board_out = board_in;
        case (step)
            STEP_QUEEN: begin
                sq_q = kth_vacant(occ, r3);
                board_out[3*sq_q +: 3] = `PIECE_QUEEN;
            end
            STEP_KNIGHTS: begin
                {rank_k1, rank_k2} = knight_pair(n4);
                sq_k1 = kth_vacant(occ, rank_k1);
                sq_k2 = kth_vacant(occ, rank_k2);
                board_out[3*sq_k1 +: 3] = `PIECE_KNIGHT;
                board_out[3*sq_k2 +: 3] = `PIECE_KNIGHT;
            end
            STEP_ROOKS_KING: begin
                sq_r0 = kth_vacant(occ, 3'd0);
                sq_r1 = kth_vacant(occ, 3'd1);
                sq_r2 = kth_vacant(occ, 3'd2);
                board_out[3*sq_r0 +: 3] = `PIECE_ROOK;
                board_out[3*sq_r1 +: 3] = `PIECE_KING;
                board_out[3*sq_r2 +: 3] = `PIECE_ROOK;
            end
            default: board_out = board_in;
        endcase
    end
endmodule

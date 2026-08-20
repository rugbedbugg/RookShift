`include "chess960_defs.vh"

// Decoder: board -> seed by direct inversion (no ROM, no search), mirroring
// position_to_seed() in src/chess960.hpp. The published paper does not
// specify decoder internals, so this doesn't contradict it -- it replaces
// the archived code's linear search (mislabeled a "CAM" in a comment there,
// a claim the paper itself never makes).
module chess960_decoder (
    input  wire        clk,
    input  wire        rst,
    input  wire [23:0] board_in,
    input  wire        start,
    output reg  [9:0]  seed_out,
    output reg         decode_valid
);
    function is_valid_position;
        input [23:0] board;
        integer sq;
        integer rooks, knights, bishops, queens, kings;
        integer bishop_sq0, bishop_sq1, bcount;
        integer rook_sq0, rook_sq1, rcount, king_sq;
        integer lo, hi;
        reg [2:0] piece;
        begin
            rooks = 0; knights = 0; bishops = 0; queens = 0; kings = 0;
            bcount = 0; rcount = 0; king_sq = -1;
            bishop_sq0 = -1; bishop_sq1 = -1;
            rook_sq0 = -1; rook_sq1 = -1;
            for (sq = 0; sq < 8; sq = sq + 1) begin
                piece = board[3*sq +: 3];
                case (piece)
                    `PIECE_ROOK: begin
                        rooks = rooks + 1;
                        if (rcount == 0) rook_sq0 = sq; else rook_sq1 = sq;
                        rcount = rcount + 1;
                    end
                    `PIECE_KNIGHT: knights = knights + 1;
                    `PIECE_BISHOP: begin
                        bishops = bishops + 1;
                        if (bcount == 0) bishop_sq0 = sq; else bishop_sq1 = sq;
                        bcount = bcount + 1;
                    end
                    `PIECE_QUEEN: queens = queens + 1;
                    `PIECE_KING: begin kings = kings + 1; king_sq = sq; end
                    default: ; // PIECE_NONE or a reserved code
                endcase
            end

            is_valid_position = 1'b0;
            if (rooks == 2 && knights == 2 && bishops == 2 && queens == 1 && kings == 1) begin
                if ((bishop_sq0 % 2) != (bishop_sq1 % 2)) begin
                    lo = (rook_sq0 < rook_sq1) ? rook_sq0 : rook_sq1;
                    hi = (rook_sq0 < rook_sq1) ? rook_sq1 : rook_sq0;
                    if (lo < king_sq && king_sq < hi) is_valid_position = 1'b1;
                end
            end
        end
    endfunction

    // Rank (0-indexed) of `target` among ascending squares 0..7 not set in
    // `exclude_mask` -- mirrors std::find's index into a vacant-squares
    // array in position_to_seed().
    function [2:0] rank_excluding;
        input [7:0] exclude_mask;
        input [2:0] target;
        integer sq;
        integer count;
        begin
            count = 0;
            for (sq = 0; sq < target; sq = sq + 1)
                if (!exclude_mask[sq]) count = count + 1;
            rank_excluding = count[2:0];
        end
    endfunction

    function [3:0] reverse_knight_pair;
        input [2:0] k1;
        input [2:0] k2;
        reg [5:0] pair;
        begin
            pair = {k1, k2};
            case (pair)
                {3'd0, 3'd1}: reverse_knight_pair = 4'd0;
                {3'd0, 3'd2}: reverse_knight_pair = 4'd1;
                {3'd0, 3'd3}: reverse_knight_pair = 4'd2;
                {3'd0, 3'd4}: reverse_knight_pair = 4'd3;
                {3'd1, 3'd2}: reverse_knight_pair = 4'd4;
                {3'd1, 3'd3}: reverse_knight_pair = 4'd5;
                {3'd1, 3'd4}: reverse_knight_pair = 4'd6;
                {3'd2, 3'd3}: reverse_knight_pair = 4'd7;
                {3'd2, 3'd4}: reverse_knight_pair = 4'd8;
                {3'd3, 3'd4}: reverse_knight_pair = 4'd9;
                default:      reverse_knight_pair = 4'd15; // no match
            endcase
        end
    endfunction

    reg        valid_board;
    integer    sq;
    reg  [2:0] piece;
    integer    bishop_sq0, bishop_sq1, bcount;
    integer    queen_sq;
    integer    knight_sq0, knight_sq1, kcount;
    reg  [7:0] bishop_mask, bishop_queen_mask;
    reg  [2:0] light_sq, dark_sq;
    reg  [1:0] r1_d, r2_d;
    reg  [2:0] r3_d;
    reg  [2:0] rank_k1, rank_k2;
    reg  [3:0] n4_val;

    always @(*) begin
        valid_board = is_valid_position(board_in);

        bishop_sq0 = -1; bishop_sq1 = -1; bcount = 0;
        queen_sq = -1;
        knight_sq0 = -1; knight_sq1 = -1; kcount = 0;

        for (sq = 0; sq < 8; sq = sq + 1) begin
            piece = board_in[3*sq +: 3];
            case (piece)
                `PIECE_BISHOP: begin
                    if (bcount == 0) bishop_sq0 = sq; else bishop_sq1 = sq;
                    bcount = bcount + 1;
                end
                `PIECE_QUEEN: queen_sq = sq;
                `PIECE_KNIGHT: begin
                    if (kcount == 0) knight_sq0 = sq; else knight_sq1 = sq;
                    kcount = kcount + 1;
                end
                default: ;
            endcase
        end

        light_sq = ((bishop_sq0 % 2) == 1) ? bishop_sq0[2:0] : bishop_sq1[2:0];
        dark_sq  = ((bishop_sq0 % 2) == 1) ? bishop_sq1[2:0] : bishop_sq0[2:0];
        r1_d = (light_sq - 3'd1) / 3'd2;
        r2_d = dark_sq / 3'd2;

        bishop_mask = 8'b0;
        if (bishop_sq0 >= 0) bishop_mask[bishop_sq0] = 1'b1;
        if (bishop_sq1 >= 0) bishop_mask[bishop_sq1] = 1'b1;
        r3_d = (queen_sq >= 0) ? rank_excluding(bishop_mask, queen_sq[2:0]) : 3'd0;

        bishop_queen_mask = bishop_mask;
        if (queen_sq >= 0) bishop_queen_mask[queen_sq] = 1'b1;
        rank_k1 = (knight_sq0 >= 0) ? rank_excluding(bishop_queen_mask, knight_sq0[2:0]) : 3'd0;
        rank_k2 = (knight_sq1 >= 0) ? rank_excluding(bishop_queen_mask, knight_sq1[2:0]) : 3'd0;
        n4_val  = (rank_k1 <= rank_k2) ? reverse_knight_pair(rank_k1, rank_k2)
                                        : reverse_knight_pair(rank_k2, rank_k1);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seed_out     <= 10'd0;
            decode_valid <= 1'b0;
        end else begin
            decode_valid <= 1'b0;
            if (start && valid_board && n4_val != 4'd15) begin
                seed_out     <= ((n4_val * 10'd6 + r3_d) * 10'd4 + r2_d) * 10'd4 + r1_d;
                decode_valid <= 1'b1;
            end
        end
    end
endmodule

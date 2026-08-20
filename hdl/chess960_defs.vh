`ifndef CHESS960_DEFS_VH
`define CHESS960_DEFS_VH

// Piece codes must stay bit-identical to `enum class Piece` in
// src/chess960.hpp: None=0, Rook=1, Knight=2, Bishop=3, Queen=4, King=5.
`define PIECE_NONE   3'd0
`define PIECE_ROOK   3'd1
`define PIECE_KNIGHT 3'd2
`define PIECE_BISHOP 3'd3
`define PIECE_QUEEN  3'd4
`define PIECE_KING   3'd5

`endif

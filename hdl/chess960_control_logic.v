`include "chess960_defs.vh"

// Control Logic: the FSM "overseeing the entire process... from seed input
// acquisition to final position output." States mirror Algorithm 1's step
// list one-to-one. Fixed 6-cycle latency (PARSE..OUTPUT) for every seed.
module chess960_control_logic (
    input  wire        clk,
    input  wire        rst,
    input  wire [9:0]  seed,
    input  wire        seed_valid,
    output reg  [23:0] board_result,
    output reg         latch_en,
    output wire        busy
);
    localparam S_IDLE       = 3'd0;
    localparam S_PARSE      = 3'd1;
    localparam S_BISHOPS    = 3'd2;
    localparam S_QUEEN      = 3'd3;
    localparam S_KNIGHTS    = 3'd4;
    localparam S_ROOKS_KING = 3'd5;
    localparam S_OUTPUT     = 3'd6;

    reg [2:0]  state;
    reg [1:0]  r1, r2;
    reg [2:0]  r3;
    reg [3:0]  n4;
    reg [23:0] board;
    reg [1:0]  gen_step;

    assign busy = (state != S_IDLE);

    wire [23:0] gen_board_out;

    chess960_position_generator u_gen (
        .board_in (board),
        .step     (gen_step),
        .r3       (r3),
        .n4       (n4),
        .board_out(gen_board_out)
    );

    always @(*) begin
        case (state)
            S_QUEEN:      gen_step = 2'd0;
            S_KNIGHTS:    gen_step = 2'd1;
            S_ROOKS_KING: gen_step = 2'd2;
            default:      gen_step = 2'd0;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_IDLE;
            board        <= 24'd0;
            board_result <= 24'd0;
            latch_en     <= 1'b0;
            r1 <= 2'd0; r2 <= 2'd0; r3 <= 3'd0; n4 <= 4'd0;
        end else begin
            latch_en <= 1'b0;
            case (state)
                S_IDLE: begin
                    board <= 24'd0;
                    if (seed_valid) state <= S_PARSE;
                end
                S_PARSE: begin
                    // Same divmod decomposition as generate_position() in
                    // src/chess960.hpp: r1=seed%4, r2=(seed/4)%4,
                    // r3=(seed/16)%6, n4=seed/96.
                    r1 <= seed % 10'd4;
                    r2 <= (seed / 10'd4) % 10'd4;
                    r3 <= (seed / 10'd16) % 10'd6;
                    n4 <= seed / 10'd96;
                    state <= S_BISHOPS;
                end
                S_BISHOPS: begin
                    board[3*(2*r1+1) +: 3] <= `PIECE_BISHOP;
                    board[3*(2*r2)   +: 3] <= `PIECE_BISHOP;
                    state <= S_QUEEN;
                end
                S_QUEEN: begin
                    board <= gen_board_out;
                    state <= S_KNIGHTS;
                end
                S_KNIGHTS: begin
                    board <= gen_board_out;
                    state <= S_ROOKS_KING;
                end
                S_ROOKS_KING: begin
                    board <= gen_board_out;
                    state <= S_OUTPUT;
                end
                S_OUTPUT: begin
                    board_result <= board;
                    latch_en     <= 1'b1;
                    state        <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

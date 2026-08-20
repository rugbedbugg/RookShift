`timescale 1ns/1ps
`include "../hdl/chess960_defs.vh"

module tb_decoder;
    reg         clk, rst;
    reg  [23:0] board_in;
    reg         start;
    wire [9:0]  seed_out;
    wire        decode_valid;

    integer errors;

    chess960_decoder dut (
        .clk(clk), .rst(rst), .board_in(board_in), .start(start),
        .seed_out(seed_out), .decode_valid(decode_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task run_decode;
        input [23:0] board;
        begin
            @(posedge clk);
            board_in = board; start = 1'b1;
            // The #1 below is required: decode_valid/seed_out are regs
            // updated via nonblocking assignment in the DUT's clocked
            // always block triggered by this same posedge, so reading them
            // with no delay observes the pre-edge (stale) value per
            // Verilog's active-vs-NBA region ordering. See tb_control_logic.v
            // and tb_generate_path.v for the same fix applied to this
            // codebase's other modules.
            @(posedge clk); #1;
            start = 1'b0;
        end
    endtask

    initial begin
        errors = 0;
        rst = 1; board_in = 0; start = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // Positive: seed 518 = RNBQKBNR -> squares0..7 = R,N,B,Q,K,B,N,R.
        run_decode({ `PIECE_ROOK, `PIECE_KNIGHT, `PIECE_BISHOP, `PIECE_KING,
                      `PIECE_QUEEN, `PIECE_BISHOP, `PIECE_KNIGHT, `PIECE_ROOK });
        if (!decode_valid || seed_out !== 10'd518) begin
            errors = errors + 1;
            $display("FAIL: RNBQKBNR should decode to seed 518 (valid=%b seed=%0d)", decode_valid, seed_out);
        end else $display("PASS: RNBQKBNR -> seed %0d", seed_out);

        // Negative: same-color bishops. Squares0..7 = B,Q,B,N,N,R,K,R.
        run_decode({ `PIECE_ROOK, `PIECE_KING, `PIECE_ROOK, `PIECE_KNIGHT,
                      `PIECE_KNIGHT, `PIECE_BISHOP, `PIECE_QUEEN, `PIECE_BISHOP });
        if (decode_valid) begin
            errors = errors + 1;
            $display("FAIL: same-color bishops should be rejected");
        end else $display("PASS: same-color bishops rejected");

        // Negative: king outside the rooks. Squares0..7 = K,B,Q,N,R,N,B,R.
        run_decode({ `PIECE_ROOK, `PIECE_BISHOP, `PIECE_KNIGHT, `PIECE_ROOK,
                      `PIECE_KNIGHT, `PIECE_QUEEN, `PIECE_BISHOP, `PIECE_KING });
        if (decode_valid) begin
            errors = errors + 1;
            $display("FAIL: king outside the rooks should be rejected");
        end else $display("PASS: king outside the rooks rejected");

        // Negative: wrong piece multiset. Squares0..7 = R,B,Q,Q,K,B,R,R.
        run_decode({ `PIECE_ROOK, `PIECE_ROOK, `PIECE_BISHOP, `PIECE_KING,
                      `PIECE_QUEEN, `PIECE_QUEEN, `PIECE_BISHOP, `PIECE_ROOK });
        if (decode_valid) begin
            errors = errors + 1;
            $display("FAIL: wrong piece multiset should be rejected");
        end else $display("PASS: wrong piece multiset rejected");

        // Negative: all-zero.
        run_decode(24'd0);
        if (decode_valid) begin
            errors = errors + 1;
            $display("FAIL: all-zero board should be rejected");
        end else $display("PASS: all-zero board rejected");

        if (errors == 0) $display("tb_decoder: ALL PASSED");
        else $display("tb_decoder: %0d FAILURES", errors);
        $finish;
    end
endmodule

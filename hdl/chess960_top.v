// Top-level: wires Input Interface -> Control Logic -> Position Generation
// Logic -> Output Interface as the generate path, plus the Decoder as an
// independent path sharing the same clock/reset.
module chess960_top (
    input  wire        clk,
    input  wire        rst,

    input  wire [9:0]  seed_in,
    input  wire        gen_start,
    output wire [23:0] board_out,
    output wire        gen_valid,
    output wire        seed_error,
    output wire        gen_busy,

    input  wire [23:0] board_in,
    input  wire        decode_start,
    output wire [9:0]  seed_out,
    output wire        decode_valid
);
    wire [9:0]  seed_latched;
    wire        seed_valid;
    wire [23:0] board_result;
    wire        latch_en;

    chess960_input_interface u_input (
        .clk(clk), .rst(rst), .seed_in(seed_in), .start(gen_start),
        .seed_out(seed_latched), .seed_valid(seed_valid), .seed_error(seed_error)
    );

    chess960_control_logic u_ctrl (
        .clk(clk), .rst(rst), .seed(seed_latched), .seed_valid(seed_valid),
        .board_result(board_result), .latch_en(latch_en), .busy(gen_busy)
    );

    chess960_output_interface u_output (
        .clk(clk), .rst(rst), .board_in(board_result), .latch_en(latch_en),
        .board_out(board_out), .valid(gen_valid)
    );

    chess960_decoder u_decoder (
        .clk(clk), .rst(rst), .board_in(board_in), .start(decode_start),
        .seed_out(seed_out), .decode_valid(decode_valid)
    );
endmodule

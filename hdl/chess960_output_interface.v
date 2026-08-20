// Output Interface: latches the finished board when Control Logic asserts
// latch_en, holds it (and a valid flag) until the next result arrives.
module chess960_output_interface (
    input  wire        clk,
    input  wire        rst,
    input  wire [23:0] board_in,
    input  wire        latch_en,
    output reg  [23:0] board_out,
    output reg         valid
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            board_out <= 24'd0;
            valid     <= 1'b0;
        end else if (latch_en) begin
            board_out <= board_in;
            valid     <= 1'b1;
        end
    end
endmodule

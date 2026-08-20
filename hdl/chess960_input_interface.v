`include "chess960_defs.vh"

// Input Interface: registers the incoming 10-bit seed on `start`, rejects
// (seed_error) anything outside [0, 959] rather than passing it on.
module chess960_input_interface (
    input  wire       clk,
    input  wire       rst,
    input  wire [9:0] seed_in,
    input  wire       start,
    output reg  [9:0] seed_out,
    output reg        seed_valid,
    output reg        seed_error
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            seed_out   <= 10'd0;
            seed_valid <= 1'b0;
            seed_error <= 1'b0;
        end else begin
            seed_valid <= 1'b0;
            seed_error <= 1'b0;
            if (start) begin
                if (seed_in < 10'd960) begin
                    seed_out   <= seed_in;
                    seed_valid <= 1'b1;
                end else begin
                    seed_error <= 1'b1;
                end
            end
        end
    end
endmodule

`timescale 1ns/1ps

module tb_input_interface;
    reg        clk, rst;
    reg  [9:0] seed_in;
    reg        start;
    wire [9:0] seed_out;
    wire       seed_valid, seed_error;

    integer errors;

    chess960_input_interface dut (
        .clk(clk), .rst(rst), .seed_in(seed_in), .start(start),
        .seed_out(seed_out), .seed_valid(seed_valid), .seed_error(seed_error)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        errors = 0;
        rst = 1; seed_in = 0; start = 0;
        repeat (2) @(posedge clk);
        rst = 0;
        @(posedge clk);

        // Valid seed.
        seed_in = 10'd518; start = 1'b1;
        @(posedge clk); start = 1'b0;
        @(posedge clk);
        if (seed_out !== 10'd518 || seed_valid !== 1'b1 || seed_error !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: valid seed 518 not accepted correctly (out=%0d valid=%b err=%b)", seed_out, seed_valid, seed_error);
        end else $display("PASS: valid seed 518 accepted");

        // Boundary invalid seed.
        @(posedge clk);
        seed_in = 10'd960; start = 1'b1;
        @(posedge clk); start = 1'b0;
        @(posedge clk);
        if (seed_error !== 1'b1 || seed_valid !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: seed 960 should be rejected (valid=%b err=%b)", seed_valid, seed_error);
        end else $display("PASS: seed 960 rejected");

        // Max 10-bit value.
        @(posedge clk);
        seed_in = 10'd1023; start = 1'b1;
        @(posedge clk); start = 1'b0;
        @(posedge clk);
        if (seed_error !== 1'b1 || seed_valid !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: seed 1023 should be rejected (valid=%b err=%b)", seed_valid, seed_error);
        end else $display("PASS: seed 1023 rejected");

        if (errors == 0) $display("tb_input_interface: ALL PASSED");
        else $display("tb_input_interface: %0d FAILURES", errors);
        $finish;
    end
endmodule

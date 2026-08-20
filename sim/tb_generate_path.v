`timescale 1ns/1ps

module tb_generate_path;
    reg         clk, rst;
    reg  [9:0]  seed_in;
    reg         start;
    wire [9:0]  seed_latched;
    wire        seed_valid, seed_error;
    wire [23:0] board_result;
    wire        latch_en;
    wire        busy;
    wire [23:0] board_out;
    wire        gen_valid;

    integer errors;
    integer i;
    integer cyc;
    reg [63:0] ref_mem [0:959];

    chess960_input_interface u_in (
        .clk(clk), .rst(rst), .seed_in(seed_in), .start(start),
        .seed_out(seed_latched), .seed_valid(seed_valid), .seed_error(seed_error)
    );

    chess960_control_logic u_ctrl (
        .clk(clk), .rst(rst), .seed(seed_latched), .seed_valid(seed_valid),
        .board_result(board_result), .latch_en(latch_en), .busy(busy)
    );

    chess960_output_interface u_out (
        .clk(clk), .rst(rst), .board_in(board_result), .latch_en(latch_en),
        .board_out(board_out), .valid(gen_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Path is relative to the simulator's runtime working directory, which
    // Step 3 sets to the repo root -- not relative to this file.
    initial $readmemh("data/chess960_positions.mem", ref_mem);

    task run_seed;
        input [9:0] s;
        begin
            // Every @(posedge clk) below is followed by #1 before any signal
            // derived from a DUT register is written or read. `busy` and
            // `board_out` are combinational/registered off state updated via
            // nonblocking assignment on the clock edge; sampling them with no
            // delay right after @(posedge clk) observes the pre-edge (stale)
            // value per IEEE 1364/1800 active-vs-NBA region ordering, which
            // silently truncates the busy-wait by a cycle (see tb_control_logic.v
            // for the same fix in the simpler single-DUT case).
            //
            // This path also has an extra pipeline stage that tb_control_logic.v
            // doesn't: `start` sets seed_valid via chess960_input_interface's own
            // registered output, so busy does not rise on the edge immediately
            // after start is dropped -- it takes one more edge for
            // chess960_control_logic to observe seed_valid. So we first wait
            // for busy to *rise* before waiting for it to fall; polling only
            // "while (busy)" from here would see busy still 0 and exit with
            // zero iterations, checking board_out a cycle before the FSM even
            // starts.
            @(posedge clk); #1;
            seed_in = s; start = 1'b1;
            @(posedge clk); #1;
            start = 1'b0;

            while (!busy) begin @(posedge clk); #1; end

            cyc = 0;
            while (busy) begin
                @(posedge clk); #1;
                cyc = cyc + 1;
            end
            @(posedge clk); #1; // let output interface latch settle
            if (board_out !== ref_mem[s][23:0]) begin
                errors = errors + 1;
                $display("FAIL seed %0d: expected=%h got=%h (cycles=%0d)", s, ref_mem[s][23:0], board_out, cyc);
            end else begin
                $display("PASS seed %0d: board=%h (cycles=%0d)", s, board_out, cyc);
            end
        end
    endtask

    initial begin
        errors = 0;
        rst = 1; seed_in = 0; start = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        for (i = 0; i < 10; i = i + 1) run_seed(i[9:0]);
        run_seed(10'd518);
        run_seed(10'd959);

        if (errors == 0) $display("tb_generate_path: ALL PASSED");
        else $display("tb_generate_path: %0d FAILURES", errors);
        $finish;
    end
endmodule

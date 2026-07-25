`timescale 1ns/1ps
module systolic_tb();
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst;
    reg signed [7:0] raw_row_0, raw_row_1, raw_row_2, raw_row_3, raw_row_4;
    reg signed [7:0] raw_col_0, raw_col_1, raw_col_2, raw_col_3, raw_col_4;
    reg wrt_en;
    wire signed [399:0] matrix_out;
    wire valid_out;

    systolic uut(
        .clk(clk),
        .rst(rst),
        .raw_row_0(raw_row_0),
        .raw_row_1(raw_row_1),
        .raw_row_2(raw_row_2),
        .raw_row_3(raw_row_3),
        .raw_row_4(raw_row_4),
        .raw_col_0(raw_col_0),
        .raw_col_1(raw_col_1),
        .raw_col_2(raw_col_2),
        .raw_col_3(raw_col_3),
        .raw_col_4(raw_col_4),
        .wrt_en(wrt_en),
        .matrix_out(matrix_out),
        .valid_out(valid_out)
    );

    integer r;
    integer c;
    integer j;

    task print_matrix;
        begin
            $display("\nFormatted matrix_out:");
            for (r = 0; r < 5; r = r + 1) begin
                $write("[");
                for (c = 0; c < 5; c = c + 1) begin
                    $write("%0d", $signed(matrix_out[((r * 5 + c) * 16) +: 16]));
                    if (c != 4) $write("\t");
                end
                $write("]\n");
            end
            $display("");
        end
    endtask

    initial begin
        $dumpfile("systolic_tb.vcd");
        $dumpvars(0, systolic_tb);

        // Initialize Everything to 0
        rst = 1;
        

        // Hold reset for 2 cycles, then release
        repeat (2) @(posedge clk);
        rst = 0;
        wrt_en = 1;
        @(negedge clk);

        
        // Cycle 1: Feed Index 0 of the calculation (Column 0 of Matrix A, Row 0 of Matrix B)
        raw_row_0 = 8'sd1;   raw_row_1 = 8'sd2;   raw_row_2 = -8'sd1;  raw_row_3 = 8'sd0;   raw_row_4 = 8'sd4;
        raw_col_0 = 8'sd2;   raw_col_1 = 8'sd0;   raw_col_2 = -8'sd1;  raw_col_3 = 8'sd1;   raw_col_4 = 8'sd3;
        @(negedge clk);

        // Cycle 2: Feed Index 1 (Column 1 of Matrix A, Row 1 of Matrix B)
        raw_row_0 = -8'sd2;  raw_row_1 = 8'sd1;   raw_row_2 = 8'sd0;   raw_row_3 = 8'sd3;   raw_row_4 = -8'sd1;
        raw_col_0 = -8'sd1;  raw_col_1 = 8'sd3;   raw_col_2 = 8'sd0;   raw_col_3 = 8'sd2;   raw_col_4 = -8'sd2;
        @(negedge clk);

        // Cycle 3: Feed Index 2 (Column 2 of Matrix A, Row 2 of Matrix B)
        raw_row_0 = 8'sd0;   raw_row_1 = -8'sd3;  raw_row_2 = 8'sd2;   raw_row_3 = 8'sd1;   raw_row_4 = -8'sd2;
        raw_col_0 = 8'sd0;   raw_col_1 = -8'sd2;  raw_col_2 = 8'sd4;   raw_col_3 = -8'sd1;  raw_col_4 = 8'sd1;
        @(negedge clk);

        // Cycle 4: Feed Index 3 (Column 3 of Matrix A, Row 3 of Matrix B)
        raw_row_0 = 8'sd3;   raw_row_1 = 8'sd0;   raw_row_2 = -8'sd2;  raw_row_3 = -8'sd1;  raw_row_4 = 8'sd0;
        raw_col_0 = 8'sd3;   raw_col_1 = 8'sd1;   raw_col_2 = 8'sd0;   raw_col_3 = 8'sd3;   raw_col_4 = 8'sd0;
        @(negedge clk);

        // Cycle 5: Feed Index 4 (The final elements: Column 4 of Matrix A, Row 4 of Matrix B)
        raw_row_0 = -8'sd1;  raw_row_1 = 8'sd4;   raw_row_2 = 8'sd1;   raw_row_3 = -8'sd2;  raw_row_4 = 8'sd3;
        raw_col_0 = -8'sd2;  raw_col_1 = 8'sd0;   raw_col_2 = 8'sd2;   raw_col_3 = -8'sd1;  raw_col_4 = -8'sd3;
        @(negedge clk);

        wrt_en = 0;

        // Wait 15 cycles for the final waves to settle into the accumulators
        repeat (15) @(posedge clk);

        // Print final result matrix!
        print_matrix();

        $display("Simulation finished.");
        #10;
        $finish;
    end
endmodule

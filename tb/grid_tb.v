`timescale 1ns/1ps
module grid_tb();
    reg signed [39:0] row;
    reg signed [39:0] col;
    
    reg clk;
    initial clk = 0;
    always #5 clk = ~clk;
    reg rst;
    wire signed [399:0] matrix_out;

    systolic_grid uut(
        .clk(clk),
        .rst(rst),
        .row(row),
        .col(col),
        .matrix_out(matrix_out)
    );

    integer r;
    integer c;

    task print_matrix;
        begin
            $display("\nFormatted matrix_out:");
            for (r = 0; r < 5; r = r + 1) begin
                $write("[");
                for (c = 0; c < 5; c = c + 1) begin
                    $write("%0d", $signed(matrix_out[((r * 5 + c) * 16) +: 16]));
                    if (c != 4) begin
                        $write("\t");
                    end
                end
                $write("]\n");
            end
            $display("");
        end
    endtask

    initial begin
        $dumpfile("grid_tb.vcd");
        $dumpvars(0, grid_tb);
        $display("time\tclk\trst\trow\tcol");
        $monitor("%0t\t%b\t%b\t%0d\t%0d", $time, clk, rst, row, col);

        // Reset
        rst = 1;
        row = 0;
        col = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // One packed pulse of input values.
        // row = {row_4, row_3, row_2, row_1, row_0}
        // col = {col_4, col_3, col_2, col_1, col_0}
        @(posedge clk);
        row = {8'sd5, 8'sd4, 8'sd3, 8'sd2, 8'sd1};
        col = {8'sd9, 8'sd8, 8'sd7, 8'sd6, 8'sd5};

        // Let the pulse propagate through the 5x5 grid.
        repeat (7) @(posedge clk);

        row = 40'd0;
        col = 40'd0;

        print_matrix();

        $display("Simulation finished.");
        #10;
        $finish;
    end

endmodule
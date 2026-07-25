`timescale 1ns/1ps
module PE_tb();
    reg signed [7:0] row;
    reg signed [7:0] col;
    
    reg clk;
    initial clk =0 ;
    always #5 clk = ~clk;
    reg rst;
    wire signed [7:0] row_out;
    wire signed [7:0] col_out;
    wire signed [15:0] out;

    processing_element uut(
        .clk(clk),
        .rst(rst),
        .row(row),
        .col(col),
        .row_out(row_out),
        .col_out(col_out),
        .out(out)
    );

    initial begin
        $dumpfile("PE_tb.vcd");
        $dumpvars(0, PE_tb);
        $display("time\tclk\trst\trow\tcol\trow_out\tcol_out\tout");
        $monitor("%0t\t%b\t%b\t%0d\t%0d\t%0d\t%0d\t%0d", $time, clk, rst, row, col, row_out, col_out, out);

        // Reset
        rst = 1;
        row = 0;
        col = 0;
        #10;
        rst = 0;
        #10;

        // Apply stimulus: several clock periods per input
        row = 8'sd3;  col = 8'sd2;   #20;
        row = -8'sd4; col = 8'sd5;   #20;
        row = 8'sd7;  col = -8'sd1;  #20;
        row = 8'sd15; col = 8'sd15;  #20;
        row = 8'sd0;  col = 8'sd0;   #40;

        $display("Simulation finished.");
        #10;
        $finish;
    end

endmodule
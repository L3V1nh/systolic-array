`timescale 1ps/1ns
module simple_tb ();
    logic [7:0] matrix_a[2][2];
    logic [7:0] matrix_b[2][2];
    logic [15:0] matrix_c[2][2];

    logic clk, rst,start, done;
    always #5 clk = ~clk;

    initial begin
    for (int i = 0; i < 2; i++) begin
        for (int j =0 ; j< 2 ;j++ ) begin
            matrix_a[i][j] = i + j;
            matrix_b[i][j] = i - j;
        end
    end

    $display("Matrix A");
    for (int i = 0; i < 2; i++) begin
        for (int j = 0; j < 2; j++)
            $write("%4d ", $signed(matrix_a[i][j]));
        $write("\n");
    end

    $display("Matrix B");
    for (int i = 0; i < 2; i++) begin
        for (int j = 0; j < 2; j++)
            $write("%4d ", $signed(matrix_b[i][j]));
        $write("\n");
    end
    end
    matrix_accel_simple uut(.*);

    initial begin
        rst=1;
        clk=0;
        start=0;
        #6 rst=0;
        start=1;
        @(posedge clk) #1 start=0;

        
        wait(done);
        $display("==================================");
        $display("Matrix C");

        for (int i = 0; i < 2; i++) begin
            for (int j = 0; j < 2; j++) begin
                $write("%0d ", matrix_c[i][j]);
            end
            $write("\n");
        end

        $display("==================================");
        $finish;
    end
endmodule
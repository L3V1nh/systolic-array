`timescale 1ns/1ps
module simple_tb ();
    localparam N = 3;
    localparam DATA_W = 8;
    localparam ACC_W = 16;
    logic [DATA_W-1:0] matrix_a[N][N];
    logic [DATA_W-1:0] matrix_b[N][N];
    logic [ACC_W-1:0] matrix_c[N][N];

    logic clk, rst,start, done;
    always #5 clk = ~clk;

    initial begin
    for (int i = 0; i < N; i++) begin
        for (int j =0 ; j< N ;j++ ) begin
            matrix_a[i][j] = i + j;
            matrix_b[i][j] = i - j;
        end
    end

    $display("Matrix A");
    for (int i = 0; i < N; i++) begin
        for (int j = 0; j < N; j++)
            $write("%4d ", $signed(matrix_a[i][j]));
        $write("\n");
    end

    $display("Matrix B");
    for (int i = 0; i < N; i++) begin
        for (int j = 0; j < N; j++)
            $write("%4d ", $signed(matrix_b[i][j]));
        $write("\n");
    end
    end
    matrix_accel_simple #(.N(N),
                    .DATA_W(DATA_W),
                    .ACC_W(ACC_W)) uut(.*);

    initial begin
        rst=1;
        clk=0;
        start=0;
        #6 rst=0;
        start=1;
        @(posedge clk) #1 start=0;

        
        wait(done);
        #20;
        $display("==================================");
        $display("Matrix C");

        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
                $write("%0d ", $signed(matrix_c[i][j]));
            end
            $write("\n");
        end

        $display("==================================");
        $finish;
    end
endmodule
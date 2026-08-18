`timescale 1ns/1ps
module axi_tb ();
    localparam N = 3;
    localparam DATA_W = 8;
    localparam ACC_W = 16;
    logic signed [DATA_W-1:0] matrix_a[N][N];
    logic signed [DATA_W-1:0] matrix_b[N][N];
    logic signed [ACC_W-1:0] matrix_c[N][N];

    axi4_lite_if axi();
    always #5 axi.clk = ~axi.clk;

    localparam logic [31:0] A_BASE = 32'h100;
    localparam logic [31:0] B_BASE = A_BASE + (N * N * 4);
    localparam logic [31:0] CONTROL = 32'h0;

    function automatic logic [31:0] matrix_addr(
        input logic [31:0] base,
        input int row,
        input int col
    );
        matrix_addr = base + (((row * N) + col) << 2);
    endfunction

    task automatic axi_write(
        input logic [31:0] addr,
        input logic [31:0] data
    );
        begin
            @(negedge axi.clk);
            axi.awaddr  = addr;
            axi.awvalid = 1'b1;
            axi.wdata   = data;
            axi.wvalid  = 1'b1;
            axi.bready  = 1'b1;

            fork
                begin
                    wait (axi.awready);
                    @(posedge axi.clk);
                    #1 axi.awvalid = 1'b0;
                end
                begin
                    wait (axi.wready);
                    @(posedge axi.clk);
                    #1 axi.wvalid = 1'b0;
                end
            join

            wait (axi.bvalid);
            @(posedge axi.clk);
            #1;
            axi.bready = 1'b0;
        end
    endtask

    task automatic write_matrix(
        input logic signed [DATA_W-1:0] matrix [N][N],
        input logic [31:0] base
    );
        begin
            for (int i = 0; i < N; i++) begin
                for (int j = 0; j < N; j++) begin
                    axi_write(matrix_addr(base, i, j), {{(32-DATA_W){1'b0}}, matrix[i][j]});
                end
            end
        end
    endtask

    initial begin
        for (int i = 0; i < N; i++) begin
            for (int j = 0; j < N; j++) begin
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

    axi4_lite_wrapper #(
        .N(N),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .axi(axi)
    );

    initial begin
        axi.rst = 1;
        axi.clk = 0;
        axi.awaddr = '0;
        axi.awvalid = 1'b0;
        axi.wdata = '0;
        axi.wvalid = 1'b0;
        axi.bready = 1'b0;
        axi.araddr = '0;
        axi.arvalid = 1'b0;
        axi.rready = 1'b0;
        #6 axi.rst = 0;

        write_matrix(matrix_a, A_BASE);
        write_matrix(matrix_b, B_BASE);

        axi_write(CONTROL, 32'h1);

        wait (dut.done_reg);
        #20;
        // $display("==================================");
        // $display("Matrix C");

        // for (int i = 0; i < N; i++) begin
        //     for (int j = 0; j < N; j++) begin
        //         $write("%0d ", $signed(dut.matrix_c[i][j]));
        //     end
        //     $write("\n");
        // end

        // $display("==================================");
        $finish;
    end
endmodule
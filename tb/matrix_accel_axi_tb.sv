`timescale 1ns/1ps
module axi_tb ();
    localparam N = 3;
    localparam DATA_W = 8;
    localparam ACC_W = 16;
    logic signed [DATA_W-1:0] matrix_a[N][N];
    logic signed [DATA_W-1:0] matrix_b[N][N];
    logic signed [ACC_W-1:0] matrix_c[N][N];

    logic clk, rst;
    always #5 clk = ~clk;

    logic [31:0] s_axi_awaddr;
    logic s_axi_awvalid;
    logic s_axi_awready;
    logic [31:0] s_axi_wdata;
    logic s_axi_wvalid;
    logic s_axi_wready;
    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid;
    logic s_axi_bready;
    logic [31:0] s_axi_araddr;
    logic s_axi_arvalid;
    logic s_axi_arready;
    logic [31:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid;
    logic s_axi_rready;

    localparam logic  [31:0] A_BASE = 32'h100;
    localparam logic  [31:0] B_BASE = A_BASE + (N * N * 4);
    localparam logic  [31:0] CONTROL = 32'h0;

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
            @(negedge clk);
            s_axi_awaddr  = addr;
            s_axi_awvalid  = 1'b1;
            s_axi_wdata    = data;
            s_axi_wvalid   = 1'b1;
            s_axi_bready   = 1'b1;

            wait (s_axi_awready && s_axi_wready);
            @(posedge clk);
            #1;
            s_axi_awvalid = 1'b0;
            s_axi_wvalid  = 1'b0;

            wait (s_axi_bvalid);
            @(posedge clk);
            #1;
            s_axi_bready = 1'b0;
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
    axi4_lite_wrapper #(.N(N),
                        .DATA_W(DATA_W),
                        .ACC_W(ACC_W)) dut (
                            .clk(clk),
                            .rst(rst),
                            .s_axi_awaddr(s_axi_awaddr),
                            .s_axi_awvalid(s_axi_awvalid),
                            .s_axi_awready(s_axi_awready),
                            .s_axi_wdata(s_axi_wdata),
                            .s_axi_wvalid(s_axi_wvalid),
                            .s_axi_wready(s_axi_wready),
                            .s_axi_bresp(s_axi_bresp),
                            .s_axi_bvalid(s_axi_bvalid),
                            .s_axi_bready(s_axi_bready),
                            .s_axi_araddr(s_axi_araddr),
                            .s_axi_arvalid(s_axi_arvalid),
                            .s_axi_arready(s_axi_arready),
                            .s_axi_rdata(s_axi_rdata),
                            .s_axi_rresp(s_axi_rresp),
                            .s_axi_rvalid(s_axi_rvalid),
                            .s_axi_rready(s_axi_rready)
                        );

    initial begin
        rst=1;
        clk=0;
        s_axi_awaddr  = '0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata   = '0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;
        s_axi_araddr  = '0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;
        #6 rst=0;

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
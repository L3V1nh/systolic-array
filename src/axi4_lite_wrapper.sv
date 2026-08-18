module axi4_lite_wrapper #(
    parameter N = 3,
    parameter DATA_W = 8,
    parameter ACC_W = 16
)(
    input  logic clk,
    input  logic rst,

    //==========================
    // Write Address Channel
    //==========================
    input  logic [31:0]       s_axi_awaddr,
    input  logic              s_axi_awvalid,
    output logic              s_axi_awready,

    //==========================
    // Write Data Channel
    //==========================
    input  logic [31:0]       s_axi_wdata,
    input  logic              s_axi_wvalid,
    output logic              s_axi_wready,

    //==========================
    // Write Response Channel
    //==========================
    output logic [1:0]        s_axi_bresp,
    output logic              s_axi_bvalid,
    input  logic              s_axi_bready,

    //==========================
    // Read Address Channel
    //==========================
    input  logic [31:0]       s_axi_araddr,
    input  logic              s_axi_arvalid,
    output logic              s_axi_arready,

    //==========================
    // Read Data Channel
    //==========================
    output logic [31:0]       s_axi_rdata,
    output logic [1:0]        s_axi_rresp,
    output logic              s_axi_rvalid,
    input  logic              s_axi_rready
);

    logic start_reg;
    logic done_reg;

    logic signed [DATA_W-1:0] matrix_a [N][N];
    logic signed [DATA_W-1:0] matrix_b [N][N];
    logic signed [ACC_W-1:0]  matrix_c [N][N];

    // Register Map
    localparam CONTROL = 32'h0;
    localparam STATUS = 32'h4;

    localparam int WORD_BYTES = 4;
    localparam int MAT_SIZE_BYTES = N*N*WORD_BYTES;

    localparam logic [31:0] A_BASE = 32'h100;
    localparam logic [31:0] B_BASE = A_BASE + MAT_SIZE_BYTES;
    localparam logic [31:0] C_BASE = B_BASE + MAT_SIZE_BYTES;

    assign s_axi_arready = 1'b0;
    assign s_axi_rdata    = 32'h0;
    assign s_axi_rresp    = 2'b00;
    assign s_axi_rvalid   = 1'b0;

    function automatic int addr_to_idx(
        input logic [31:0] addr,
        input logic [31:0] base
    );
    begin
        addr_to_idx = (addr - base) >> 2;
    end
    endfunction

    function automatic logic in_range(
        input logic [31:0] addr,
        input logic [31:0] base,
        input int size_bytes
    );
    begin
        in_range = (addr >= base) && (addr < (base + size_bytes));
    end
    endfunction
    
    // Write
    typedef enum logic [1:0] { 
        W_IDLE,
        W_COMMIT,
        W_RESP
    } Wstate_t;

    Wstate_t wstate, wstate_next;

    logic [31:0] waddr_reg, wdata_reg;
    logic aw_handshake, w_handshake;
    logic aw_done, w_done;
    assign aw_handshake = s_axi_awvalid && s_axi_awready;
    assign w_handshake  = s_axi_wvalid && s_axi_wready;

    always_ff @(posedge clk) begin: state_register
        if(rst) begin
            wstate <= W_IDLE;

            waddr_reg <= '0;
            wdata_reg <= '0;
            aw_done <= 1'b0;
            w_done <= 1'b0;

            for (int i = 0;i < N ; i++) begin
                for (int j = 0; j< N ;j++ ) begin
                    matrix_a[i][j] <= '0;
                    matrix_b[i][j] <= '0;
                end
            end

        end
        else begin
            wstate <= wstate_next;
            if (aw_handshake) begin
                waddr_reg <= s_axi_awaddr;
                aw_done <= 1'b1;
            end
            if (w_handshake) begin
                wdata_reg <= s_axi_wdata;
                w_done <= 1'b1;
            end
            if (wstate == W_RESP && s_axi_bready) begin
                aw_done <= 1'b0;
                w_done <= 1'b0;
            end
        end
    end

    always_comb begin : state_transition
        wstate_next = wstate;
        case (wstate)
            W_IDLE: begin
                if ((aw_done || aw_handshake) && (w_done || w_handshake))
                    wstate_next = W_COMMIT;
            end
            W_COMMIT: wstate_next = W_RESP;
            W_RESP:wstate_next = (s_axi_bready) ? W_IDLE:W_RESP;
        endcase
    end

    logic a_sel, b_sel, control_sel, invalid_addr;

    int idx;
    int row;
    int col;

    always_comb begin: datapath

    control_sel = (waddr_reg == CONTROL);
    a_sel = in_range(waddr_reg, A_BASE, MAT_SIZE_BYTES);
    b_sel = in_range(waddr_reg, B_BASE, MAT_SIZE_BYTES);
    invalid_addr = !(control_sel || a_sel || b_sel);

    idx = 0;
    if (a_sel)
        idx = addr_to_idx(waddr_reg, A_BASE);
    else if (b_sel)
        idx = addr_to_idx(waddr_reg, B_BASE);

    row = idx / N;
    col = idx % N;

    s_axi_awready = (wstate == W_IDLE) && !aw_done;
    s_axi_wready  = (wstate == W_IDLE) && !w_done;
    s_axi_bvalid  = 1'b0;
    s_axi_bresp   = 2'b00; // OKAY

    case (wstate)

        W_IDLE: begin
        end

        W_COMMIT: begin
        end

        W_RESP: begin
            s_axi_bvalid = 1'b1;

            if (invalid_addr)
                s_axi_bresp = 2'b11; // DECERR
            else
                s_axi_bresp = 2'b00; // OKAY
        end

        default: begin
        end

    endcase
    end

    always_ff @(posedge clk) begin : matrix_write

    if (rst) begin
        start_reg <= 1'b0;
    end
    else begin
        if (wstate == W_COMMIT) begin

            start_reg <= control_sel ? wdata_reg[0] : 1'b0;

            if (a_sel)
                matrix_a[row][col]
                    <= wdata_reg[DATA_W-1:0];

            else if (b_sel)
                matrix_b[row][col]
                    <= wdata_reg[DATA_W-1:0];

        end
        else begin
            start_reg <= 1'b0;
        end

    end
end
matrix_accel #(.N(N),
                   .DATA_W(DATA_W),
                   .ACC_W(ACC_W)) accel (
                    .clk,
                    .rst,
                    .matrix_a,
                    .matrix_b,
                    .matrix_c,
                    .start(start_reg),
                    .done(done_reg)
                   );
endmodule
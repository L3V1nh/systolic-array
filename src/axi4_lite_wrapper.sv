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

    localparam int MAT_SIZE_BYTES = N*N*4;

    localparam logic [31:0] A_BASE = 32'h100;
    localparam logic [31:0] B_BASE = A_BASE + MAT_SIZE_BYTES;
    localparam logic [31:0] C_BASE = B_BASE + MAT_SIZE_BYTES;

    function automatic int addr_to_idx(
        input logic [31:0] addr,
        input logic [31:0] base
    );
    begin
        addr_to_idx = (addr - base) >> 2;
    end
    endfunction
    
    // Write
    typedef enum logic [1:0] { 
        W_IDLE,
        WRITE,
        W_RESP
    } Wstate_t;

    Wstate_t wstate, wstate_next;

    logic [31:0] waddr_reg, wdata_reg;
    assign aw_handshake = s_axi_awvalid&&s_axi_awready;
    assign w_handshake = s_axi_wvalid&&s_axi_wready
    logic aw_received, w_received;

    always_ff @(posedge clk) begin
        if(rst) begin
            wstate <= IDLE;

            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
            start_reg <= 1'b0;

            for (int i = 0;i < N ; i++) begin
                for (int j = 0; j< N ;j++ ) begin
                    matrix_a[i][j] <= '0;
                    matrix_b[i][j] <= '0;
                    matrix_c[i][j] <= '0;
                end
            end

        end
        else begin
            wstate <= wstate_next;
            if (aw_handshake) begin
                waddr_reg <= s_axi_awaddr;
                aw_received <= 1;
            end
            if (w_handshake) begin
                wdata_reg <= s_axi_wdata;
                w_received <= 1;
            end
        end
    end

    assign s_axi_awready = (wstate == IDLE) && !aw_received;
    assign s_axi_wready  = (wstate == IDLE) && !w_received;

    

    always_comb begin : state_transition
        wstate_next = wstate;
        case (wstate)
            IDLE: wstate_next = (aw_received && w_received) ? WRITE:IDLE;
            WRITE: wstate_next = W_RESP;
            W_RESP:wstate_next = (s_axi_bready) ? IDLE:W_RESP;
        endcase
    end

    logic a_sel, b_sel, invalid_addr;

    int idx;
    int row;
    int col;
    always_comb begin : addr_decode

        a_sel = (waddr_reg >= A_BASE) &&
                (waddr_reg < A_BASE + MAT_SIZE_BYTES);

        b_sel = (waddr_reg >= B_BASE) &&
                (waddr_reg < B_BASE + MAT_SIZE_BYTES);

        invalid_addr = !(a_sel || b_sel);

        idx = 0;
        row = 0;
        col = 0;

        if (a_sel) begin
            idx = addr_to_idx(waddr_reg, A_BASE);
        end
        else if (b_sel) begin
            idx = addr_to_idx(waddr_reg, B_BASE);
        end

        row = idx / N;
        col = idx % N;

    end

    always_comb begin: datapath

    s_axi_bvalid = 1'b0;
    s_axi_bresp  = 2'b00; // OKAY

    case (wstate)

        IDLE: begin
        end

        WRITE: begin
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
        for (int i = 0;i < N ; i++) begin
                for (int j = 0; j< N ;j++ ) begin
                    matrix_a[i][j] <= '0;
                    matrix_b[i][j] <= '0;
                    matrix_c[i][j] <= '0;
                end
            end
    end
    else begin

        wstate <= wstate_next;

        if (wstate == WRITE) begin

            if (a_sel)
                matrix_a[row][col]
                    <= wdata_reg[DATA_W-1:0];

            else if (b_sel)
                matrix_b[row][col]
                    <= wdata_reg[DATA_W-1:0];

        end

    end

end
endmodule
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


    localparam CONTROL = ;
    
endmodule
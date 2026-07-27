module processing_element #(
    parameter DATA_W = 8,
    parameter ACC_W = 16
)(
    input wire clk,
    input wire rst,
    input wire signed [DATA_W-1:0] row,
    input wire signed [DATA_W-1:0] col,
    output reg signed [DATA_W-1:0] row_out,
    output reg signed [DATA_W-1:0] col_out,
    output reg signed [ACC_W-1:0] out
);

    wire signed [2*DATA_W-1:0] product;

    BoothMultiplier #(.DATA_W(DATA_W)) mul (
    .multiplicand(row),
    .multiplier(col),
    .product(product)
    );
    always @(posedge clk) begin
    if (rst) begin
        out     <= {ACC_W{1'b0}};
        row_out <= {DATA_W{1'b0}};
        col_out <= {DATA_W{1'b0}};
    end else begin
        out     <= out + product;
        row_out <= row;
        col_out <= col;
    end
    end

endmodule
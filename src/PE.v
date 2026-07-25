module processing_element #(
    parameter WIDTH = 8
)(
    input wire clk,
    input wire rst,
    input wire signed [WIDTH-1:0] row,
    input wire signed [WIDTH-1:0] col,
    output reg signed [WIDTH-1:0] row_out,
    output reg signed [WIDTH-1:0] col_out,
    output reg signed [2*WIDTH-1:0] out
);

    wire signed [2*WIDTH-1:0] product;

    BoothMultiplier #(.WIDTH(WIDTH)) mul (
    .multiplicand(row),
    .multiplier(col),
    .product(product)
    );
    always @(posedge clk) begin
    if (rst) begin
        out     <= {2*WIDTH{1'b0}};
        row_out <= {WIDTH{1'b0}};
        col_out <= {WIDTH{1'b0}};
    end else begin
        out     <= out + product;
        row_out <= row;
        col_out <= col;
    end
    end

endmodule
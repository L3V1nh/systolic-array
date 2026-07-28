module BoothMultiplier #(
    parameter DATA_W = 8
) (
    input  wire signed [DATA_W-1:0]   multiplicand,
    input  wire signed [DATA_W-1:0]   multiplier,
    output reg  signed [2*DATA_W-1:0] product
);

    reg signed [DATA_W-1:0] A;
    reg signed [DATA_W-1:0] Q;
    reg                    Q_1;
    reg signed [DATA_W-1:0] M;

    always @* begin
        A   = {DATA_W{1'b0}};
        M   = multiplicand;
        Q   = multiplier;
        Q_1 = 1'b0;

        repeat (DATA_W) begin
            case ({Q[0], Q_1})
                2'b01: A = A + M;   // A = A + M, natural DATA_W-bit signed add
                2'b10: A = A - M;   // A = A - M
                default: ;          // 00 or 11: no operation
            endcase

            {A, Q, Q_1} = {A[DATA_W-1], A, Q, Q_1} >>> 1;
        end

        product = {A, Q};
    end

endmodule
module systolic_grid #(
    parameter int N = 5,
    parameter int DATA_W = 8,
    parameter int ACC_W = 16
)(
    input logic clk,
    input logic rst,

    input logic signed [DATA_W-1:0] row [N],
    input logic signed [DATA_W-1:0] col [N],

    output logic signed [ACC_W-1:0] matrix_out [N][N]
);


    wire signed [DATA_W-1:0] h_bus [N-1:0][N:0];
    wire signed [DATA_W-1:0] v_bus [N:0][N-1:0];

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin
            assign h_bus[i][0] = row[i]; 
            assign v_bus[0][i]   = col[i];
        end
    endgenerate

    genvar r, c;
    generate
        for (r = 0; r < N; r = r + 1) begin 
            for (c = 0; c < N; c = c + 1) begin
                
                processing_element #(
                        .DATA_W(DATA_W),
                        .ACC_W(ACC_W)
                    ) pe (
                    .clk,
                    .rst,
                    .row(h_bus[r][c]),      
                    .col(v_bus[r][c]),        
                    .row_out(h_bus[r][c+1]),
                    .col_out(v_bus[r+1][c]),  
                    .out(matrix_out[r][c])        
                );
            end
        end
    endgenerate
endmodule
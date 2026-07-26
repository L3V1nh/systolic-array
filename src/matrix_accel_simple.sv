import matrix_pkg::*
module matrix_accel_simple #(
    parameter N = matrix_pkg::N,
    parameter DATA_W = matrix_pkg::DATA_W,
    parameter ACC_W = matrix_pkg::ACC_W
)(
    input logic clk,
    input logic rst,
    input logic start,

    input logic signed [DATA_W-1:0] matrix_a [N][N],
    input logic signed [DATA_W-1:0] matrix_b [N][N],

    output logic signed [ACC_W-1:0] matrix_c [N][N],
    output logic done
);
    logic signed [DATA_W-1:0] row [N];
    logic signed [DATA_W-1:0] row_next [N];
    logic signed [DATA_W-1:0] col [N];
    logic signed [DATA_W-1:0] col_next [N];

    state_t state, state_next;
    always_ff @( posedge clk ) begin : registers
        if(rst) begin
            for (int i = 0; i < N ; i++) begin
                for (int j = 0; j < N ; j++) begin
                    matrix_c[i][j] <= 0;
                end
            end
            done <= 0;
            state <= IDLE;
        end
        else begin
            row <= row_next;
            col <= col_next;
            state <= state_next;
        end
    end

    logic calc_done;
    assign calc_done = (feed_cnt == (2*N-1));
    always_comb begin : state_logic
        case (state)
            IDLE: if(start) state_next = FEED;
            FEED: if(calc_done) state_next = DONE;
            DONE: state_next =  (start)? FEED:IDLE;
            default:
        endcase
    end

    int feed_cnt;
    int feed_cnt_next;
    int row_idx;
    int col_idx;

    always_comb begin : datapath
    feed_cnt_next = feed_cnt;

    row_next = row;
    col_next = col;

    case (state)
        IDLE: begin

            feed_cnt_next = 0;

            for (int i = 0; i < N; i++) begin
                row_next[i] = '0;
                col_next[i] = '0;
            end

        end

        FEED: begin

            for (int i = 0; i < N; i++) begin

                row_idx = feed_cnt - i;

                if (row_idx >= 0 && row_idx < N)
                    row_next[i] = matrix_a[i][row_idx];
                else
                    row_next[i] = '0;


                col_idx = feed_cnt - i;

                if (col_idx >= 0 && col_idx < N)
                    col_next[i] = matrix_b[col_idx][i];
                else
                    col_next[i] = '0;

            end

            feed_cnt_next = feed_cnt + 1;

        end
        DONE: begin

            for (int i = 0; i < N; i++) begin
                row_next[i] = '0;
                col_next[i] = '0;
            end

        end

    endcase

    end
    
    assign done = (state==DONE);
endmodule
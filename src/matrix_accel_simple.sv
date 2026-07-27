module matrix_accel_simple #(
    parameter N = 2,
    parameter DATA_W = 8,
    parameter ACC_W = 16
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

    int feed_cnt;
    int feed_cnt_next;
    
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        FEED,
        DONE
    } state_t;

    state_t state, state_next;
    always_ff @( posedge clk ) begin : registers
        if(rst) begin
            state <= IDLE;
            feed_cnt <= 0;
            for (int i = 0; i < N; i++) begin
                row[i] <= '0;
                col[i] <= '0;
            end
        end
        else begin
            row <= row_next;
            col <= col_next;
            state <= state_next;
            feed_cnt <= feed_cnt_next;
        end
    end

    logic calc_done;
    assign calc_done = (feed_cnt == (2*N-1));
    always_comb begin : state_logic
        state_next = state;
        case (state)
            IDLE: if(start) state_next = FEED;
            FEED: if(calc_done) state_next = DONE;
            DONE: state_next =  (start)? FEED:IDLE;
        endcase
    end

    
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

    systolic_grid #(.N(2),
                    .DATA_W(8),
                    .ACC_W(16)) grid(
                        .clk,
                        .rst,
                        .row,
                        .col,
                        .matrix_out(matrix_c)
                    );
endmodule
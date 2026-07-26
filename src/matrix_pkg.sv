package matrix_pkg;

    parameter int N       = 5;
    parameter int DATA_W  = 8;
    parameter int ACC_W   = 16;

    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        FEED,
        DONE
    } state_t;

endpackage
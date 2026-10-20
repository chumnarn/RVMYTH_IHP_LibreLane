// RVMYTH integration wrapper for IHP SG13G2.
// Upstream core reset is active high; the chip pad reset is active low.
`default_nettype none
module chip_core (
    input  logic       clk,
    input  logic       rst_n,
    output logic [9:0] result
);
    core i_rvmyth_core (
        .clk   (clk),
        .reset (~rst_n),
        .out   (result)
    );
endmodule
`default_nettype wire

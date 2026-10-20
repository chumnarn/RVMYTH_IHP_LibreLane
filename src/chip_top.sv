// Full-chip padframe for RVMYTH, based on chumnarn/ihp-sg13g2-librelane-template.
`default_nettype none
module chip_top (
`ifdef USE_POWER_PINS
    inout wire IOVDD,
    inout wire IOVSS,
    inout wire VDD,
    inout wire VSS,
`endif
    inout wire clk_PAD,
    inout wire rst_n_PAD,
    inout wire [9:0] result_PAD
);
    wire clk_core;
    wire rst_n_core;
    wire [9:0] result_core;

//    sg13g2_IOPadIn clk_pad (
//`ifdef USE_POWER_PINS
//        .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS),
//`endif
//        .p2c(clk_core), .pad(clk_PAD)
//    );
 
sg13g2_IOPadIn clk_pad (
`ifdef USE_POWER_PINS
    .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS),
`endif
    .pad(clk_PAD),
    .p2c(clk_core)
);


   sg13g2_IOPadIn rst_n_pad (
`ifdef USE_POWER_PINS
        .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS),
`endif
        .p2c(rst_n_core), .pad(rst_n_PAD)
    );

    for (genvar i = 0; i < 10; i++) begin : result_pads
        sg13g2_IOPadOut30mA result_pad (
`ifdef USE_POWER_PINS
            .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS),
`endif
            .c2p(result_core[i]), .pad(result_PAD[i])
        );
    end

(* keep = 1 *)    sg13g2_IOPadIOVdd iovdd_pad (
`ifdef USE_POWER_PINS
        .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS)
`endif
    );

(* keep = 1 *)    sg13g2_IOPadIOVss iovss_pad (
`ifdef USE_POWER_PINS
        .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS)
`endif
    );

(* keep = 1 *)    sg13g2_IOPadVdd vdd_pad (
`ifdef USE_POWER_PINS
        .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS)
`endif
    );

(* keep = 1 *)    sg13g2_IOPadVss vss_pad (
`ifdef USE_POWER_PINS
        .iovdd(IOVDD), .iovss(IOVSS), .vdd(VDD), .vss(VSS)
`endif
    );

    (* keep *) chip_core i_chip_core (
        .clk(clk_core), .rst_n(rst_n_core), .result(result_core)
    );
endmodule
`default_nettype wire

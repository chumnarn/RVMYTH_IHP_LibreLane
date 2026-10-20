`timescale 1ns/1ps
module tb_rvmyth_core;
  logic clk = 0;
  logic reset = 1;
  wire [9:0] out;
  core dut (.clk(clk), .reset(reset), .out(out));
  always #5 clk = ~clk;
  initial begin
    $dumpfile("rvmyth_core.vcd");
    $dumpvars(0, tb_rvmyth_core);
    repeat (4) @(negedge clk);
    reset = 0;
    repeat (500) @(negedge clk);
    $display("RVMyth result bus = 0x%03x (%0d)", out, out);
    $finish;
  end
endmodule

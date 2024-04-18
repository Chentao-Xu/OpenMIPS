`include "../src/defines.v"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/03/12 21:59:15
// Design Name: 
// Module Name: openmips_min_sopc_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module openmips_min_sopc_tb ();
  reg CLOCK_50;
  reg rst;

  initial begin
    CLOCK_50 = 1'b0;
    forever #10 CLOCK_50 = ~CLOCK_50;
  end

  initial begin
    rst = `RstEnable;
    #195 rst = `RstDisable;
    #100000 $stop;
  end

  //实例化最小SOPC
  openmips_min_sopc openmips_min_sopc0 (
      .clk(CLOCK_50),
      .rst(rst)
  );

endmodule

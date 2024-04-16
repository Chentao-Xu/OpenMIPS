`include "defines.v"
module ex_mem (
    input wire rst,
    input wire clk,

    // 执行阶段的信息
    input wire [`RegAddrBus] ex_wd,
    input wire ex_wreg,
    input wire [`RegBus] ex_wdata,
    input wire ex_whilo,
    input wire [`RegBus] ex_hi,
    input wire [`RegBus] ex_lo,
    input wire [`RegBus] ex_mem_addr,
    input wire [`RegBus] ex_reg2,
    input wire [`AluOpBus] ex_aluop,

    // 送到访存阶段的信息
    output reg [`RegAddrBus] mem_wd,
    output reg mem_wreg,
    output reg [`RegBus] mem_wdata,
    output reg mem_whilo,
    output reg [`RegBus] mem_hi,
    output reg [`RegBus] mem_lo,
    output reg [`RegBus] mem_mem_addr,
    output reg [`RegBus] mem_reg2,
    output reg [`AluOpBus] mem_aluop
);

  always @(posedge clk) begin
    if (rst == `RstEnable) begin
      mem_wd <= `NOPRegAddr;
      mem_wdata <= `ZeroWord;
      mem_wreg <= `WriteDisable;
      mem_hi <= `ZeroWord;
      mem_lo <= `ZeroWord;
      mem_whilo <= `WriteDisable;
      mem_aluop <= `EXE_NOP_OP;
      mem_mem_addr <= `ZeroWord;
      mem_reg2 <= `ZeroWord;
    end else begin
      mem_wd <= ex_wd;
      mem_wdata <= ex_wdata;
      mem_wreg <= ex_wreg;
      mem_hi <= ex_hi;
      mem_lo <= ex_lo;
      mem_whilo <= ex_whilo;
      mem_aluop <= ex_aluop;
      mem_mem_addr <= ex_mem_addr;
      mem_reg2 <= ex_reg2;
    end
  end

endmodule

`include "defines.v"
module mem (
    input wire rst,

    // 来自执行阶段的信息
    input wire [`RegAddrBus] wd_i,
    input wire wreg_i,
    input wire [`RegBus] wdata_i,
    input wire whilo_i,
    input wire [`RegBus] hi_i,
    input wire [`RegBus] lo_i,
    input wire [`AluOpBus] aluop_i,
    input wire [`RegBus] mem_addr_i,
    input wire [`RegBus] reg2_i,

    // 来自数据存储器DRAM的信息
    input wire [`RegBus] mem_data_i,

    // 访存阶段的结果
    output reg [`RegAddrBus] wd_o,
    output reg wreg_o,
    output reg [`RegBus] wdata_o,
    output reg whilo_o,
    output reg [`RegBus] hi_o,
    output reg [`RegBus] lo_o,

    //送到DRAM的数据
    output reg [`RegBus] mem_addr_o,
    output wire mem_we_o,
    output reg [3:0] mem_sel_o,
    output reg [`RegBus] mem_data_o,
    output reg mem_ce_o
);

  wire [`RegBus] zero32;
  reg mem_we;

  // DRAM的读写信号
  assign mem_we_o = mem_we;

  assign zero32   = `ZeroWord;

  always @(*) begin
    if (rst == `RstEnable) begin
      wd_o = `NOPRegAddr;
      wreg_o = `WriteDisable;
      wdata_o = `ZeroWord;
      hi_o = `ZeroWord;
      lo_o = `ZeroWord;
      whilo_o = `WriteDisable;
      mem_addr_o = `ZeroWord;
      mem_we = `WriteDisable;
      mem_sel_o = 4'b0000;
      mem_data_o = `ZeroWord;
      mem_ce_o = `ChipDisable;
    end else begin
      wd_o = wd_i;
      wreg_o = wreg_i;
      wdata_o = wdata_i;
      hi_o = hi_i;
      lo_o = lo_i;
      whilo_o = whilo_i;
      mem_we = `WriteDisable;
      mem_addr_o = `ZeroWord;
      mem_sel_o = 4'b1111;
      mem_ce_o = `ChipDisable;

      case (aluop_i)
        `EXE_LB_OP: begin  // lb指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteDisable;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              wdata_o   = {{24{mem_data_i[7]}}, mem_data_i[7:0]};
              mem_sel_o = 4'b0001;
            end
            2'b01: begin
              wdata_o   = {{24{mem_data_i[15]}}, mem_data_i[15:8]};
              mem_sel_o = 4'b0010;
            end
            2'b10: begin
              wdata_o   = {{24{mem_data_i[23]}}, mem_data_i[23:16]};
              mem_sel_o = 4'b0100;
            end
            2'b11: begin
              wdata_o   = {{24{mem_data_i[31]}}, mem_data_i[31:24]};
              mem_sel_o = 4'b1000;
            end
            default: begin
              wdata_o = `ZeroWord;
            end
          endcase
        end

        `EXE_LBU_OP: begin  //lbu指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteDisable;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              wdata_o   = {{24{1'b0}}, mem_data_i[7:0]};
              mem_sel_o = 4'b0001;
            end
            2'b01: begin
              wdata_o   = {{24{1'b0}}, mem_data_i[15:8]};
              mem_sel_o = 4'b0010;
            end
            2'b10: begin
              wdata_o   = {{24{1'b0}}, mem_data_i[23:16]};
              mem_sel_o = 4'b0100;
            end
            2'b11: begin
              wdata_o   = {{24{1'b0}}, mem_data_i[31:24]};
              mem_sel_o = 4'b1000;
            end
            default: begin
              wdata_o = `ZeroWord;
            end
          endcase
        end

        `EXE_LH_OP: begin  // lh指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteDisable;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              wdata_o   = {{16{mem_data_i[15]}}, mem_data_i[15:0]};
              mem_sel_o = 4'b0011;
            end
            2'b10: begin
              wdata_o   = {{16{mem_data_i[31]}}, mem_data_i[31:16]};
              mem_sel_o = 4'b1100;
            end
            default: begin
              wdata_o = `ZeroWord;
            end
          endcase
        end

        `EXE_LHU_OP: begin  // lhu指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteDisable;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              wdata_o   = {{16{1'b0}}, mem_data_i[15:0]};
              mem_sel_o = 4'b0011;
            end
            2'b10: begin
              wdata_o   = {{16{1'b0}}, mem_data_i[31:16]};
              mem_sel_o = 4'b1100;
            end
            default: begin
              wdata_o = `ZeroWord;
            end
          endcase
        end

        `EXE_LW_OP: begin  // lw指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteDisable;
          wdata_o = mem_data_i;
          mem_sel_o = 4'b1111;
          mem_ce_o = `ChipEnable;
        end

        // LWL和LWR等指令注意切换为小端法

        `EXE_LWL_OP: begin  // lwl指令
          mem_addr_o = {mem_addr_i[31:2], 2'b00};  // 为了对齐
          mem_we = `WriteDisable;
          mem_sel_o = 4'b1111;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              wdata_o = {mem_data_o[7:0], reg2_i[23:0]};
            end
            2'b01: begin
              wdata_o = {mem_data_o[15:0], reg2_i[15:0]};
            end
            2'b10: begin
              wdata_o = {mem_data_o[23:0], reg2_i[7:0]};
            end
            2'b11: begin
              wdata_o = mem_data_i[31:0];
            end
            default: begin
              wdata_o = `ZeroWord;
            end
          endcase
        end

        `EXE_LWR_OP: begin  // lwr指令
          mem_addr_o = {mem_addr_i[31:2], 2'b00};
          mem_we = `WriteDisable;
          mem_sel_o = 4'b1111;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              wdata_o = mem_data_i[31:0];
            end
            2'b01: begin
              wdata_o = {reg2_i[31:24], mem_data_o[31:8]};
            end
            2'b10: begin
              wdata_o = {reg2_i[31:16], mem_data_o[31:16]};
            end
            2'b11: begin
              wdata_o = {reg2_i[31:8], mem_data_o[31:24]};
            end
            default: begin
            end
          endcase
        end

        `EXE_SB_OP: begin  // sb指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteEnable;
          mem_data_o = {4{reg2_i[7:0]}};
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o = 4'b0001;
            end
            2'b01: begin
              mem_sel_o = 4'b0010;
            end
            2'b10: begin
              mem_sel_o = 4'b0100;
            end
            2'b11: begin
              mem_sel_o = 4'b1000;
            end
            default: begin
              mem_sel_o = 4'b0000;
            end
          endcase
        end

        `EXE_SH_OP: begin  //sh指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteEnable;
          mem_data_o = {reg2_i[15:0], reg2_i[15:0]};
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o = 4'b0011;
            end
            2'b10: begin
              mem_sel_o = 4'b1100;
            end
            default: begin
              mem_sel_o = 4'b0000;
            end
          endcase
        end

        `EXE_SW_OP: begin  //sw指令
          mem_addr_o = mem_addr_i;
          mem_we = `WriteEnable;
          mem_data_o = reg2_i;
          mem_sel_o = 4'b1111;
          mem_ce_o = `ChipEnable;
        end

        `EXE_SWL_OP: begin
          mem_addr_o = {mem_addr_i[31:2], 2'b00};
          mem_we = `WriteEnable;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o  = 4'b0001;
              mem_data_o = {zero32[23:0], reg2_i[31:24]};
            end
            2'b01: begin
              mem_sel_o  = 4'b0011;
              mem_data_o = {zero32[15:0], reg2_i[31:16]};
            end
            2'b10: begin
              mem_sel_o  = 4'b0111;
              mem_data_o = {zero32[7:0], reg2_i[31:8]};
            end
            2'b11: begin
              mem_sel_o  = 4'b1111;
              mem_data_o = reg2_i[31:0];
            end
            default: begin
              mem_sel_o = 4'b0000;
            end

          endcase
        end

        `EXE_SWR_OP: begin
          mem_addr_o = {mem_addr_i[31:2], 2'b00};
          mem_we = `WriteEnable;
          mem_ce_o = `ChipEnable;
          case (mem_addr_i[1:0])
            2'b00: begin
              mem_sel_o  = 4'b1111;
              mem_data_o = reg2_i[31:0];
            end
            2'b01: begin
              mem_sel_o  = 4'b1110;
              mem_data_o = {reg2_i[23:0], zero32[7:0]};
            end
            2'b10: begin
              mem_sel_o  = 4'b1100;
              mem_data_o = {reg2_i[15:0], zero32[15:0]};
            end
            2'b11: begin
              mem_sel_o  = 4'b1000;
              mem_data_o = {reg2_i[7:0], zero32[23:0]};
            end
            default: begin
              mem_sel_o = 4'b0000;
            end
          endcase
        end

        default: begin
        end

      endcase
    end
  end

endmodule

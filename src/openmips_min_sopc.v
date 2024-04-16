`include "defines.v"
module openmips_min_sopc (
    input wire clk,
    input wire rst
);

  // 连接指令存储器
  wire [`InstAddrBus] inst_addr;
  wire [`InstBus] inst;
  wire rom_ce;

  // 连接数据存储器
  wire [`DataBus] ram_data_i;
  wire [`DataBus] ram_data_o;
  wire [`DataAddrBus] ram_addr;
  wire ram_we;
  wire ram_ce;
  wire [3:0] ram_sel;

  // 例化处理器OpenMIPS

  openmips openmips0 (
      .clk(clk),
      .rst(rst),
      .rom_addr_o(inst_addr),
      .rom_data_i(inst),
      .rom_ce_o(rom_ce),

      .ram_data_i(ram_data_i),
      .ram_addr_o(ram_addr),
      .ram_data_o(ram_data_o),
      .ram_we_o  (ram_we),
      .ram_sel_o (ram_sel),
      .ram_ce_o  (ram_ce)
  );

  // 例化指令存储器ROM
  inst_rom inst_rom0 (
      .ce  (rom_ce),
      .addr(inst_addr),
      .inst(inst)
  );

  // 例化数据存储器DRAM
  data_ram data_ram_0 (
      .clk   (clk),
      .ce    (ram_ce),
      .we    (ram_we),
      .sel   (ram_sel),
      .data_i(ram_data_i),
      .addr  (ram_addr),
      .data_o(ram_data_o)
  );


endmodule

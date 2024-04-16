`include "defines.v"
module ex (
    input wire rst,

    //译码阶段送到执行阶段的信息
    input wire [`AluSelBus] alusel_i,
    input wire [`AluOpBus] aluop_i,
    input wire [`RegBus] reg1_i,
    input wire [`RegBus] reg2_i,
    input wire wreg_i,
    input wire [`RegAddrBus] wd_i,

    //HILO模块给出的数值
    input wire [`RegBus] hi_i,
    input wire [`RegBus] lo_i,

    // 回写阶段的指令是否要写HI、LO，用于检测HI、LO寄存器带来的数据相关问题
    input wire [`RegBus] wb_hi_i,
    input wire [`RegBus] wb_lo_i,
    input wire wb_whilo_i,

    // 访存阶段的指令是否要写HI、LO，用于检测HI、LO寄存器带来的数据相关问题
    input wire [`RegBus] mem_hi_i,
    input wire [`RegBus] mem_lo_i,
    input wire mem_whilo_i,

    // 延迟槽
    input wire is_in_delayslot_i,
    input wire [`RegBus] link_address_i,
    
    // 当前处于执行阶段的指令
    input wire [`RegBus] inst_i,

    // 处于执行阶段的指令对HI、LO寄存器的写操作请求
    output reg [`RegBus] hi_o,
    output reg [`RegBus] lo_o,
    output reg whilo_o,

    // 执行阶段运算子类型
    output reg [`AluOpBus] aluop_o,

    // 加载存储指令的地址
    output reg [`RegBus] mem_addr_o,

    // 存储指令要存储的数据或者lwl, lwr要加载到的目标寄存器的原始数据
    output reg [`RegBus] reg2_o,

    //执行的结果
    output reg [`RegAddrBus] wd_o,
    output reg wreg_o,
    output reg [`RegBus] wdata_o
);

  reg [`RegBus] logicout;  // 保存逻辑运算结果
  reg [`RegBus] shiftres;  // 保存移位运算结果
  reg [`RegBus] moveres;  // 移动操作的结果
  reg [`RegBus] HI;  // 保存HI寄存器的最新值
  reg [`RegBus] LO;  // 保存LO寄存器的最新值

  // 新定义了一些变量
  wire ov_sum;  // 保存溢出情况
  wire reg1_eq_reg2;  // 第一个操作数是否等于第二个操作数
  wire reg1_lt_reg2;  // 第一个操作数是否小于第二个操作数
  reg [`RegBus] arithmeticres;  // 保存算术运算的结果
  wire [`RegBus] reg2_i_mux;  // 保 存 输 入 的 第 二 个 操 作 数reg2_i的补码
  wire [`RegBus] reg1_i_not;  // 保 存 输 入 的 第 一 个 操 作 数reg1_i取反后的值
  wire [`RegBus] result_sum;  // 保存加法结果
  wire [`RegBus] opdata1_mult;  // 乘法操作中的被乘数
  wire [`RegBus] opdata2_mult;  // 乘法操作中的乘数
  wire [`DoubleRegBus] hilo_temp;  // 临时保存乘法结果，宽度为64位
  reg [`DoubleRegBus] mulres;  // 保存乘法结果，宽度为64位

  // 传到访存阶段确定加载存储类型
  assign aluop_o = aluop_i;

  // 存储加载指令的存储器地址 reg1_i为base, inst[15:0]有符号扩展 
  assign mem_addr_o = reg1_i + {{16{inst_i[15]}},inst_i[15:0]};

  assign reg2_o = reg2_i;

  /******************************************************************
** 取得最新的HILO寄存器值**
*******************************************************************/

  always @(*) begin
    if (rst == `RstEnable) begin
      {HI, LO} = {`ZeroWord, `ZeroWord};
    end else if (mem_whilo_i == `WriteEnable) begin
      {HI, LO} = {mem_hi_i, mem_lo_i};
    end else if (wb_whilo_i == `WriteEnable) begin
      {HI, LO} = {wb_hi_i, wb_lo_i};
    end else begin
      {HI, LO} = {hi_i, lo_i};
    end
  end

  /******************************************************************
** 第一段：计算以下5个变量的值**
*******************************************************************/

  //（1）如果是减法或者有符号比较运算，那么reg2_i_mux等于第二个操作数reg2_i的补码
  // 减法——第二个数取反的加法，有符号数比较——两个数相减
  // 否则reg2_i_mux就等于第二个操作数reg2_i
  assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_SUBU_OP) || (aluop_i == `EXE_SLT_OP)) ?
                      (~reg2_i)+1 : reg2_i;

  //（2）分三种情况：
  // A．如果是加法运算，此时reg2_i_mux就是第二个操作数reg2_i，
  // 所以result_sum就是加法运算的结果
  // B．如果是减法运算，此时reg2_i_mux是第二个操作数reg2_i的补码，
  // 所以result_sum就是减法运算的结果
  // C．如果是有符号比较运算，此时reg2_i_mux也是第二个操作数reg2_i
  // 的补码，所以result_sum也是减法运算的结果，可以通过判断减法
  // 的结果是否小于零，进而判断第一个操作数reg1_i是否小于第二个操
  // 作数reg2_i
  assign result_sum = reg1_i + reg2_i_mux;

  //（3）计算是否溢出，加法指令（add和addi）、减法指令（sub）执行的时候，
  // 需要判断是否溢出，满足以下两种情况之一时，有溢出：
  // A．reg1_i为正数，reg2_i_mux为正数，但是两者之和为负数
  // B．reg1_i为负数，reg2_i_mux为负数，但是两者之和为正数
  assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

  //（4）计算操作数1是否小于操作数2，分两种情况：
  // A．aluop_i为EXE_SLT_OP表示有符号比较运算，此时又分3种情况
  // A1．reg1_i为负数、reg2_i为正数，显然reg1_i小于reg2_i
  // A2．reg1_i为正数、reg2_i为正数，并且reg1_i减去reg2_i的值小于0
  // （即result_sum为负），此时也有reg1_i小于reg2_i
  // A3．reg1_i为负数、reg2_i为负数，并且reg1_i减去reg2_i的值小于0
  // （即result_sum为负），此时也有reg1_i小于reg2_i
  // B、无符号数比较的时候，直接使用比较运算符比较reg1_i与reg2_i
  assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP))?
                        ((reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i[31] && result_sum[31])|| (reg1_i[31] && reg2_i[31] && result_sum[31]))
                        :(reg1_i < reg2_i);

  //（5）对操作数1逐位取反，赋给reg1_i_not
  assign reg1_i_not = ~reg1_i;


  /******************************************************************
** 第二段：依据aluop_i指示的运算子类型进行运算**
*******************************************************************/

  //进行逻辑运算
  always @(*) begin
    if (rst == `RstEnable) begin
      logicout = `ZeroWord;
    end else begin
      case (aluop_i)
        `EXE_OR_OP: begin  // 逻辑或运算
          logicout = reg1_i | reg2_i;
        end
        `EXE_AND_OP: begin  // 逻辑与运算
          logicout = reg1_i & reg2_i;
        end
        `EXE_NOR_OP: begin  // 逻辑或非运算
          logicout = ~(reg1_i | reg2_i);
        end
        `EXE_XOR_OP: begin  // 逻辑异或运算
          logicout = reg1_i ^ reg2_i;
        end

        default: begin
          logicout = `ZeroWord;
        end
      endcase
    end
  end

  //进行位移运算
  always @(*) begin
    if (rst == `RstEnable) begin
      shiftres = `ZeroWord;
    end else begin
      case (aluop_i)
        `EXE_SLL_OP: begin
          shiftres = reg2_i << reg1_i[4:0];
        end
        `EXE_SRL_OP: begin
          shiftres = reg2_i >> reg1_i[4:0];
        end
        `EXE_SRA_OP: begin
          shiftres = ({32{reg2_i[31]}} << (6'd32 - {1'b0, reg1_i[4:0]})) | reg2_i >> reg1_i[4:0];
        end
        default : begin
          shiftres = `ZeroWord;
        end
      endcase
    end
  end

  //进行移动运算
  always @(*) begin
    if (rst == `RstEnable) begin
      moveres = `ZeroWord;
    end else begin
      moveres = `ZeroWord;
      case (aluop_i)
        `EXE_MFHI_OP: begin
          // 如果是mfhi指令，那么将HI的值作为移动操作的结果
          moveres = HI;
        end
        `EXE_MFLO_OP: begin
          // 如果是mflo指令，那么将LO的值作为移动操作的结果
          moveres = LO;
        end
        `EXE_MOVZ_OP: begin
          // 如果是movz指令，那么将reg1_i的值作为移动操作的结果
          moveres = reg1_i;
        end
        `EXE_MOVN_OP: begin
          // 如果是movn指令，那么将reg1_i的值作为移动操作的结果
          moveres = reg1_i;
        end
        default: begin
        end
      endcase
    end
  end

  always @(*) begin
    if (rst == `RstEnable) begin
      arithmeticres = `ZeroWord;
    end else begin
      case (aluop_i)
        `EXE_SLT_OP, `EXE_SLTU_OP: begin
          arithmeticres = {{31{1'b0}}, reg1_lt_reg2};  // 比较运算
        end
        `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP: begin
          arithmeticres = result_sum;  // 加法运算
        end
        `EXE_SUB_OP, `EXE_SUBU_OP: begin
          arithmeticres = result_sum;  // 减法运算
        end
        `EXE_CLZ_OP: begin  // 计数运算clz
          arithmeticres =  reg1_i[31] ? 0 : reg1_i[30] 
                            ? 1 :
                            reg1_i[29] ? 2 : reg1_i[28]
                            ? 3 :
                            reg1_i[27] ? 4 : reg1_i[26]
                            ? 5 :
                            reg1_i[25] ? 6 : reg1_i[24]
                            ? 7 :
                            reg1_i[23] ? 8 : reg1_i[22]
                            ? 9 :
                            reg1_i[21] ? 10 : reg1_i[20]
                            ? 11 :
                            reg1_i[19] ? 12 : reg1_i[18]
                            ? 13 :
                            reg1_i[17] ? 14 : reg1_i[16]
                            ? 15 :
                            reg1_i[15] ? 16 : reg1_i[14]
                            ? 17 :
                            reg1_i[13] ? 18 : reg1_i[12]
                            ? 19 :
                            reg1_i[11] ? 20 : reg1_i[10]
                            ? 21 :
                            reg1_i[9] ? 22 : reg1_i[8]
                            ? 23 :
                            reg1_i[7] ? 24 : reg1_i[6]
                            ? 25 :
                            reg1_i[5] ? 26 : reg1_i[4]
                            ? 27 :
                            reg1_i[3] ? 28 : reg1_i[2]
                            ? 29 :
                            reg1_i[1] ? 30 : reg1_i[0]
                            ? 31 : 32 ;
        end
        `EXE_CLO_OP: begin  // 计数运算clo
          arithmeticres = (reg1_i_not[31] ? 0 :
                            reg1_i_not[29] ? 2 :
                            reg1_i_not[28] ? 3 :
                            reg1_i_not[27] ? 4 :
                            reg1_i_not[26] ? 5 :
                            reg1_i_not[25] ? 6 :
                            reg1_i_not[24] ? 7 :
                            reg1_i_not[23] ? 8 :
                            reg1_i_not[22] ? 9 :
                            reg1_i_not[21] ? 10 :
                            reg1_i_not[20] ? 11 :
                            reg1_i_not[19] ? 12 :
                            reg1_i_not[18] ? 13 :
                            reg1_i_not[17] ? 14 :
                            reg1_i_not[16] ? 15 :
                            reg1_i_not[15] ? 16 :
                            reg1_i_not[14] ? 17 :
                            reg1_i_not[13] ? 18 :
                            reg1_i_not[12] ? 19 :
                            reg1_i_not[11] ? 20 :
                            reg1_i_not[10] ? 21 :
                            reg1_i_not[9] ? 22 :
                            reg1_i_not[8] ? 23 :
                            reg1_i_not[7] ? 24 :
                            reg1_i_not[6] ? 25 :
                            reg1_i_not[5] ? 26 :
                            reg1_i_not[4] ? 27 :
                            reg1_i_not[3] ? 28 :
                            reg1_i_not[2] ? 29 :
                            reg1_i_not[1] ? 30 :
                            reg1_i_not[0] ? 31 : 32) ;
        end
        default: begin
          arithmeticres = `ZeroWord;
        end
      endcase
    end
  end

  /****************************************************************
************ 第三段：进行乘法运算 *************
*****************************************************************/

  //（1）取得乘法运算的被乘数，如果是有符号乘法且被乘数是负数，那么取补码
  assign opdata1_mult=(((aluop_i==`EXE_MUL_OP)||
                      (aluop_i==`EXE_MULT_OP))
                      && (reg1_i[31] == 1'b1)) ? (~reg1_i +
                      1) : reg1_i;
  //（2）取得乘法运算的乘数，如果是有符号乘法且乘数是负数，那么取补码
  assign opdata2_mult=(((aluop_i==`EXE_MUL_OP)||
                      (aluop_i==`EXE_MULT_OP))
                      && (reg2_i[31] == 1'b1)) ? (~reg2_i +
                      1) : reg2_i;
  //（3）得到临时乘法结果，保存在变量hilo_temp中
  assign hilo_temp = opdata1_mult * opdata2_mult;
  //（4）对临时乘法结果进行修正，最终的乘法结果保存在变量mulres中，主要有两点：
  // A．如果是有符号乘法指令mult、mul，那么需要修正临时乘法结果，如下：
  // A1．如果被乘数与乘数两者一正一负，那么需要对临时乘法结果
  // hilo_temp求补码，作为最终的乘法结果，赋给变量mulres。
  // A2．如果被乘数与乘数同号，那么hilo_temp的值就作为最终的
  // 乘法结果，赋给变量mulres。
  // B．如果是无符号乘法指令multu，那么hilo_temp的值就作为最终的乘法结果,
  // 赋给变量mulres
  always @(*) begin
    if (rst == `RstEnable) begin
      mulres = {`ZeroWord, `ZeroWord};
    end else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MUL_OP)) begin
      if (reg1_i[31] ^ reg2_i[31] == 1'b1) begin
        mulres = ~hilo_temp + 1;
      end else begin
        mulres = hilo_temp;
      end
    end else begin
      mulres = hilo_temp;
    end
  end


  /****************************************************************
** 第四段：依据alusel_i指示的运算类型，选择一个运算结果作为最终结果 **
** 此处只有逻辑运算结果 **
*****************************************************************/

  always @(*) begin
    wd_o   = wd_i;
    wreg_o = wreg_i;

    //如果add、addi、sub、subi且溢出设置wreg_o为Disable
    if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) || (aluop_i == `EXE_SUB_OP)) 
      && (ov_sum == 1'b1)) begin
      wreg_o = `WriteDisable;
    end else begin
      wreg_o = wreg_i;
    end

    case (alusel_i)
      `EXE_RES_LOGIC: begin
        wdata_o = logicout;
      end
      `EXE_RES_SHIFT: begin
        wdata_o = shiftres;
      end
      `EXE_RES_MOVE: begin
        wdata_o = moveres;
      end
      `EXE_RES_ARITHMETIC: begin
        wdata_o = arithmeticres;
      end
      `EXE_RES_MUL: begin
        wdata_o = mulres[31:0];
      end
      `EXE_RES_JUMP_BRANCH:begin
        wdata_o = link_address_i;
      end
      default: begin
        wdata_o = `ZeroWord;
      end
    endcase
  end
  /****************************************************************
** 第五段：如果是MTHI, MTLO, 需要给出whilo_o, hi_o, lo_o的值**
*****************************************************************/

  always @(*) begin
    if (rst == `RstEnable) begin
      whilo_o = `WriteDisable;
      hi_o = `ZeroWord;
      lo_o = `ZeroWord;
    end else if ((aluop_i == `EXE_MULT_OP) || (aluop_i == `EXE_MULTU_OP)) begin
      whilo_o = `WriteEnable;
      hi_o = mulres[63:32];
      lo_o = mulres[31:0];
    end else if (aluop_i == `EXE_MTHI_OP) begin
      whilo_o = `WriteEnable;
      hi_o = reg1_i;
      lo_o = LO;  // 写HI寄存器，所以LO保持不变
    end else if (aluop_i == `EXE_MTLO_OP) begin
      whilo_o = `WriteEnable;
      hi_o = HI;  // 写LO寄存器，所以HI保持不变
      lo_o = reg1_i;
    end else begin
      whilo_o = `WriteDisable;
      hi_o = `ZeroWord;
      lo_o = `ZeroWord;
    end
  end

endmodule

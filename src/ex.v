`include "defines.v"
module ex (
    input wire rst,

    //译码阶段送到执行阶段的信�?
    input wire [`AluSelBus] alusel_i,
    input wire [`AluOpBus] aluop_i,
    input wire [`RegBus] reg1_i,
    input wire [`RegBus] reg2_i,
    input wire wreg_i,
    input wire [`RegAddrBus] wd_i,

    //HILO模块给出的数�?
    input wire [`RegBus] hi_i,
    input wire [`RegBus] lo_i,

    // 延迟�?
    input wire is_in_delayslot_i,
    input wire [`RegBus] link_address_i,
    
    // 当前处于执行阶段的指�?
    input wire [`RegBus] inst_i,

    // 执行阶段运算子类�?
    output wire [`AluOpBus] aluop_o,

    // 加载存储指令的地�?
    output wire [`RegBus] mem_addr_o,

    // 存储指令要存储的数据
    output wire [`RegBus] reg2_o,

    //执行的结�?
    output reg [`RegAddrBus] wd_o,
    output reg wreg_o,
    output reg [`RegBus] wdata_o
);

  reg [`RegBus] logicout;  // 保存逻辑运算结果
  reg [`RegBus] shiftres;  // 保存移位运算结果

  // 新定义了�?些变�?
  wire ov_sum;  // 保存溢出情况
  wire reg1_eq_reg2;  // 第一个操作数是否等于第二个操作数
  wire reg1_lt_reg2;  // 第一个操作数是否小于第二个操作数
  reg [`RegBus] arithmeticres;  // 保存算术运算的结�?
  wire [`RegBus] reg2_i_mux;  // �? �? �? �? �? �? �? �? �? �? 数reg2_i的补�?
  wire [`RegBus] reg1_i_not;  // �? �? �? �? �? �? �? �? �? �? 数reg1_i取反后的�?
  wire [`RegBus] result_sum;  // 保存加法结果
  wire [`RegBus] opdata1_mult;  // 乘法操作中的被乘�?
  wire [`RegBus] opdata2_mult;  // 乘法操作中的乘数
  wire [`DoubleRegBus] temp_mul;
  reg [`DoubleRegBus] mulres;  // 保存乘法结果，宽度为64�?

  // 传到访存阶段确定加载存储类型
  assign aluop_o = aluop_i;

  // 存储加载指令的存储器地址 reg1_i为base, inst[15:0]有符号扩�? 
  assign mem_addr_o = reg1_i + {{16{inst_i[15]}},inst_i[15:0]};

  assign reg2_o = reg2_i;

  /******************************************************************
** 第一段：计算以下5个变量的�?**
*******************************************************************/

  //�?1）如果是减法或�?�有符号比较运算，那么reg2_i_mux等于第二个操作数reg2_i的补�?
  // 减法—�?�第二个数取反的加法，有符号数比较�?��?�两个数相减
  // 否则reg2_i_mux就等于第二个操作数reg2_i
  assign reg2_i_mux = ((aluop_i == `EXE_SUB_OP) || (aluop_i == `EXE_SLT_OP)) ?
                      (~reg2_i)+1 : reg2_i;

  //�?2）分三种情况�?
  // A．如果是加法运算，此时reg2_i_mux就是第二个操作数reg2_i�?
  // �?以result_sum就是加法运算的结�?
  // B．如果是减法运算，此时reg2_i_mux是第二个操作数reg2_i的补码，
  // �?以result_sum就是减法运算的结�?
  // C．如果是有符号比较运算，此时reg2_i_mux也是第二个操作数reg2_i
  // 的补码，�?以result_sum也是减法运算的结果，可以通过判断减法
  // 的结果是否小于零，进而判断第�?个操作数reg1_i是否小于第二个操
  // 作数reg2_i
  assign result_sum = reg1_i + reg2_i_mux;

  //�?3）计算是否溢出，加法指令（add和addi）�?�减法指令（sub）执行的时�?�，
  // �?要判断是否溢出，满足以下两种情况之一时，有溢出：
  // A．reg1_i为正数，reg2_i_mux为正数，但是两�?�之和为负数
  // B．reg1_i为负数，reg2_i_mux为负数，但是两�?�之和为正数
  assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) || ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

  //�?4）计算操作数1是否小于操作�?2，分两种情况�?
  // A．aluop_i为EXE_SLT_OP表示有符号比较运算，此时又分3种情�?
  // A1．reg1_i为负数�?�reg2_i为正数，显然reg1_i小于reg2_i
  // A2．reg1_i为正数�?�reg2_i为正数，并且reg1_i减去reg2_i的�?�小�?0
  // （即result_sum为负），此时也有reg1_i小于reg2_i
  // A3．reg1_i为负数�?�reg2_i为负数，并且reg1_i减去reg2_i的�?�小�?0
  // （即result_sum为负），此时也有reg1_i小于reg2_i
  // B、无符号数比较的时�?�，直接使用比较运算符比较reg1_i与reg2_i
  assign reg1_lt_reg2 = ((aluop_i == `EXE_SLT_OP))?
                        ((reg1_i[31] && !reg2_i[31]) || (!reg1_i[31] && !reg2_i[31] && result_sum[31])|| (reg1_i[31] && reg2_i[31] && result_sum[31]))
                        :(reg1_i < reg2_i);

  //�?5）对操作�?1逐位取反，赋给reg1_i_not
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
        `EXE_OR_OP: begin  // 逻辑或运�?
          logicout = reg1_i | reg2_i;
        end
        `EXE_AND_OP: begin  // 逻辑与运�?
          logicout = reg1_i & reg2_i;
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

  always @(*) begin
    if (rst == `RstEnable) begin
      arithmeticres = `ZeroWord;
    end else begin
      case (aluop_i)
        `EXE_SLT_OP: begin
          arithmeticres = {{31{1'b0}}, reg1_lt_reg2};  // 比较运算
        end
        `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP: begin
          arithmeticres = result_sum;  // 加法运算
        end
        `EXE_SUB_OP: begin
          arithmeticres = result_sum;  // 减法运算
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

  //�?1）取得乘法运算的被乘数，如果是有符号乘法且被乘数是负数，那么取补�?
  assign opdata1_mult=((aluop_i==`EXE_MUL_OP)
                      && (reg1_i[31] == 1'b1)) ? (~reg1_i +
                      1) : reg1_i;
  //�?2）取得乘法运算的乘数，如果是有符号乘法且乘数是负数，那么取补�?
  assign opdata2_mult=((aluop_i==`EXE_MUL_OP)
                      && (reg2_i[31] == 1'b1)) ? (~reg2_i +
                      1) : reg2_i;

  assign temp_mul = opdata1_mult * opdata2_mult;
  
  always @(*) begin
    mulres = temp_mul;
  end

  /****************************************************************
** 第四段：依据alusel_i指示的运算类型，选择�?个运算结果作为最终结�? **
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

endmodule

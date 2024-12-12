`timescale 1ns/1ps
`include "H:\\Intelligent-Computing-Architectures\\Lab5-NaiveTPU-Mat\\basic\\rtl\\define.v"

module MM_top_tb_random();

reg                   clk                  ;
reg                   rst                  ;
reg                   arst_n               ;

// connect BRAM_FM32
wire    [  31:   0]   BRAM_FM32_addr       ;
wire                  BRAM_FM32_clk        ; // clk
wire    [  31:   0]   BRAM_FM32_wrdata     ; // 'b0
wire    [  31:   0]   BRAM_FM32_rddata     ;
wire                  BRAM_FM32_en         ; // 1'b1
wire                  BRAM_FM32_rst        ; // rst
wire    [   3:   0]   BRAM_FM32_we         ; // 'b0

// connect BRAM_WM32
wire    [  31:   0]   BRAM_WM32_addr       ;
wire                  BRAM_WM32_clk        ; // clk
wire    [  31:   0]   BRAM_WM32_wrdata     ; // 'b0
wire    [  31:   0]   BRAM_WM32_rddata     ;
wire                  BRAM_WM32_en         ; // 1'b1
wire                  BRAM_WM32_rst        ; // rst
wire    [   3:   0]   BRAM_WM32_we         ; // 'b0

// connect BRAM_CTRL
wire    [  31:   0]   BRAM_CTRL_addr       ;
wire                  BRAM_CTRL_clk        ; // clk
wire    [  31:   0]   BRAM_CTRL_wrdata     ;
wire    [  31:   0]   BRAM_CTRL_rddata     ;
wire                  BRAM_CTRL_en         ; // 1'b1
wire                  BRAM_CTRL_rst        ; // rst
wire    [   3:   0]   BRAM_CTRL_we         ;

// connect BRAM_OUT
wire    [  31:   0]   BRAM_OUT_addr        ;
wire                  BRAM_OUT_clk         ; // clk
wire    [  31:   0]   BRAM_OUT_wrdata      ;
wire    [  31:   0]   BRAM_OUT_rddata      ;
wire                  BRAM_OUT_en          ; // 1'b1
wire                  BRAM_OUT_rst         ; // rst
wire    [   3:   0]   BRAM_OUT_we          ;

reg                   arm_clk              ;
reg                   arm_work             ;
reg     [   3:   0]   arm_BRAM_FM32_wea    ; // input wire [3 : 0] wea
reg     [  15:   0]   arm_BRAM_FM32_addra  ; // input wire [15 : 0] addra
reg     [  31:   0]   arm_BRAM_FM32_dina   ; // input wire [31 : 0] dina
wire    [  31:   0]   arm_BRAM_FM32_douta  ; // output wire [31 : 0] douta
reg     [   3:   0]   arm_BRAM_WM32_wea    ; // input wire [3 : 0] wea
reg     [  15:   0]   arm_BRAM_WM32_addra  ; // input wire [15 : 0] addra
reg     [  31:   0]   arm_BRAM_WM32_dina   ; // input wire [31 : 0] dina
wire    [  31:   0]   arm_BRAM_WM32_douta  ; // output wire [31 : 0] douta
reg     [   3:   0]   arm_BRAM_CTRL_wea    ; // input wire [3 : 0] wea
reg     [  15:   0]   arm_BRAM_CTRL_addra  ; // input wire [15 : 0] addra
reg     [  31:   0]   arm_BRAM_CTRL_dina   ; // input wire [31 : 0] dina
wire    [  31:   0]   arm_BRAM_CTRL_douta  ; // output wire [31 : 0] douta
reg     [   3:   0]   arm_BRAM_OUT_wea     ; // input wire [3 : 0] wea
reg     [  15:   0]   arm_BRAM_OUT_addra   ; // input wire [15 : 0] addra
reg     [  31:   0]   arm_BRAM_OUT_dina    ; // input wire [31 : 0] dina
wire    [  31:   0]   arm_BRAM_OUT_douta   ; // output wire [31 : 0] douta

wire    [  31:   0]   BRAM_FM32_addr_change;
wire    [  31:   0]   BRAM_WM32_addr_change;
wire    [  31:   0]   BRAM_CTRL_addr_change;
wire    [  31:   0]   BRAM_OUT_addr_change ;

integer line_FM;
integer line_WM;
integer line_para;
integer line_MMout;

integer i, j, k;

reg FM_reg_valid, WM_reg_valid;
reg [7:0] FM_reg0, FM_reg1, FM_reg2, FM_reg3;
reg [7:0] WM_reg0, WM_reg1, WM_reg2, WM_reg3;

reg [15:0] M, N, P;

reg [15:0] cnt;
reg [15:0] cnt_f1;

// 状态定义
// 初始等待状态
localparam IDLE       = 8'b0000_0001;
// 写入Feature
localparam WRITE_FM   = 8'b0000_0010;
// 写入Weight
localparam WRITE_WM   = 8'b0000_0100;
// 写入计算结果
localparam WRITE_COM  = 8'b0000_1000;
// 写入flag
localparam WRITE_FLAG = 8'b0001_0000;
// 等待flag
localparam WAIT_FLAG  = 8'b0010_0000;
// 读取输出
localparam READ_OUT   = 8'b0100_0000;
// 结束
localparam FINISH     = 8'b1000_0000;

// 当前状态
reg [7:0] c_state;
reg [7:0] c_state_f1;
reg [7:0] c_state_f2;
reg [7:0] c_state_f3;
// 下一个状态，使用组合逻辑
reg [7:0] n_state;

// 实验的循环次数
reg [15:0] test_cnt;

// 记录数据
reg [0:7] feature [0:200][0:200];
reg [0:7] weight  [0:200][0:200];
reg [0:7] result_cnt;
reg signed [31:0] result_std;
reg [31:0] result_sim [0:40000];
reg error_flag;
reg finish_flag;

// 当前状态的转义逻辑
always @(posedge arm_clk or posedge rst) begin
    if (rst) begin
        c_state <= IDLE;
    end
    else begin
        c_state <= n_state;
    end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      cnt_f1 <= 'b0;
      c_state_f1 <= IDLE;
      c_state_f2 <= IDLE;
      c_state_f3 <= IDLE;
  end
  else begin
      cnt_f1 <= cnt;
      c_state_f1 <= c_state;
      c_state_f2 <= c_state_f1;
      c_state_f3 <= c_state_f2;
  end
end

// 定义状态转移
always @(*) begin
  case(c_state)
    // 接收到arm请求后写入Feature
    IDLE: begin
        if (arm_work)
            n_state = WRITE_FM;
        else
            n_state = c_state;
    end

    // 写入Feature后写入Weight
    WRITE_FM: begin
        if (cnt == N*((M-1)/4+1) - 'b1)
            n_state = WRITE_WM;
        else
            n_state = c_state;
    end

    // 写入Weight后写入计算结果
    WRITE_WM: begin
        if (cnt == N*((P-1)/4+1) - 'b1)
            n_state = WRITE_COM;
        else
            n_state = c_state;
    end

    // 写入计算结果后写入flag：等待乘除法单元完成计算
    WRITE_COM: begin
        if (cnt == 'd1)
            n_state = WRITE_FLAG;
        else
            n_state = c_state;
    end

    // 写入flag：等待乘除法单元完成计算的flag
    WRITE_FLAG: begin
        n_state = WAIT_FLAG;
    end

    // 乘除法单元完成计算后读出结果
    WAIT_FLAG: begin
        if (arm_BRAM_CTRL_douta == `FLAG_FINISH)
            n_state = READ_OUT;
        else
            n_state = c_state;
    end

    // 读取乘除法单元的计算结果
    READ_OUT: begin
        if (cnt == M*P-1)
            n_state = FINISH;
        else
            n_state = c_state;
    end

    // 完成计算
    FINISH: begin
        n_state = finish_flag ? IDLE : FINISH;
    end

    default: begin
        n_state = IDLE;
    end

  endcase
end

// cnt的状态转义逻辑
always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      cnt <= 'b0;
  end
  // 写入Feature
  else if (c_state == WRITE_FM) begin
      if (cnt == N*((M-1)/4+1) - 'b1)
          cnt <= 'b0;
      else
          cnt <= cnt + 1'b1;
  end
  // 写入Weight
  else if (c_state == WRITE_WM) begin
      if (cnt == N*((P-1)/4+1) - 'b1)
          cnt <= 'b0;
      else
          cnt <= cnt + 1'b1;
  end
  // 写入计算结果
  else if (c_state == WRITE_COM) begin
      if (cnt == 'd1)
          cnt <= 'b0;
      else
          cnt <= cnt + 1'b1;
  end
  // 读取计算结果
  else if (c_state == READ_OUT) begin
      if (cnt == M*P-1)
          cnt <= 'b0;
      else
          cnt <= cnt + 1'b1;
  end
  else begin
      cnt <= cnt;
  end
end

// IDLE
initial begin
  test_cnt = 0;
  while(1) begin
      // 开始实验
      wait(c_state == IDLE);
      M = {$random} % 20 + 2;
      N = {$random} % 20 + 2;
      P = {$random} % 20 + 2;
      $display("[%d]: M = %d, N = %d, P = %d", test_cnt, M, N, P);

      FM_reg_valid = 1'b0;
      FM_reg0 = 'b0;
      FM_reg1 = 'b0;
      FM_reg2 = 'b0;
      FM_reg3 = 'b0;

      WM_reg_valid = 1'b0;
      WM_reg0 = 'b0;
      WM_reg1 = 'b0;
      WM_reg2 = 'b0;
      WM_reg3 = 'b0;

      test_cnt = test_cnt + 1;
      result_cnt = 'b0;

      finish_flag = 1'b0;

      // 完成计算
      wait(c_state == FINISH);
      wait(result_cnt == M*P);

      arm_work = 1'b0;
      error_flag = 1'b0;
      // 校验计算结果
      // 计算std
      error_flag = 1'b0;
      for(i = 0; i < M; i = i + 1) begin
        for(j = 0; j < P; j = j + 1) begin
            result_std = 'b0;
            for(k = 0; k < N; k = k + 1) begin
                result_std = result_std + $signed(weight[k][j]) * $signed({8'b0, feature[i][k]});
            end
            if(result_sim[i*P+j] != result_std) begin
                error_flag = 1'b1;
            end
        end
      end

      if(error_flag) begin
        $display("[%d]: error", test_cnt);
        $finish;
      end
      else begin
        $display("[%d]: correct", test_cnt);
      end
      arm_work = 1'b1;
      finish_flag = 1'b1;
  end
end

// WRITE_FM
initial begin
    while(1) begin
        FM_reg_valid = 1'b0;
        FM_reg0 = 'b0;
        FM_reg1 = 'b0;
        FM_reg2 = 'b0;
        FM_reg3 = 'b0;

        // 等待状态
        wait(c_state == WRITE_FM);

        for(j = 0; j < N; j = j + 1) begin
            for(i = 0; i < M; i = i + 4) begin
                @(posedge arm_clk)
                FM_reg_valid = 1'b1;
                {FM_reg0, FM_reg1, FM_reg2, FM_reg3} = $random;

                // 处理边界情况
                if(i + 1 >= M) begin
                  FM_reg1 = 0;
                  FM_reg2 = 0;
                  FM_reg3 = 0;
                end 
                else if(i + 2 >= M) begin
                    FM_reg2 = 0;
                    FM_reg3 = 0;
                end 
                else if(i + 2 >= M) begin
                    FM_reg3 = 0;
                end

                // 记录生成值
                feature[i  ][j] = FM_reg0;
                feature[i+1][j] = FM_reg1;
                feature[i+2][j] = FM_reg2;
                feature[i+3][j] = FM_reg3;
            end
        end
    end
end

// WRITE_WM
initial begin
    while(1) begin
        WM_reg_valid = 1'b0;
        WM_reg0 = 'b0;
        WM_reg1 = 'b0;
        WM_reg2 = 'b0;
        WM_reg3 = 'b0;

        wait(c_state == WRITE_WM);

        for(i = 0; i < N ; i = i + 1) begin 
            for(j = 0; j < P; j = j + 4) begin
                @(posedge arm_clk)
                WM_reg_valid = 1'b1;
                {WM_reg0, WM_reg1, WM_reg2, WM_reg3} = $random;

                if(j + 1 >= M) begin
                    WM_reg1 = 0;
                    WM_reg2 = 0;
                    WM_reg3 = 0;
                end else if(j + 2 >= M) begin
                    WM_reg2 = 0;
                    WM_reg3 = 0;
                end else if(j + 2 >= M) begin
                    WM_reg3 = 0;
                end

                // 记录生成值
                weight[i][j  ] = WM_reg0;
                weight[i][j+1] = WM_reg1;
                weight[i][j+2] = WM_reg2;
                weight[i][j+3] = WM_reg3;
            end
        end
    end
end

// 设置相应的参数
initial begin
    clk = 1'b0;
    arm_clk = 1'b0;
    rst = 1'b1;
    arst_n = 1'b0;
    arm_work = 1'b0;

    # 100
    rst = 1'b0;
    arst_n = 1'b1;

    # 100
    arm_work = 1'b1;
end

// 时钟变化
always #5 clk = ~clk;
always #7.5 arm_clk = ~arm_clk;

assign BRAM_FM32_addr_change = (BRAM_FM32_addr - `SADDR_F_MEM)>>2;
assign BRAM_WM32_addr_change = (BRAM_WM32_addr - `SADDR_W_MEM)>>2;
assign BRAM_CTRL_addr_change = (BRAM_CTRL_addr - `ADDR_FLAG)  >>2;
assign BRAM_OUT_addr_change  = (BRAM_OUT_addr  - `SADDR_O_MEM)>>2;

// 根据使用的仿真器修改："VivadoSimulator" | "ModelsimSimulator"
// 实际上使用Vivado的即可，其他仿真器的区别主要在于对**阻塞赋值**的解释
parameter SIMULATOR = "VivadoSimulator";
// parameter SIMULATOR = "ModelsimSimulator";
reg FM_reg_valid_sim, WM_reg_valid_sim;
reg [7:0] FM_reg0_sim, FM_reg1_sim, FM_reg2_sim, FM_reg3_sim;
reg [7:0] WM_reg0_sim, WM_reg1_sim, WM_reg2_sim, WM_reg3_sim;

generate
  if (SIMULATOR == "VivadoSimulator") begin
      always @(posedge arm_clk) begin
          {FM_reg_valid_sim, WM_reg_valid_sim} <= {FM_reg_valid, WM_reg_valid};
          {FM_reg0_sim, FM_reg1_sim, FM_reg2_sim, FM_reg3_sim} <= {FM_reg0, FM_reg1, FM_reg2, FM_reg3};
          {WM_reg0_sim, WM_reg1_sim, WM_reg2_sim, WM_reg3_sim} <= {WM_reg0, WM_reg1, WM_reg2, WM_reg3};
      end
  end
  else if (SIMULATOR == "ModelsimSimulator") begin
      always @(*) begin
          {FM_reg_valid_sim, WM_reg_valid_sim} = {FM_reg_valid, WM_reg_valid};
          {FM_reg0_sim, FM_reg1_sim, FM_reg2_sim, FM_reg3_sim} = {FM_reg0, FM_reg1, FM_reg2, FM_reg3};
          {WM_reg0_sim, WM_reg1_sim, WM_reg2_sim, WM_reg3_sim} = {WM_reg0, WM_reg1, WM_reg2, WM_reg3};
      end
  end
endgenerate

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_FM32_wea <= 'b0;
  end
  else begin
      arm_BRAM_FM32_wea <= {4{FM_reg_valid_sim}};
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_FM32_addra <= 'b0;
  end
  else if (c_state_f1 == WRITE_FM) begin
      arm_BRAM_FM32_addra <= cnt_f1;
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_FM32_dina <= 'b0;
  end
  else begin
      arm_BRAM_FM32_dina <= {FM_reg3_sim, FM_reg2_sim, FM_reg1_sim, FM_reg0_sim};
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_WM32_wea <= 'b0;
  end
  else begin
      arm_BRAM_WM32_wea <= {4{WM_reg_valid_sim}};
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_WM32_addra <= 'b0;
  end
  else if (c_state_f1 == WRITE_WM) begin
      arm_BRAM_WM32_addra <= cnt_f1;
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_WM32_dina <= 'b0;
  end
  else begin
      arm_BRAM_WM32_dina <= {WM_reg3_sim,WM_reg2_sim,WM_reg1_sim,WM_reg0_sim};
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_CTRL_wea <= 'b0;
  end
  else if (c_state_f1 == WRITE_COM || c_state_f1 == WRITE_FLAG) begin
      arm_BRAM_CTRL_wea <= {4{1'b1}};
  end
  else begin
      arm_BRAM_CTRL_wea <= 'b0;
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_CTRL_addra <= 'b0;
  end
  else if (c_state_f1 == WRITE_COM) begin
      if (cnt_f1 == 'b0)
          arm_BRAM_CTRL_addra <= (`ADDR_COM1 - `ADDR_FLAG) >> 2;
      else if (cnt_f1 == 'b1)
          arm_BRAM_CTRL_addra <= (`ADDR_COM2 - `ADDR_FLAG) >> 2;
  end
  else if (c_state_f1 == WRITE_FLAG) begin
      arm_BRAM_CTRL_addra <= (`ADDR_FLAG - `ADDR_FLAG) >> 2;
  end
  else if (c_state == WAIT_FLAG) begin
      arm_BRAM_CTRL_addra <= (`ADDR_FLAG - `ADDR_FLAG) >> 2;
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_CTRL_dina <= 'b0;
  end
  else if (c_state_f1 == WRITE_COM) begin
      if (cnt_f1 == 'b0)
          arm_BRAM_CTRL_dina <= {P, M};
      else if (cnt_f1 == 'b1)
          arm_BRAM_CTRL_dina <= {16'b0, N};
  end
  else if (c_state_f1 == WRITE_FLAG) begin
      arm_BRAM_CTRL_dina <= `FLAG_START;
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_OUT_wea <= 'b0;
  end
  else begin
      arm_BRAM_OUT_wea <= 'b0;
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_OUT_addra <= 'b0;
  end
  else if (c_state_f1 == READ_OUT) begin
      arm_BRAM_OUT_addra <= cnt_f1;
  end
end

always @(posedge arm_clk or posedge rst) begin
  if (rst) begin
      arm_BRAM_OUT_dina <= 'b0;
  end
  else begin
      arm_BRAM_OUT_dina <= 'b0;
  end
end

// 记录计算结果
always @(posedge arm_clk) begin
  if (c_state_f3 == READ_OUT) begin
    result_sim[result_cnt] = arm_BRAM_OUT_douta;
    //$display("[%d]: %d", result_cnt, result_sim[result_cnt]);
    result_cnt = result_cnt + 1;
  end
end

// 基于IP实例化BRAM
// 存储Feature的BRAM
tb_ram BRAM_FM32 (
  .clka(arm_clk),    // input wire clka
  .wea(arm_BRAM_FM32_wea),      // input wire [3 : 0] wea
  .addra(arm_BRAM_FM32_addra[15:0]),  // input wire [15 : 0] addra
  .dina(arm_BRAM_FM32_dina),    // input wire [31 : 0] dina
  .douta(arm_BRAM_FM32_douta),  // output wire [31 : 0] douta
  .clkb(BRAM_FM32_clk),    // input wire clkb
  .web(BRAM_FM32_we),      // input wire [3 : 0] web
  .addrb(BRAM_FM32_addr_change[15:0]),  // input wire [15 : 0] addrb
  .dinb(BRAM_FM32_wrdata),    // input wire [31 : 0] dinb
  .doutb(BRAM_FM32_rddata)  // output wire [31 : 0] doutb
);

// 存储Weight的BRAM
tb_ram BRAM_WM32 (
  .clka(arm_clk),    // input wire clka
  .wea(arm_BRAM_WM32_wea),      // input wire [3 : 0] wea
  .addra(arm_BRAM_WM32_addra[15:0]),  // input wire [15 : 0] addra
  .dina(arm_BRAM_WM32_dina),    // input wire [31 : 0] dina
  .douta(arm_BRAM_WM32_douta),  // output wire [31 : 0] douta
  .clkb(BRAM_WM32_clk),    // input wire clkb
  .web(BRAM_WM32_we),      // input wire [3 : 0] web
  .addrb(BRAM_WM32_addr_change[15:0]),  // input wire [15 : 0] addrb
  .dinb(BRAM_WM32_wrdata),    // input wire [31 : 0] dinb
  .doutb(BRAM_WM32_rddata)  // output wire [31 : 0] doutb
);

// 控制状态的BRAM
tb_ram BRAM_CTRL (
  .clka(arm_clk),    // input wire clka
  .wea(arm_BRAM_CTRL_wea),      // input wire [3 : 0] wea
  .addra(arm_BRAM_CTRL_addra[15:0]),  // input wire [15 : 0] addra
  .dina(arm_BRAM_CTRL_dina),    // input wire [31 : 0] dina
  .douta(arm_BRAM_CTRL_douta),  // output wire [31 : 0] douta
  .clkb(BRAM_CTRL_clk),    // input wire clkb
  .web(BRAM_CTRL_we),      // input wire [3 : 0] web
  .addrb(BRAM_CTRL_addr_change[15:0]),  // input wire [15 : 0] addrb
  .dinb(BRAM_CTRL_wrdata),    // input wire [31 : 0] dinb
  .doutb(BRAM_CTRL_rddata)  // output wire [31 : 0] doutb
);

tb_ram BRAM_OUT (
  .clka(arm_clk),    // input wire clka
  .wea(arm_BRAM_OUT_wea),      // input wire [3 : 0] wea
  .addra(arm_BRAM_OUT_addra[15:0]),  // input wire [15 : 0] addra
  .dina(arm_BRAM_OUT_dina),    // input wire [31 : 0] dina
  .douta(arm_BRAM_OUT_douta),  // output wire [31 : 0] douta
  .clkb(BRAM_OUT_clk),    // input wire clkb
  .web(BRAM_OUT_we),      // input wire [3 : 0] web
  .addrb(BRAM_OUT_addr_change[15:0]),  // input wire [15 : 0] addrb
  .dinb(BRAM_OUT_wrdata),    // input wire [31 : 0] dinb
  .doutb(BRAM_OUT_rddata)  // output wire [31 : 0] doutb
);

MM_TOP U_MM_TOP(
  .clk                 (clk                ),
  .arst_n              (arst_n             ),
  .BRAM_FM32_addr      (BRAM_FM32_addr     ),
  .BRAM_FM32_clk       (BRAM_FM32_clk      ),
  .BRAM_FM32_wrdata    (BRAM_FM32_wrdata   ),
  .BRAM_FM32_rddata    (BRAM_FM32_rddata   ),
  .BRAM_FM32_en        (BRAM_FM32_en       ),
  .BRAM_FM32_rst       (BRAM_FM32_rst      ),
  .BRAM_FM32_we        (BRAM_FM32_we       ),
  .BRAM_WM32_addr      (BRAM_WM32_addr     ),
  .BRAM_WM32_clk       (BRAM_WM32_clk      ),
  .BRAM_WM32_wrdata    (BRAM_WM32_wrdata   ),
  .BRAM_WM32_rddata    (BRAM_WM32_rddata   ),
  .BRAM_WM32_en        (BRAM_WM32_en       ),
  .BRAM_WM32_rst       (BRAM_WM32_rst      ),
  .BRAM_WM32_we        (BRAM_WM32_we       ),
  .BRAM_CTRL_addr      (BRAM_CTRL_addr     ),
  .BRAM_CTRL_clk       (BRAM_CTRL_clk      ),
  .BRAM_CTRL_wrdata    (BRAM_CTRL_wrdata   ),
  .BRAM_CTRL_rddata    (BRAM_CTRL_rddata   ),
  .BRAM_CTRL_en        (BRAM_CTRL_en       ),
  .BRAM_CTRL_rst       (BRAM_CTRL_rst      ),
  .BRAM_CTRL_we        (BRAM_CTRL_we       ),
  .BRAM_OUT_addr       (BRAM_OUT_addr      ),
  .BRAM_OUT_clk        (BRAM_OUT_clk       ),
  .BRAM_OUT_wrdata     (BRAM_OUT_wrdata    ),
  .BRAM_OUT_rddata     (BRAM_OUT_rddata    ),
  .BRAM_OUT_en         (BRAM_OUT_en        ),
  .BRAM_OUT_rst        (BRAM_OUT_rst       ),
  .BRAM_OUT_we         (BRAM_OUT_we        )
);

endmodule

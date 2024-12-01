// 上承存储数据的BRAM，下起计算模块
module Multiply_ctrl(
    input clk,
    input rst,

    // connect CTRL
    input       [7:0]   sub_M, // 本次计算子矩阵结果的大小
    input       [7:0]   sub_P, // 本次计算子矩阵结果的大小
    input       [15:0]  N,
    input       [15:0]  subFM_addr,
    input       [15:0]  subFM_incr,
    input       [15:0]  subWM_addr,
    input       [15:0]  subWM_incr,
    input               submulti_start,
    output reg          submulti_finish, // 脉冲信号

    // 存储feature矩阵
    output reg  [15:0]  BRAM_FM64_raddr,
    input       [63:0]  BRAM_FM64_rddata,
    // 存储weight矩阵
    output reg  [15:0]  BRAM_WM128_raddr,
    input       [127:0] BRAM_WM128_rddata,

    // 与输入align的控制信号
    output reg  [7:0]   fvalid,
    output reg  [15:0]  wvalid,
    // 进行数据连接
    output reg  [63:0]  fdata,
    output reg  [127:0] wdata,

    // 与乘法模块的控制信号
    output reg          num_valid,
    output reg  [15:0]  num_ori,

    // 与输出align的控制信号
    // 由于有两个乘法单元，故需要两个参数
    output reg  [7:0]   sub_scale_M1,
    output reg  [7:0]   sub_scale_P1,
    output reg  [7:0]   sub_scale_M2,
    output reg  [7:0]   sub_scale_P2,
    // 第一个对齐单元已经对齐完成
    input               align_fifo_get_all1,
    // 第二个对齐单元已经对齐完成
    input               align_fifo_get_all2
);

// 搬运的数据计数
reg [15:0] data_cnt;
// 对齐fifo中数据获取完成标志
reg [1:0]  align_fifo_get_all;

// 定义状态
localparam IDLE   = 5'b0_0001;
localparam INFO   = 5'b0_0010;
localparam WORK   = 5'b0_0100;
localparam WAIT   = 5'b0_1000;
localparam FINISH = 5'b1_0000;

reg [4:0] c_state;
reg [4:0] n_state;

// 状态转移
always @(posedge clk or posedge rst) begin
    if (rst) begin
        c_state <= IDLE;
    end
    else begin
        c_state <= n_state;
    end
end

always @(*) begin
    case(c_state)
        IDLE: begin
            if (submulti_start)
                n_state = INFO;
            else
                n_state = c_state;
        end
        // 告诉输入对齐模块，输入数据的大小
        INFO: begin
            n_state = WORK;
        end
        // 计算：本质是将数据搬移送入Multiply_8x8模块
        WORK: begin
            if (data_cnt == N-1'b1)
                n_state = WAIT;
            else
                n_state = c_state;
        end
        // 从对齐fifo中获取计算结果
        WAIT: begin
            if (&align_fifo_get_all)
                n_state = FINISH;
            else
                n_state = c_state;
        end
        // 结束 
        FINISH: begin
            n_state = IDLE;
        end

        default: begin
            n_state = IDLE;
        end
    endcase
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_cnt <= 'b0;
    end
    else if (c_state == INFO) begin
        data_cnt <= 'b0;
    end
    // 每次增加一个数据
    else if (c_state == WORK) begin
        data_cnt <= data_cnt + 1'b1;
    end
    else begin
        data_cnt <= data_cnt;
    end
end

// 对BRAM操作地址的状态转移
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_FM64_raddr  <= 'b0;
        BRAM_WM128_raddr <= 'b0;
    end
    else if (n_state == INFO) begin
        BRAM_FM64_raddr  <= subFM_addr;
        BRAM_WM128_raddr <= subWM_addr;
    end
    else if (n_state == WORK) begin
        BRAM_FM64_raddr  <= BRAM_FM64_raddr  + subFM_incr;
        BRAM_WM128_raddr <= BRAM_WM128_raddr + subWM_incr;
    end
    else begin
        BRAM_FM64_raddr  <= BRAM_FM64_raddr;
        BRAM_WM128_raddr <= BRAM_WM128_raddr;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        sub_scale_M1 <= 'b0;
        sub_scale_P1 <= 'b0;
        sub_scale_M2 <= 'b0;
        sub_scale_P2 <= 'b0;
        num_valid    <= 'b0;
        num_ori      <= 'b0;
    end
    else if (n_state == INFO) begin
        // 对齐M次
        sub_scale_M1 <= sub_M;
        sub_scale_M2 <= sub_M;
        // 需要的对齐单元数，要考虑是否需要两个单元
        sub_scale_P1 <= (sub_P > 'd8)? 'd8: sub_P;
        sub_scale_P2 <= (sub_P > 'd8)? (sub_P - 'd8): 'd0;

        num_valid <= 1'b1;
        num_ori <= N;
    end
    else begin
        sub_scale_M1 <= sub_scale_M1;
        sub_scale_M2 <= sub_scale_M2;
        sub_scale_P1 <= sub_scale_P1;
        sub_scale_P2 <= sub_scale_P2;

        num_valid    <= 'b0;
        num_ori      <= num_ori;
    end
end

// 对输出数据进行状态转移：实际上是在搬运数据
always @(posedge clk or posedge rst) begin
    if (rst) begin
        fvalid <= 'b0;
        wvalid <= 'b0;
        fdata  <= 'b0;
        wdata  <= 'b0;
    end
    else if (c_state == WORK) begin
        fvalid <= 8'hff;
        wvalid <= 16'hffff;
        fdata  <= BRAM_FM64_rddata;
        wdata  <= BRAM_WM128_rddata;
    end
    else begin
        fvalid <= 'b0;
        wvalid <= 'b0;
        fdata  <= fdata;
        wdata  <= wdata;
    end
end

// 完成的控制信号
always @(posedge clk or posedge rst) begin
    if (rst) begin
        submulti_finish <= 'b0;
    end
    else if (c_state == FINISH) begin
        submulti_finish <= 1'b1;
    end
    else begin
        submulti_finish <= 'b0;
    end
end

// 完成输出align
always @(posedge clk or posedge rst) begin
    if (rst) begin
        align_fifo_get_all <= 'b0;
    end

    else if (c_state == IDLE) begin
        align_fifo_get_all <= 'b0;
    end

    // 当下进行状态转移
    else if (c_state == WORK && n_state == WAIT) begin
        // 为0：不需要搬运数据
        if ((sub_scale_M1 == 'b0 || sub_scale_P1 == 'b0) && (sub_scale_M2 == 'b0 || sub_scale_P2 == 'b0))
            align_fifo_get_all <= 2'b11;
        else if (sub_scale_M1 == 'b0 || sub_scale_P1 == 'b0)
            align_fifo_get_all <= {align_fifo_get_all[1], 1'b1};
        else if (sub_scale_M2 == 'b0 || sub_scale_P2 == 'b0)
            align_fifo_get_all <= {1'b1, align_fifo_get_all[0]};
        else
            align_fifo_get_all <= align_fifo_get_all;
    end

    // 对齐完毕的控制信号
    else if (c_state == WAIT) begin
        if (align_fifo_get_all1 && align_fifo_get_all2) begin
            align_fifo_get_all <= 2'b11;
        end
        // 第一个对齐单元完成
        else if (align_fifo_get_all1) begin
            align_fifo_get_all <= {align_fifo_get_all[1], 1'b1};
        end
        // 第二个对齐单元完成
        else if (align_fifo_get_all2) begin
            align_fifo_get_all <= {1'b1, align_fifo_get_all[0]};
        end
        else begin
            align_fifo_get_all <= align_fifo_get_all;
        end
    end

    else begin
        align_fifo_get_all <= align_fifo_get_all;
    end
end

endmodule

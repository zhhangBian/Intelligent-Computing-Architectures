`include "define.v"

// 负责读入feature数据，并将其重构
// 存储到BRAM_FM64中，其数据位宽为64bit
module FM_reshape(
    input clk,
    input rst,

    // connect CTRL
    input [15:0] M,
    input [15:0] N,
    input reshape_start,
    // 对外的finish信号
    output reg FM_reshape_finish,

    // 与32位BRAM的交互信号：存储feature矩阵的BRAM
    // 读取的地址
    output BRAM_FM32_clk,
    output BRAM_FM32_rst,
    // 读使能，常置1
    output BRAM_FM32_en,
    // 写使能，常置0
    output [3:0] BRAM_FM32_we,
    // 操作的地址
    output reg [31:0] BRAM_FM32_addr,
    // 写入的数据，常置0
    output [31:0] BRAM_FM32_wrdata,
    // 读取的数据
    input [31:0] BRAM_FM32_rddata,

    // 与64位BRAM的交互信号：存储重构后的feature矩阵的BRAM
    // 写数据的地址
    output reg [15:0] BRAM_FM64_waddr,
    // 写入的数据
    output reg [63:0] BRAM_FM64_wrdata,
    // 写使能
    output reg BRAM_FM64_we
);

assign BRAM_FM32_clk    = clk;
assign BRAM_FM32_rst    = rst;
assign BRAM_FM32_en     = 1'b1;
assign BRAM_FM32_we     = 'b0;
assign BRAM_FM32_wrdata = 'b0;

localparam IDLE   = 4'b0001;
localparam COM    = 4'b0010;
localparam WORK   = 4'b0100;
localparam FINISH = 4'b1000;

reg [3:0] c_state;
reg [3:0] n_state;

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
        // 等待，等待ctrl发出控制信号
        IDLE: begin
            if (reshape_start)
                n_state = COM;
            else
                n_state = c_state;
        end
        // 根据输入的M，N计算需要执行的次数
        COM: begin
            n_state = WORK;
        end
        // 执行搬运操作，并对数据进行补0
        WORK: begin
            // 当列方向和行方向的计数都达到后，结束
            if ((cycle1_cnt == cycle1-1'b1) && (cycle2_cnt == cycle2-1'b1))
                n_state = FINISH;
            else
                n_state = c_state;
        end
        // 完成，告知控制器
        FINISH: begin
            n_state = IDLE;
        end

        default: begin
            n_state = IDLE;
        end
    endcase
end

// 需要执行的列方向循环数
reg [15:0] cycle1;
// 列方向循环计数
reg [15:0] cycle1_cnt;
// 需要执行的行方向循环数
reg [15:0] cycle2;
// 行方向循环计数
reg [15:0] cycle2_cnt;

// 对需要进行的循环数进行复位
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cycle1 <= 'b0;
        cycle2 <= 'b0;
    end
    else if (c_state == COM) begin
        cycle1 <= ((M - 1) >> 2) + 1;
        cycle2 <= N;
    end
    else begin
        cycle1 <= cycle1;
        cycle2 <= cycle2;
    end
end

// 列方向循环计数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cycle1_cnt <= 'b0;
    end
    else if (c_state == COM) begin
        cycle1_cnt <= 'b0;
    end
    else if (c_state == WORK) begin
        // 写完一列后进行复位
        if (cycle1_cnt == cycle1-1'b1)
            cycle1_cnt <= 'b0;
        // 否则步进一个数据
        else
            cycle1_cnt <= cycle1_cnt + 1'b1;
    end
    else begin
        cycle1_cnt <= cycle1_cnt;
    end
end

// 行方向循环计数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cycle2_cnt <= 'b0;
    end
    else if (c_state == COM) begin
        cycle2_cnt <= 'b0;
    end
    else if (c_state == WORK) begin
        // 写完一列后才能到下一列
        if (cycle1_cnt == cycle1-1'b1)
            cycle2_cnt <= cycle2_cnt + 1'b1;
        else
            cycle2_cnt <= cycle2_cnt;
    end
    else begin
        cycle2_cnt <= cycle2_cnt;
    end
end

// 对BRAM_FM32的操作地址
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_FM32_addr <= 'b0;
    end
    // 复位位feature矩阵存储的地址
    else if (n_state == COM) begin
        BRAM_FM32_addr <= `SADDR_F_MEM;
    end
    // 每周期读一个数据
    else if (n_state == WORK) begin
        BRAM_FM32_addr <= BRAM_FM32_addr + `F_MEM_INCR;
    end
    else begin
        BRAM_FM32_addr <= BRAM_FM32_addr;
    end
end

// 对BRAM_FM64的操作地址
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_FM64_waddr <= 'b0;
    end
    // 复位位feature矩阵存储的地址
    else if (c_state == COM) begin
        BRAM_FM64_waddr <= 'b0 - 1'b1;
    end
    // 写完一列或完整一个64位数据，写一次
    else if ((c_state == WORK) && ((cycle1_cnt == cycle1 - 1'b1) || (cycle1_cnt[0] == 1'b1))) begin
        BRAM_FM64_waddr <= BRAM_FM64_waddr + 1'b1;
    end
    else begin
        BRAM_FM64_waddr <= BRAM_FM64_waddr;
    end
end

// 对BRAM_FM64写入的数据
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_FM64_wrdata <= 'b0;
    end
    else if (c_state == WORK) begin
        // 数据拼接，同时达到了补0的效果
        // 进行数据拼接，将32位数据合成64位数据
        // 先写入低位
        if (cycle1_cnt[0] == 1'b0)
            BRAM_FM64_wrdata <= {32'b0, BRAM_FM32_rddata};
        // 再写入高位
        else
            BRAM_FM64_wrdata <= {BRAM_FM32_rddata, BRAM_FM64_wrdata[31:0]};
    end
    else begin
        BRAM_FM64_wrdata <= BRAM_FM64_wrdata;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_FM64_we <= 'b0;
    end
    // 只有当写入高位，或计数达到后，才执行写入操作
    // - 写入高位：拼接后完整的数据
    // - 计数达到：否则进行了补0操作
    else if ((c_state == WORK) && ((cycle1_cnt == cycle1-1'b1) || (cycle1_cnt[0] == 1'b1))) begin
        BRAM_FM64_we <= 1'b1;
    end
    else begin
        BRAM_FM64_we <= 1'b0;
    end
end

// 对外输出的结束信号
always @(posedge clk or posedge rst) begin
    if (rst) begin
        FM_reshape_finish <= 'b0;
    end
    else if (reshape_start) begin
        FM_reshape_finish <= 'b0;
    end
    else if (c_state == FINISH) begin
        FM_reshape_finish <= 1'b1;
    end
    else begin
        FM_reshape_finish <= FM_reshape_finish;
    end
end

endmodule
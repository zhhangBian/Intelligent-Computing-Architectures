`include "define.v"

// 负责读入weight数据，并将其重构
// 存储到BRAM_WM128中，其数据位宽为128bit
module WM_reshape(
    input clk,
    input rst,

    // connect CTRL
    input [15:0] P,
    input [15:0] N,
    input reshape_start,
    // 对外的finish信号
    output reg WM_reshape_finish,

    // 与32位BRAM的交互信号：存储weight矩阵的BRAM
    output BRAM_WM32_clk,
    output BRAM_WM32_rst,
    // 读使能，常置1
    output BRAM_WM32_en,
    // 写使能，常置0
    output [3:0] BRAM_WM32_we,
    // 操作的地址
    output reg [31:0] BRAM_WM32_addr,
    // 写入的数据，常置0
    output [31:0] BRAM_WM32_wrdata,
    // 读取的数据
    input [31:0] BRAM_WM32_rddata,

    // 与128位BRAM的交互信号：存储重构后的weight矩阵的BRAM
    output reg [15:0] BRAM_WM128_waddr,
    // 写入的数据
    output reg [127:0] BRAM_WM128_wrdata,
    // 写使能
    output reg BRAM_WM128_we
);

assign BRAM_WM32_clk    = clk;
assign BRAM_WM32_wrdata = 'b0;
assign BRAM_WM32_en     = 1'b1;
assign BRAM_WM32_rst    = rst;
assign BRAM_WM32_we     = 'b0;

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
        // 根据输入的P，N计算需要执行的次数
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
        // 结束
        FINISH: begin
            n_state = IDLE;
        end

        default: begin
            n_state = IDLE;
        end
    endcase
end

reg [15:0] cycle1;
reg [15:0] cycle2;
reg [15:0] cycle1_cnt;
reg [15:0] cycle2_cnt;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cycle1 <= 'b0;
        cycle2 <= 'b0;
    end
    else if (c_state == COM) begin
        cycle1 <= ((P - 1) >> 2) + 1;
        cycle2 <= N;
    end
    else begin
        cycle1 <= cycle1;
        cycle2 <= cycle2;
    end
end

// 行方向循环计数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cycle1_cnt <= 'b0;
    end
    else if (c_state == COM) begin
        cycle1_cnt <= 'b0;
    end
    else if (c_state == WORK) begin
        // 写完一行后进行复位
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

// 列方向循环计数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cycle2_cnt <= 'b0;
    end
    else if (c_state == COM) begin
        cycle2_cnt <= 'b0;
    end
    else if (c_state == WORK) begin
        // 写完一行后才能到下一行
        if (cycle1_cnt == cycle1-1'b1)
            cycle2_cnt <= cycle2_cnt + 1'b1;
        else
            cycle2_cnt <= cycle2_cnt;
    end
    else begin
        cycle2_cnt <= cycle2_cnt;
    end
end

// 对BRAM_WM32的操作地址
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_WM32_addr <= 'b0;
    end
    // 复位位weight矩阵存储的地址
    else if (n_state == COM) begin
        BRAM_WM32_addr <= `SADDR_W_MEM;
    end
    // 每周期读一个数据
    else if (n_state == WORK) begin
        BRAM_WM32_addr <= BRAM_WM32_addr + `W_MEM_INCR;
    end
    else begin
        BRAM_WM32_addr <= BRAM_WM32_addr;
    end
end

// 对BRAM_WM128的操作地址
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_WM128_waddr <= 'b0;
    end
    // 复位位weight矩阵存储的地址
    else if (c_state == COM) begin
        BRAM_WM128_waddr <= 'b0 - 1'b1;
    end
    // 写完一行或完整一个128位数据，写一次
    else if ((c_state == WORK) && ((cycle1_cnt == cycle1 - 1'b1) || (cycle1_cnt[1:0] == 2'b11))) begin
        BRAM_WM128_waddr <= BRAM_WM128_waddr + 1'b1;
    end
    else begin
        BRAM_WM128_waddr <= BRAM_WM128_waddr;
    end
end

// 对BRAM_WM128写入的数据
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_WM128_wrdata <= 'b0;
    end
    else if (c_state == WORK) begin
        // 数据拼接，同时达到了补0的效果
        case(cycle1_cnt[1:0])
            2'b00: BRAM_WM128_wrdata <= {96'b0, BRAM_WM32_rddata};
            2'b01: BRAM_WM128_wrdata <= {64'b0, BRAM_WM32_rddata, BRAM_WM128_wrdata[31:0]};
            2'b10: BRAM_WM128_wrdata <= {32'b0, BRAM_WM32_rddata, BRAM_WM128_wrdata[63:0]};
            2'b11: BRAM_WM128_wrdata <= {BRAM_WM32_rddata, BRAM_WM128_wrdata[95:0]};
            default: BRAM_WM128_wrdata <= BRAM_WM128_wrdata;
        endcase
    end
    else begin
        BRAM_WM128_wrdata <= BRAM_WM128_wrdata;
    end
end

// 对BRAM_WM128的写使能
always @(posedge clk or posedge rst) begin
    if (rst) begin
        BRAM_WM128_we <= 'b0;
    end
    // 写完一行或完整一个128位数据，写一次
    else if ((c_state == WORK) && ((cycle1_cnt == cycle1-1'b1) || (cycle1_cnt[1:0] == 2'b11))) begin
        BRAM_WM128_we <= 1'b1;
    end
    else begin
        BRAM_WM128_we <= 1'b0;
    end
end

// 对外的finish信号
always @(posedge clk or posedge rst) begin
    if (rst) begin
        WM_reshape_finish <= 'b0;
    end
    else if (reshape_start) begin
        WM_reshape_finish <= 'b0;
    end
    else if (c_state == FINISH) begin
        WM_reshape_finish <= 1'b1;
    end
    else begin
        WM_reshape_finish <= WM_reshape_finish;
    end
end

endmodule
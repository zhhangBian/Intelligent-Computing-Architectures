// 优化：去除了冗余的控制信号

// 由于MAC的数据传递固定为每个计算结点向右向下传递数据，故实际计算中的信号只需要确定计算的开始和结束，MAC单元会自动负责计算的进行。
// 并且，由于MAC中设计有了计算器，实际上每个MAC是清除自身的行为逻辑的，不需要额外的外部信号进行驱动，可以只使用一个外u开始有效信号`num_valid`信号完成对于数据有效的控制，其效果为：
// 1. 重置MAC内部寄存器，设置`num_r`寄存器为输入的`num_r`值
// 2. 当输入数据有效时，拉低num_valid信号，乘加器自动开始计数，在指定周期内完成乘法的运算要求

// 可以将整个矩阵乘法器与外部对接的`num_valid`信号接入左上角的第一个乘加模块，后续模块的`num_valid`信号接入左侧或者上方乘加模块的`num_valid_r`输出。
// 由于MAC进行了大量的重复使用，简单的优化都可以带来较好的资源提升效果。

module MAC(
    input clk, 
    input rst, 

    // 需要进行乘加计算的数据长度
    input                 num_valid, 
    input       [31:0]    num, 
    // 为什么要输出：num_valid的传递也是由MAC进行的
    output  reg           num_valid_r, 
    // 传递输入的数据
    output  reg [31:0]    num_r, 

    // 纵向数据，类型为signed
    input   signed  [7:0] w_data, 
    output  reg signed    [7:0] w_data_r, 

    // 横向数据，类型为usigned
    input   [7:0]         f_data, 
    output  reg [7:0]     f_data_r,

    // 下一个 MAC 的运算结果，纵向向上传播
    input   signed [31:0] data_l, 
    // 当前MAC运算结果有效
    output  reg           valid_o, 
    // 输出数据需要经过选择
    output  reg signed  [31:0]  data_o
);

// 乘累加长度
always @(posedge clk or posedge rst) begin
    if (rst) begin
        num_r <= 32'b0;
    end
    else if (num_valid) begin
        num_r <= num;
    end
    else begin
        num_r <= num_r;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        num_valid_r <= 1'b0;
    end
    else begin
        num_valid_r <= num_valid;
    end
end

// 纵向数据
always @(posedge clk or posedge rst) begin
    if (rst) begin
        w_data_r <= 32'b0;
    end
    else begin
        w_data_r <= w_data;
    end
end

// 横向数据
always @(posedge clk or posedge rst) begin
    if (rst) begin
        f_data_r <= 32'b0;
    end
    else begin
        f_data_r <= f_data;
    end
end

// 本级控制信号
reg [31:0] num_cnt;
// 本MAC计算完成
wire finish = (num_cnt == 1'b0);

always @(posedge clk or posedge rst) begin
    if (rst || num_valid) begin
        num_cnt <= num;
    end
    // 数据有效再更新
    else begin
        num_cnt <= num_cnt - 1'b1;
    end
end

wire signed [15:0] f_data_extend;
// 对横向数据扩展：乘法由8位到16位
assign f_data_extend = $signed({{8{f_data[7]}}, f_data});

// 本级计算
reg signed [31:0] data_reg;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_reg <= 32'b0;
    end
    else if (finish) begin
        data_reg <= 32'b0;
    end
    // 进行累加：矩阵乘计算
    else begin
        data_reg <= data_reg + $signed(w_data) * $signed(f_data_extend);
    end
end

// 数据输出，纵向向上传播
always @(posedge clk or posedge rst) begin
    // 本级计算完成，借助向上传递数据
    if (finish) begin
        data_o <= data_reg;
    end
    // MAC自身一定已经计算完成了
    else begin
        data_o <= data_l;
    end
end

endmodule
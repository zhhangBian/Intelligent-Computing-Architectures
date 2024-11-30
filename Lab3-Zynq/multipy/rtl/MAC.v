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

    // 纵向数据
    input                 w_valid,
    // 纵向数据，类型为signed
    input   signed  [7:0] w_data,
    output  reg           w_valid_r,
    output  reg signed    [7:0] w_data_r,

    // 横向数据有效
    input                 f_valid,
    // 横向数据，类型为usigned
    input   [7:0]         f_data,
    output  reg           f_valid_r,
    output  reg [7:0]     f_data_r,

    // 下一个 MAC 的运算结果是否有效
    input                 valid_l,
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

always @(posedge clk or posedge rst) begin
    if (rst) begin
        w_valid_r <= 1'b0;
    end
    else begin
        w_valid_r <= w_valid;
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

always @(posedge clk or posedge rst) begin
    if (rst) begin
        f_valid_r <= 1'b0;
    end
    else begin
        f_valid_r <= f_valid;
    end
end

// 本级控制信号
reg [31:0] num_cnt;
// 数据是否就绪，可用于乘加
wire valid = w_valid & f_valid;
// 数据序列乘加完成
wire last = (num_cnt == num_r - 1'b1);
// 本MAC计算完成
wire finish = valid & last;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        num_cnt <= 32'b0;
    end
    // 数据有效再更新
    else if (valid) begin
        if (num_cnt == num_r - 1'b1) begin
            num_cnt <= 32'b0;
        end
        else begin
            num_cnt <= num_cnt + 1'b1;
        end
    end
    else begin
        num_cnt <= num_cnt;
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
    // 数据有效，则进行计算
    else if (valid) begin
        // 不复位则累加会出现问题
        if (last) begin
            data_reg <= 32'b0;
        end
        // 进行累加：矩阵乘计算
        else begin
            data_reg <= data_reg + $signed(w_data) * $signed(f_data_extend);
        end
    end
    else begin
        data_reg <= data_reg;
    end
end

// 数据输出，纵向向上传播
always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_o <= 32'b0;
    end
    // 本级计算完成，借助向上传递数据
    else if (finish) begin
        data_o <= data_reg + $signed(w_data) * $signed(f_data_extend);
    end
    // 当valid_l时，MAC自身一定已经计算完成了
    else if (valid_l) begin
        data_o <= data_l;
    end
    else begin
        data_o <= data_o;
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_o <= 32'b0;
    end
    else begin
        // 本级计算完成或传递数据
        valid_o <= finish | valid_l;
    end
end

endmodule
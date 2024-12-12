// 对乘法模块的输出模块进行对齐的fifo
module Align_fifo(
    input clk,
    input rst,

    // connect Multiply_8x8
    input         valid_get0,
    input [31:0]  data_get0,
    input         valid_get1,
    input [31:0]  data_get1,
    input         valid_get2,
    input [31:0]  data_get2,
    input         valid_get3,
    input [31:0]  data_get3,
    input         valid_get4,
    input [31:0]  data_get4,
    input         valid_get5,
    input [31:0]  data_get5,
    input         valid_get6,
    input [31:0]  data_get6,
    input         valid_get7,
    input [31:0]  data_get7,

    // connect Multiply_ctrl
    // 子矩阵的M
    input [7:0]   sub_scale_M,
    // 子矩阵的P
    input [7:0]   sub_scale_P,
    // 对齐fifo是否获取完成
    output reg    align_fifo_get_all,

    // connect Out_ctrl
    // 外部的接收输出模块是否准备好
    input         out_ctrl_ready,
    // valid比数据早一拍有效
    // 输出有效
    output reg    valid,
    // 输出数据
    output reg [31:0] data
);

// 对fifo中存储数据的计数
reg  [3:0]  fifo_wr_cnt   [7:0];
wire [7:0]  fifo_wr_en;
reg  [7:0]  fifo_rd_en;
wire [7:0]  fifo_empty;
wire [31:0] fifo_data_in  [7:0];
wire [31:0] fifo_data_out [7:0];

genvar i;
generate
    for (i = 0; i < 8; i = i + 1) begin
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                fifo_wr_cnt[i] <= 'b0;
            end
            else if (align_fifo_get_all) begin
                fifo_wr_cnt[i] <= 'b0;
            end
            else if (fifo_wr_en[i]) begin
                fifo_wr_cnt[i] <= fifo_wr_cnt[i] + 'b1;
            end
            else begin
                fifo_wr_cnt[i] <= fifo_wr_cnt[i];
            end
        end
    end
endgenerate

// 写使能
assign fifo_wr_en[0] = (~align_fifo_get_all) && valid_get0 && (sub_scale_P > 8'd0) && (fifo_wr_cnt[0] < sub_scale_M);
assign fifo_wr_en[1] = (~align_fifo_get_all) && valid_get1 && (sub_scale_P > 8'd1) && (fifo_wr_cnt[1] < sub_scale_M);
assign fifo_wr_en[2] = (~align_fifo_get_all) && valid_get2 && (sub_scale_P > 8'd2) && (fifo_wr_cnt[2] < sub_scale_M);
assign fifo_wr_en[3] = (~align_fifo_get_all) && valid_get3 && (sub_scale_P > 8'd3) && (fifo_wr_cnt[3] < sub_scale_M);
assign fifo_wr_en[4] = (~align_fifo_get_all) && valid_get4 && (sub_scale_P > 8'd4) && (fifo_wr_cnt[4] < sub_scale_M);
assign fifo_wr_en[5] = (~align_fifo_get_all) && valid_get5 && (sub_scale_P > 8'd5) && (fifo_wr_cnt[5] < sub_scale_M);
assign fifo_wr_en[6] = (~align_fifo_get_all) && valid_get6 && (sub_scale_P > 8'd6) && (fifo_wr_cnt[6] < sub_scale_M);
assign fifo_wr_en[7] = (~align_fifo_get_all) && valid_get7 && (sub_scale_P > 8'd7) && (fifo_wr_cnt[7] < sub_scale_M);

// 写数据
assign fifo_data_in[0] = data_get0;
assign fifo_data_in[1] = data_get1;
assign fifo_data_in[2] = data_get2;
assign fifo_data_in[3] = data_get3;
assign fifo_data_in[4] = data_get4;
assign fifo_data_in[5] = data_get5;
assign fifo_data_in[6] = data_get6;
assign fifo_data_in[7] = data_get7;

generate
  for (i = 0; i < 8; i = i + 1) begin
    // 使用了IP，实例化8个fifo
    my_fifo my_fifo(
      .clk   (clk),
      // 写使能
      .wr_en (fifo_wr_en[i]),
      // 读使能：对fifo中的数据依次读出
      .rd_en (fifo_rd_en[i]),
      // 输入数据
      .din   (fifo_data_in[i]),
      // 输出数据
      .dout  (fifo_data_out[i]),
      // fifo是否为空
      .empty (fifo_empty[i])
    );
  end
endgenerate

// 当前输出哪一个fifo：依次进行状态转移
localparam NOW_OUT0 = 8'b0000_0001;
localparam NOW_OUT1 = 8'b0000_0010;
localparam NOW_OUT2 = 8'b0000_0100;
localparam NOW_OUT3 = 8'b0000_1000;
localparam NOW_OUT4 = 8'b0001_0000;
localparam NOW_OUT5 = 8'b0010_0000;
localparam NOW_OUT6 = 8'b0100_0000;
localparam NOW_OUT7 = 8'b1000_0000;

// 当前状态
reg [7:0] c_state;
reg [7:0] c_state_f1;
// 下一状态
reg [7:0] n_state;

// 状态转移
always @(posedge clk or posedge rst) begin
    if (rst) begin
        c_state <= NOW_OUT0;
        c_state_f1 <= 8'b0;
    end
    else begin
        c_state <= n_state;
        c_state_f1 <= c_state;
    end
end

always @(*) begin
    case (c_state)
        NOW_OUT0: begin
            if (fifo_rd_en[0] && (sub_scale_P == 8'd1))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[0])
                n_state = NOW_OUT1;
            else
                n_state = c_state;
        end

        NOW_OUT1: begin
            if (fifo_rd_en[1] && (sub_scale_P == 8'd2))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[1])
                n_state = NOW_OUT2;
            else
                n_state = c_state;
        end

        NOW_OUT2: begin
            if (fifo_rd_en[2] && (sub_scale_P == 8'd3))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[2])
                n_state = NOW_OUT3;
            else
                n_state = c_state;
        end

        NOW_OUT3: begin
            if (fifo_rd_en[3] && (sub_scale_P == 8'd4))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[3])
                n_state = NOW_OUT4;
            else
                n_state = c_state;
        end

        NOW_OUT4: begin
            if (fifo_rd_en[4] && (sub_scale_P == 8'd5))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[4])
                n_state = NOW_OUT5;
            else
                n_state = c_state;
        end

        NOW_OUT5: begin
            if (fifo_rd_en[5] && (sub_scale_P == 8'd6))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[5])
                n_state = NOW_OUT6;
            else
                n_state = c_state;
        end

        NOW_OUT6: begin
            if (fifo_rd_en[6] && (sub_scale_P == 8'd7))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[6])
                n_state = NOW_OUT7;
            else
                n_state = c_state;
        end

        NOW_OUT7: begin
            if (fifo_rd_en[7] && (sub_scale_P == 8'd8))
                n_state = NOW_OUT0;
            else if (fifo_rd_en[7])
                n_state = NOW_OUT0;
            else
                n_state = c_state;
        end

        default: begin
            n_state = NOW_OUT0;
        end
    endcase
end

// 对fifo的读使能
always @(*) begin
    fifo_rd_en = 8'b0;
    case (c_state)
      NOW_OUT0: fifo_rd_en[0] = (~fifo_empty[0]) & out_ctrl_ready;
      NOW_OUT1: fifo_rd_en[1] = (~fifo_empty[1]) & out_ctrl_ready;
      NOW_OUT2: fifo_rd_en[2] = (~fifo_empty[2]) & out_ctrl_ready;
      NOW_OUT3: fifo_rd_en[3] = (~fifo_empty[3]) & out_ctrl_ready;
      NOW_OUT4: fifo_rd_en[4] = (~fifo_empty[4]) & out_ctrl_ready;
      NOW_OUT5: fifo_rd_en[5] = (~fifo_empty[5]) & out_ctrl_ready;
      NOW_OUT6: fifo_rd_en[6] = (~fifo_empty[6]) & out_ctrl_ready;
      NOW_OUT7: fifo_rd_en[7] = (~fifo_empty[7]) & out_ctrl_ready;
      default: fifo_rd_en = 8'b0;
    endcase
end

// 输出数据是否有效
always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid <= 1'b0;
    end
    else begin
        case (c_state)
            NOW_OUT0: valid = fifo_rd_en[0];
            NOW_OUT1: valid = fifo_rd_en[1];
            NOW_OUT2: valid = fifo_rd_en[2];
            NOW_OUT3: valid = fifo_rd_en[3];
            NOW_OUT4: valid = fifo_rd_en[4];
            NOW_OUT5: valid = fifo_rd_en[5];
            NOW_OUT6: valid = fifo_rd_en[6];
            NOW_OUT7: valid = fifo_rd_en[7];
            default: valid = 1'b0;
        endcase
    end
end

// 输出数据
// valid比数据早一拍有效
always @(*) begin
    case (c_state_f1)
        NOW_OUT0: data = fifo_data_out[0];
        NOW_OUT1: data = fifo_data_out[1];
        NOW_OUT2: data = fifo_data_out[2];
        NOW_OUT3: data = fifo_data_out[3];
        NOW_OUT4: data = fifo_data_out[4];
        NOW_OUT5: data = fifo_data_out[5];
        NOW_OUT6: data = fifo_data_out[6];
        NOW_OUT7: data = fifo_data_out[7];
        default: data = 'b0;
    endcase
end

// 应该读入的总数据
reg [15:0] all_count;
// 输入的有效valid计数
reg [15:0] input_valid_cnt;
// 对fifo写入的数据计数
reg [15:0] fifo_write_cnt;

// 应该读入的总数据
always @(posedge clk or posedge rst) begin
  if (rst) begin
      all_count <= 'b0;
  end
  else begin
      all_count <= sub_scale_M * sub_scale_P;
  end
end

// 输入的有效valid计数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        input_valid_cnt <= 'b0;
    end
    // 对齐了或不需要输入数据则复位
    else if (input_valid_cnt>='d64 && (align_fifo_get_all || all_count == 0)) begin
        input_valid_cnt <= 'b0;
    end
    else begin
        input_valid_cnt <= input_valid_cnt +
                          valid_get7 + valid_get6 +
                          valid_get5 + valid_get4 +
                          valid_get3 + valid_get2 +
                          valid_get1 + valid_get0;
    end
end

// 对fifo写入的数据计数
always @(posedge clk or posedge rst) begin
    if (rst) begin
        fifo_write_cnt <= 'b0;
    end
    else if (align_fifo_get_all) begin
        fifo_write_cnt <= 'b0;
    end
    else begin
        fifo_write_cnt <= fifo_write_cnt +
                  fifo_wr_en[7] + fifo_wr_en[6] +
                  fifo_wr_en[5] + fifo_wr_en[4] +
                  fifo_wr_en[3] + fifo_wr_en[2] +
                  fifo_wr_en[1] + fifo_wr_en[0];
    end
end

// 对齐fifo是否获取完成
always @(posedge clk or posedge rst) begin
    if (rst) begin
        align_fifo_get_all <= 1'b0;
    end
    //对fifo写入的数据达到输入总数，则结束
    else if ((fifo_write_cnt >= all_count) && (all_count!=0) && (~align_fifo_get_all)) begin
        align_fifo_get_all <= 1'b1;
    end
    else if (input_valid_cnt >= 'd64) begin
        align_fifo_get_all <= 1'b0;
    end
    else begin
        align_fifo_get_all <= align_fifo_get_all;
    end
end

endmodule

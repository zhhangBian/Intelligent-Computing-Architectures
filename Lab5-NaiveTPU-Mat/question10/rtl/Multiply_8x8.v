// 接受一个 8*num的Feature矩阵和一个 num*8 的Weight矩阵
// 经过一定周期后输出 Feature * Weight
module Multiply_8x8(
  input clk, 
  input rst, 
  // f的输入数据
  // ! 接线空置，不接入MAC
  input       fvalid0, 
  input [7:0] fdata0, 
  input       fvalid1, 
  input [7:0] fdata1, 
  input       fvalid2, 
  input [7:0] fdata2, 
  input       fvalid3, 
  input [7:0] fdata3, 
  input       fvalid4, 
  input [7:0] fdata4, 
  input       fvalid5, 
  input [7:0] fdata5, 
  input       fvalid6, 
  input [7:0] fdata6, 
  input       fvalid7, 
  input [7:0] fdata7, 
  // w的输入数据
  input               wvalid0, 
  input signed [7:0]  wdata0, 
  input               wvalid1, 
  input signed [7:0]  wdata1, 
  input               wvalid2, 
  input signed [7:0]  wdata2, 
  input               wvalid3, 
  input signed [7:0]  wdata3, 
  input               wvalid4, 
  input signed [7:0]  wdata4, 
  input               wvalid5, 
  input signed [7:0]  wdata5, 
  input               wvalid6, 
  input signed [7:0]  wdata6, 
  input               wvalid7, 
  input signed [7:0]  wdata7, 

  // 表示两个相乘矩阵的性质
  input           num_valid_ori, 
  input [31:0]    num_ori, 
  // 矩阵计算结果的输出
  output                valid_o0, 
  output signed [31:0]  data_o0, 
  output                valid_o1, 
  output signed [31:0]  data_o1, 
  output                valid_o2, 
  output signed [31:0]  data_o2, 
  output                valid_o3, 
  output signed [31:0]  data_o3, 
  output                valid_o4, 
  output signed [31:0]  data_o4, 
  output                valid_o5, 
  output signed [31:0]  data_o5, 
  output                valid_o6, 
  output signed [31:0]  data_o6, 
  output                valid_o7, 
  output signed [31:0]  data_o7
);

wire    [  63:   0]   num_valid           ;
wire    [  31:   0]   num           [63:0];
wire    [  63:   0]   num_valid_r         ;
wire    [  31:   0]   num_r         [63:0];
wire    [  63:   0]   w_valid             ;
wire    [   7:   0]   w_data        [63:0];
wire    [  63:   0]   w_valid_r           ;
wire    [   7:   0]   w_data_r      [63:0];
wire    [  63:   0]   f_valid             ;
wire    [   7:   0]   f_data        [63:0];
wire    [  63:   0]   f_valid_r           ;
wire    [   7:   0]   f_data_r      [63:0];
wire    [  63:   0]   valid_l             ;
wire    [  31:   0]   data_l        [63:0];
wire    [  63:   0]   valid_o             ;
wire    [  31:   0]   data_o        [63:0];

// -------PE矩阵编号-------
//  0  1  2  3  4  5  6  7
//  8  9 10 11 12 13 14 15
// 16 17 18 19 20 21 22 23
// 24 25 26 27 28 29 30 31
// 32 33 34 35 36 37 38 39
// 40 41 42 43 44 45 46 47
// 48 49 50 51 52 53 54 55
// 56 57 58 59 60 61 62 63

// 传递顺序为：每行第一个负责向下和向右传递
genvar i, j;
generate
  for(i = 0; i < 8; i = i + 1) begin
      for(j = 0; j < 8; j = j + 1) begin
          if(j == 0) begin
              // (0, 0)MAC为输入
              if(i == 0) begin
                  assign num_valid[8 * i + j] = num_valid_ori;
                  assign num[8 * i + j]       = num_ori;
              end
              // 每行第一个接受上方传入
              else begin
                  assign num_valid[8 * i + j] = num_valid_r[8 * (i - 1) + j];
                  assign num[8 * i + j]       = num_r[8 * (i - 1) + j];
              end
          end
          // 一般的MAC由左边的单元进行传递
          else begin
              assign num_valid[8 * i + j]     = num_valid_r[8 * i + j - 1];
              assign num[8 * i + j]           = num_r[8 * i + j - 1];
          end
      end
  end
endgenerate

// 对于Weight矩阵的输入，为纵向输入
generate
  for(i = 1; i < 8; i = i + 1) begin
      for(j = 0; j < 8; j = j + 1) begin
          // 接收上方传入的数据
          assign w_data[8 *i + j]   = w_data_r[8 *(i - 1) + j];
      end
  end
endgenerate
// 特殊处理、
assign w_data[0] = wdata0;
assign w_data[1] = wdata1;
assign w_data[2] = wdata2;
assign w_data[3] = wdata3;
assign w_data[4] = wdata4;
assign w_data[5] = wdata5;
assign w_data[6] = wdata6;
assign w_data[7] = wdata7;

// 对于Feature矩阵的输入，为横向输入
generate
  for(i = 0; i < 8; i = i + 1) begin
      for(j = 1; j < 8; j = j + 1) begin
          // 接收外部输入的数据
          assign f_data[8 *i + j]   = f_data_r[8 *i + j - 1];
      end
  end
endgenerate
// 特殊处理
assign f_data[0]  = fdata0;
assign f_data[8]  = fdata1;
assign f_data[16] = fdata2;
assign f_data[24] = fdata3;
assign f_data[32] = fdata4;
assign f_data[40] = fdata5;
assign f_data[48] = fdata6;
assign f_data[56] = fdata7;

// MAC中数据的输出传递：均为纵向
generate
  for(i = 0; i < 8; i = i + 1) begin
      for(j = 0; j < 8; j = j + 1) begin
          // 最后一行为0
          if(i == 7) begin
              assign data_l[8 * i + j]    = 32'b0;
          end
          // 接收下方向上传递
          else begin
              assign data_l[8 * i + j]    = data_o[8 * (i + 1) + j];
          end
      end
  end
endgenerate

generate
  for (i = 0; i < 64; i = i + 1) begin
      MAC U_MAC(
          .clk          (clk           ), // input
          .rst          (rst           ), // input

          .num_valid    (num_valid[i]  ), // input
          .num          (num[i]        ), // input [31:0]
          .num_valid_r  (num_valid_r[i]), // output reg
          .num_r        (num_r[i]      ), // output reg

          .w_data       (w_data[i]     ), // input signed [7:0]
          .w_data_r     (w_data_r[i]   ), // output reg signed [7:0]

          .f_data       (f_data[i]     ), // input signed [7:0]
          .f_data_r     (f_data_r[i]   ), // output reg signed [7:0]

          .data_l       (data_l[i]     ), // input signed [31:0]
          .data_o       (data_o[i]     ), // output reg signed [31:0]

          .valid_o      (valid_o[i]    )  // output reg
  );
  end
endgenerate

assign valid_o0 = valid_o[0];
assign valid_o1 = valid_o[1];
assign valid_o2 = valid_o[2];
assign valid_o3 = valid_o[3];
assign valid_o4 = valid_o[4];
assign valid_o5 = valid_o[5];
assign valid_o6 = valid_o[6];
assign valid_o7 = valid_o[7];

assign data_o0 = data_o[0];
assign data_o1 = data_o[1];
assign data_o2 = data_o[2];
assign data_o3 = data_o[3];
assign data_o4 = data_o[4];
assign data_o5 = data_o[5];
assign data_o6 = data_o[6];
assign data_o7 = data_o[7];

endmodule

// feature矩阵存储的位置
`define SADDR_F_MEM 32'h4000_0000
// weight矩阵存储的位置
`define SADDR_W_MEM 32'h4002_0000
// output矩阵存储的位置
`define SADDR_O_MEM 32'h4004_0000

// flag的存储地址
`define ADDR_FLAG   32'h4006_0000
// 指令的最低地址，也是存储M和P的地址
`define ADDR_COM1   32'h4006_0010
// 存储N的地址
`define ADDR_COM2   32'h4006_0014

// flag信息
`define FLAG_START  32'h0000_0001
`define FLAG_FINISH 32'h0000_0000

// feature矩阵相邻数据的步长：32位
`define F_MEM_INCR  32'd4
// weight矩阵相邻数据的步长：32位
`define W_MEM_INCR  32'd4
// output矩阵相邻数据的步长：32位
`define O_MEM_INCR  32'd4

# ʵ��˵��

����ʵ��Ϊʹ��`Verilog`��дһ������˷���������һ��Feature�����Weight������˵�Ч����

�����ṩ�Ĵ�����ڳ�ª���������ع���ʹ�ô���Ŀɶ��ԡ������Ծ��ﵽ�˼����������

# ʵ��Ŀ��

- ѧϰ����˷�����ԭ��
- ����Linux�򿪷������ֲ

# ʵ��ԭ��

## ����˷�

������������$A = A_{m \times n}, B = B_{n \times l}$������˽��$C = A \times B$���У�
$$
C = (c_{ij})_{m \times l} \\
c_{ij} = \sum_{p=0}^{n} \sum_{q = 0}^{n} a_{ip} \times b_{pj}
$$
����C�е�Ԫ��$c_{ij}$�����Կ���A�ĵ�i����B�ĵ�j�н�����������Ԫ������ʱ����˺��ۼ���$c_{ij}$��

���ң����ھ�����Ƕ�C�����е�Ԫ���ԣ�����A����������B�������н��С�����������󼴿���ÿ����Ԫ�ϻ��۵õ�����ľ���˽��

�������һ�²����е�ͼƬ��

![�����ԭ��](./img/�����ԭ��.png)

## Verilogʵ��

��Verilog�У�����֧��$8 * \text{num}$��Feature�����$\text{num} * 8$��Weight������ˣ�ʵ�����������

�����Feature�����Ǻ�������ģ�Weight��������������ģ��ɻ�����ԪMACӳ���������ÿ��Ԫ�أ����м��㡣

### �ⲿ�ӿ�

ʹ��MAC��Ϊ������Ԫ��Ϊ�˼��ٵ�·����·��MACʹ���˴�����������MAC�н��д��д���

�ڼ�������У������������ݵĴ��ݣ�

- �����С����num���������㵥Ԫ����Ψһ�����룬���뵽λ��$(0, 0)$λ�õ�MAC����������λ�ڵ�һ�е�MAC���д��ϵ��µĴ��ݣ�ÿһ�н��д����ҵĴ���
- w��������ݣ�Ϊ���򴫵ݣ���һ�е�MAC�����ⲿ����
- f��������ݣ�Ϊ���򴫵ݣ���һ�е�MAC�����ⲿ����
- �����������򴫵ݣ��ȴ����Ϊ�кŸߵ�����

### ���㵥ԪMAC

MAC��������������

1. ����˼Ӳ�������w��f���ݾ�Ϊvalidʱ�����гˣ����ۼӵ�����ļĴ����ϣ��ۼӴ���Ϊnum��ʵ���˾���˷�����
2. ���ݴ��ݣ�������Ҫ��������ʱ�����������Ѿ����д��ݳ�ȥ�ˣ��ʲ���������ݳ�ͻ

# ʵ��ʵ��

## ����1

�������ڳ˷��ķ�����չ���⣺���`f_data`�ķ�����չ����Ϊ�޷��ţ���˷����Ҳ���޷��ŵġ�

��һ�����˵�Feature�����Ϊ�������ʲ������Ӱ�죻���ڶ������˵�Feature��Ԫ���и������ʳ˷������л���ɴ��󣬸��������޷������ͽ�����չ������˽���Ĵ���

����Ҫ�������µ��޸ģ�

```diff
- assign f_data_extend = $signed(8'b0, f_data});
+ assign f_data_extend = $signed({{8{f_data[7]}}, f_data});
```

�޸ĺ󣬿��Եõ���ȷ�Ĳ��Σ�

![sim](./img/sim.png)

## ����2

### MAC�Ľӿ��빦�ܶ���

MAC�Ľӿڶ���Ϊ��

| �ź���      | λ�� | ���� | ����                                       |
| ----------- | ---- | ---- | ------------------------------------------ |
| num_valid   | 1    | I    | �����źţ��������num�Ƿ���Ч              |
| num         | 32   | I    | �������num                                |
| num_valid_r | 1    | O    | ��һ�ĵ������źţ����ڴ��ݸ�����MAC        |
| num_r       | 32   | O    | ��һ�ĵľ������num�����ڴ��ݸ�����MAC     |
| w_valid     | 1    | I    | �����źţ������w_data�Ƿ���Ч             |
| w_data      | 8    | I    | weight��������                             |
| w_valid_r   | 1    | O    | ��һ�ĵ������źţ����ڴ��ݸ�����MAC        |
| w_data_r    | 8    | O    | ��һ�ĵ�weight�������ݣ����ڴ��ݸ�����MAC  |
| f_valid     | 1    | I    | �����źţ������f_data�Ƿ���Ч             |
| f_data      | 8    | I    | feature��������                            |
| f_valid_r   | 1    | O    | ��һ�ĵ������źţ����ڴ��ݸ�����MAC        |
| f_data_r    | 8    | O    | ��һ�ĵ�feature�������ݣ����ڴ��ݸ�����MAC |
| valid_l     | 1    | I    | �����źţ���һ�����·���MAC�������Ƿ���Ч  |
| data_l      | 8    | I    | ��һ�����·���MAC������                    |
| valid_o     | 1    | O    | ��ǰMAC�������Ƿ���Ч                    |
| data_o      | 8    | O    | MAC���������                              |

MAC������������ȷ���ģ�

- �����С����num���������㵥Ԫ����Ψһ�����룬���뵽λ��$(0, 0)$λ�õ�MAC����������λ�ڵ�һ�е�MAC���д��ϵ��µĴ��ݣ�ÿһ�н��д����ҵĴ���
- w��������ݣ�Ϊ���򴫵ݣ���һ�е�MAC�����ⲿ����
- f��������ݣ�Ϊ���򴫵ݣ���һ�е�MAC�����ⲿ����
- �����������򴫵ݣ��ȴ����Ϊ�кŸߵ�����

��������ݵ�ѡ����ʵ��ȷ���ģ����·�MAC������Чʱ�����������һ���Ѿ������ȥ�ˣ��ʿ��Խ���ѡ���·����������

����Ϊʲô��������һ��������������Ķ˿ڣ�����Ĳ²���Ϊ�˽�ʡ����Ҫ�ĵ�·��Դ����

### Multipy�ĽӿںͶ���

��ʵ��Multipy��������д������˼��͵Ŀɶ��ԣ������ع�������������������߼���

1. ����Ĺ�����ͨ�����ݴ���ʵ�ֵģ������ݽ�������ʱ��Ҳ��ͬʱ��ʼ���㣬�������ʱ����Ҳ������˼���
2. ��������ɼ���󣬿�ʼ�������ݵ����

Multipy�Ľӿڶ��壺

| �ź���        | λ�� | ���� | ����                                    |
| ------------- | ---- | ---- | --------------------------------------- |
| clk           | 1    | I    | ʱ���ź�                                |
| rst           | 1    | I    | �첽��λ�źţ��ߵ�ƽ��Ч                |
| fvalid        | 1    | I    | �����źţ������feature���������Ƿ���Ч |
| fdata         | 8    | I    | �����feature��������                   |
| wvalid        | 1    | I    | �����źţ������weight���������Ƿ���Ч  |
| wdata         | 8    | I    | �����weight��������                    |
| num_valid_ori | 1    | I    | �����źţ������num�����Ƿ���Ч         |
| num_ori       | 32   | I    | �������num                             |
| valid_o       | 1    | O    | �����źţ�������������Ƿ���Ч          |
| data_o        | 32   | O    | �����������                            |

����num�Ĵ����߼���Ϊ��һ�н��д������µĴ��ݣ���һ�е�Ԫ���ٴ������ҽ��д��ݣ��ʴ���Ϊ��

```verilog
generate
    for(i = 0; i < 8; i = i + 1) begin
        for(j = 0; j < 8; j = j + 1) begin
            if(j == 0) begin
                // (0, 0)MACΪ����
                if(i == 0) begin
                    assign num_valid[8 * i + j] = num_valid_ori;
                    assign num[8 * i + j]       = num_ori;
                end
                // ÿ�е�һ�������Ϸ�����
                else begin
                    assign num_valid[8 * i + j] = num_valid_r[8 * (i - 1) + j];
                    assign num[8 * i + j]       = num_r[8 * (i - 1) + j];
                end
            end
            // һ���MAC����ߵĵ�Ԫ���д���
            else begin
                assign num_valid[8 * i + j]     = num_valid_r[8 * i + j - 1];
                assign num[8 * i + j]           = num_r[8 * i + j - 1];
            end
        end
    end
endgenerate
```

���Ƶģ�Weight����Feature���󡢽���������Ĵ���˼·�����ƣ�ֻ�Ǵ��ݷ����к������������𣬾Ͳ���׸����

# ʵ���������

ʵ���˾���˷���

��������MAC��������������ʵ���˳˼Ӳ�����

ͬʱ�����þ������num��Ϊ����������ʾһ��Ҫ���ж��ٴμ��㡣

![���ʾ��](./img/result.png)

# ʵ���ܽ�

ʵ�������õľ����Ч����

# �����ع�����

## Multipy

```verilog
// ����һ�� 8*num��Feature�����һ�� num*9 ��Weight����
// ����һ�����ں���� Feature * Weight
module Multiply_8x8(
    input clk,
    input rst,
    // f����������
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
    // w����������
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

    // ��ʾ������˾��������
    input           num_valid_ori,
    input [31:0]    num_ori,
    // ��������������
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

// -------PE������-------
//  0  1  2  3  4  5  6  7
//  8  9 10 11 12 13 14 15
// 16 17 18 19 20 21 22 23
// 24 25 26 27 28 29 30 31
// 32 33 34 35 36 37 38 39
// 40 41 42 43 44 45 46 47
// 48 49 50 51 52 53 54 55
// 56 57 58 59 60 61 62 63

// ����˳��Ϊ��ÿ�е�һ���������º����Ҵ���
genvar i, j;
generate
    for(i = 0; i < 8; i = i + 1) begin
        for(j = 0; j < 8; j = j + 1) begin
            if(j == 0) begin
                // (0, 0)MACΪ����
                if(i == 0) begin
                    assign num_valid[8 * i + j] = num_valid_ori;
                    assign num[8 * i + j]       = num_ori;
                end
                // ÿ�е�һ�������Ϸ�����
                else begin
                    assign num_valid[8 * i + j] = num_valid_r[8 * (i - 1) + j];
                    assign num[8 * i + j]       = num_r[8 * (i - 1) + j];
                end
            end
            // һ���MAC����ߵĵ�Ԫ���д���
            else begin
                assign num_valid[8 * i + j]     = num_valid_r[8 * i + j - 1];
                assign num[8 * i + j]           = num_r[8 * i + j - 1];
            end
        end
    end
endgenerate

// ����Weight��������룬Ϊ��������
generate
    for(i = 1; i < 8; i = i + 1) begin
        for(j = 0; j < 8; j = j + 1) begin
            // �����Ϸ����������
            assign w_valid[8 *i + j]  = w_valid_r[8 *(i - 1) + j];
            assign w_data[8 *i + j]   = w_data_r[8 *(i - 1) + j];
        end
    end
endgenerate
// ���⴦��
assign w_valid[0] = wvalid0;  assign w_data[0] = wdata0;
assign w_valid[1] = wvalid1;  assign w_data[1] = wdata1;
assign w_valid[2] = wvalid2;  assign w_data[2] = wdata2;
assign w_valid[3] = wvalid3;  assign w_data[3] = wdata3;
assign w_valid[4] = wvalid4;  assign w_data[4] = wdata4;
assign w_valid[5] = wvalid5;  assign w_data[5] = wdata5;
assign w_valid[6] = wvalid6;  assign w_data[6] = wdata6;
assign w_valid[7] = wvalid7;  assign w_data[7] = wdata7;

// ����Feature��������룬Ϊ��������
generate
    for(i = 0; i < 8; i = i + 1) begin
        for(j = 1; j < 8; j = j + 1) begin
            // �����ⲿ���������
            assign f_valid[8 *i + j]  = f_valid_r[8 *i + j - 1];
            assign f_data[8 *i + j]   = f_data_r[8 *i + j - 1];
        end
    end
endgenerate
// ���⴦��
assign f_valid[0]   = fvalid0;  assign f_data[0]  = fdata0;
assign f_valid[8]   = fvalid1;  assign f_data[8]  = fdata1;
assign f_valid[16]  = fvalid2;  assign f_data[16] = fdata2;
assign f_valid[24]  = fvalid3;  assign f_data[24] = fdata3;
assign f_valid[32]  = fvalid4;  assign f_data[32] = fdata4;
assign f_valid[40]  = fvalid5;  assign f_data[40] = fdata5;
assign f_valid[48]  = fvalid6;  assign f_data[48] = fdata6;
assign f_valid[56]  = fvalid7;  assign f_data[56] = fdata7;

// MAC�����ݵ�������ݣ���Ϊ����
generate
    for(i = 0; i < 8; i = i + 1) begin
        for(j = 0; j < 8; j = j + 1) begin
            // ���һ��Ϊ0
            if(i == 7) begin
                assign valid_l[8 * i + j]   = 1'b0;
                assign data_l[8 * i + j]    = 32'b0;
            end
            // �����·����ϴ���
            else begin
                assign valid_l[8 * i + j]   = valid_o[8 * (i + 1) + j];
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
            .w_valid      (w_valid[i]    ), // input
            .w_data       (w_data[i]     ), // input signed [7:0]
            .w_valid_r    (w_valid_r[i]  ), // output reg
            .w_data_r     (w_data_r[i]   ), // output reg signed [7:0]
            .f_valid      (f_valid[i]    ), // input
            .f_data       (f_data[i]     ), // input signed [7:0]
            .f_valid_r    (f_valid_r[i]  ), // output reg
            .f_data_r     (f_data_r[i]   ), // output reg signed [7:0]
            .valid_l      (valid_l[i]    ), // input
            .data_l       (data_l[i]     ), // input signed [31:0]
            .valid_o      (valid_o[i]    ), // output reg
            .data_o       (data_o[i]     )  // output reg signed [31:0]
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
```

## MAC

```verilog
module MAC(
    input clk,
    input rst,

    // ��Ҫ���г˼Ӽ�������ݳ���
    input                 num_valid,
    input       [31:0]    num,
    // ΪʲôҪ�����num_valid�Ĵ���Ҳ����MAC���е�
    output  reg           num_valid_r,
    // �������������
    output  reg [31:0]    num_r,

    // ��������
    input                 w_valid,
    // �������ݣ�����Ϊsigned
    input   signed  [7:0] w_data,
    output  reg           w_valid_r,
    output  reg signed    [7:0] w_data_r,

    // ����������Ч
    input                 f_valid,
    // �������ݣ�����Ϊusigned
    input   [7:0]         f_data,
    output  reg           f_valid_r,
    output  reg [7:0]     f_data_r,

    // ��һ�� MAC ���������Ƿ���Ч
    input                 valid_l,
    // ��һ�� MAC �����������������ϴ���
    input   signed [31:0] data_l,
    // ��ǰMAC��������Ч
    output  reg           valid_o,
    // ���������Ҫ����ѡ��
    output  reg signed  [31:0]  data_o
    );

// ���ۼӳ���
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

// ��������
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

// ��������
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

// ���������ź�
reg [31:0] num_cnt;
// �����Ƿ�����������ڳ˼�
wire valid = w_valid & f_valid;
// �������г˼����
wire last = (num_cnt == num_r - 1'b1);
// ��MAC�������
wire finish = valid & last;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        num_cnt <= 32'b0;
    end
    // ������Ч�ٸ���
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
// �Ժ���������չ���˷���8λ��16λ
assign f_data_extend = $signed({{8{f_data[7]}}, f_data});

// ��������
reg signed [31:0] data_reg;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_reg <= 32'b0;
    end
    // ������Ч������м���
    else if (valid) begin
        // ����λ���ۼӻ��������
        if (last) begin
            data_reg <= 32'b0;
        end
        // �����ۼӣ�����˼���
        else begin
            data_reg <= data_reg + $signed(w_data) * $signed(f_data_extend);
        end
    end
    else begin
        data_reg <= data_reg;
    end
end

// ����������������ϴ���
always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_o <= 32'b0;
    end
    // ����������ɣ��������ϴ�������
    else if (finish) begin
        data_o <= data_reg + $signed(w_data) * $signed(f_data_extend);
    end
    // ��valid_lʱ��MAC����һ���Ѿ����������
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
        // ����������ɻ򴫵�����
        valid_o <= finish | valid_l;
    end
end

endmodule
```
module my_fifo(
    input clk,
    input rst,
    input wr_en,
    input rd_en,
    input [7:0] din,
    output [7:0] dout,
    output empty
);

logic [7:0] data_reg [0:7];
logic [2:0] head_q, tail_q;

assign dout = data_reg[head_q];

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        tail_q <= 'b0;
    end
    else if(wr_en) begin
        data_reg[tail_q] <= din;
        tail_q <= tail_q + 1;
    end
end

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        head_q <= 3'b0;
    end
    else if(rd_en) begin
        head_q <= head_q + 1;
    end
end

assign empty = (head_q == tail_q);

endmodule
// ============================================================
// seg7_hex —— 在 4 位数码管上以十六进制显示一个 16 位数
//
// 动态扫描：4 个数码管轮流点亮，每个约 2.6ms，人眼看起来同时亮。
// Basys3 的段选 seg 和位选 an 都是低电平有效。
// ============================================================
module seg7_hex (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] value,   // value[15:12] 显示在最左边
    output reg  [6:0]  seg,     // seg[0]~seg[6] 对应 a~g
    output wire        dp,
    output reg  [3:0]  an
);

    assign dp = 1'b1;           // 小数点不亮

    // 扫描计数器：用高 2 位选择当前点亮哪一位
    reg [19:0] scan_cnt;
    always @(posedge clk)
        if (rst) scan_cnt <= 20'd0;
        else     scan_cnt <= scan_cnt + 20'd1;

    wire [1:0] digit_sel = scan_cnt[19:18];

    reg [3:0] nibble;
    always @(*) begin
        case (digit_sel)
            2'd0: begin an = 4'b1110; nibble = value[3:0];   end   // 最右
            2'd1: begin an = 4'b1101; nibble = value[7:4];   end
            2'd2: begin an = 4'b1011; nibble = value[11:8];  end
            default: begin an = 4'b0111; nibble = value[15:12]; end // 最左
        endcase
    end

    // 十六进制字形（低电平点亮，位顺序 gfedcba）
    always @(*) begin
        case (nibble)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            default: seg = 7'b0001110;   // F
        endcase
    end

endmodule

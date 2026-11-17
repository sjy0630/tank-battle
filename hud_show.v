// 顶部比分和终局画面显示模块
module hud_show (
    input wire [9:0] h_cnt, v_cnt,
    input wire [2:0] score_p1, score_p2,
    input wire match_over,
    output wire overlay,
    output wire [11:0] rgb
);
    `include "param.vh"

    wire [7:0] p1_digit = 8'h30 + score_p1;//转换成ASCII码，可以用'0'等字符对应
    wire [7:0] p2_digit = 8'h30 + score_p2;
    wire p1_wins = score_p1 == WIN_SCORE;
    wire [11:0] winner_color = p1_wins ? COLOR_P1 : COLOR_P2;

    // 字模宽 5、高 7，每个字符占 8 像素宽，剩余 3 像素留空。
    // 顶栏和复位提示放大 2 倍，终局标题和比分放大 4 倍。
    wire hud_line = !match_over && h_cnt >= 235 && h_cnt < 411 && v_cnt >= 9 && v_cnt < 23;
    wire title_line = match_over && h_cnt >= 214 && h_cnt < 438 && v_cnt >= 152 && v_cnt < 180;
    wire score_line = match_over && h_cnt >= 246 && h_cnt < 406 && v_cnt >= 224 && v_cnt < 252;
    wire reset_line = match_over && h_cnt >= 243 && h_cnt < 403 && v_cnt >= 304 && v_cnt < 318;

    wire [9:0] x = h_cnt - (hud_line ? 10'd235 : title_line ? 10'd214 : score_line ? 10'd246 : 10'd243);
    wire [9:0] y = v_cnt - (hud_line ? 10'd9 : title_line ? 10'd152 : score_line ? 10'd224 : 10'd304);
    wire large_text = title_line || score_line;
    wire [3:0] column = large_text ? x[8:5] : x[7:4];
    wire [2:0] glyph_x = large_text ? x[4:2] : x[3:1];
    wire [2:0] glyph_y = large_text ? y[4:2] : y[3:1];

    //不同情况下显示的字符串
    wire [55:0] title = p1_wins ? "P1 WINS" : "P2 WINS";
    wire [87:0] text_line = hud_line ? {"P1 ", p1_digit, " - ", p2_digit, " P2"} :
                            title_line ? {title, 32'b0} :
                            score_line ? {p1_digit, " - ", p2_digit, 48'b0} :
                                         {"SW15 RESET", 8'b0};
    // 一行文字从高位往低位排，每个字符占 8 位。-: 8 从指定高位向低位取 8 位。
    wire [7:0] letter = text_line[87 - 8*column -: 8];
    wire [34:0] glyph = font(letter); // 查出当前字符的 5×7 点阵
    // 字模最上面一行存 [34:30]，最下面一行存 [4:0]。+: 5 从指定低位向高位取 5 位。
    wire [4:0] dots = glyph[5*(6-glyph_y) +: 5];
    // 一行字模从 dots[4] 到 dots[0] 对应从左到右。每个字符剩下的 3 列留空。
    // 扫描坐标在文字区域内，且查到的字模点为 1 时，才画文字。
    wire text_pixel = (hud_line || title_line || score_line || reset_line) &&
                      glyph_x < 5 && dots[4-glyph_x];

    // column 从 0 开始。顶栏的第 0～3 列是红方，第 7 列起是蓝方。
    // 终局比分形如“5 - 3”，第 0 列是红方分数，第 4 列是蓝方分数。
    wire red_text = (hud_line && column < 4) || (score_line && column == 0);
    wire blue_text = (hud_line && column >= 7) || (score_line && column == 4);
    // 标题跟随获胜方颜色，其余文字用白色。
    wire [11:0] text_color = red_text ? COLOR_P1 : blue_text ? COLOR_P2 :
                             title_line ? winner_color : 12'hFFF;

    // panel 是终局画面中央的面板。对战时只覆盖顶部，终局时覆盖整个可见区。
    wire panel = h_cnt >= 112 && h_cnt < 528 && v_cnt >= 112 && v_cnt < 368;
    assign overlay = match_over || v_cnt < HUD_H;
    // 先画文字。其余像素依次判断顶栏底色、终局外背景、面板顶部 4 像素色条和面板底色。
    assign rgb = text_pixel ? text_color :
                 !match_over ? COLOR_HUD :
                 !panel ? 12'h112 :
                 v_cnt < 116 ? winner_color : 12'h223;

    //不同字符对应的像素。每行写 5 位，从左到右，最高 5 位是最上面一行。
    function [34:0] font;
        input [7:0] ch;
        begin
            case (ch)
                "0": font = 35'b01110_10001_10001_10001_10001_10001_01110;
                "1": font = 35'b00100_01100_00100_00100_00100_00100_01110;
                "2": font = 35'b01110_10001_00001_00010_00100_01000_11111;
                "3": font = 35'b11110_00001_00001_01110_00001_00001_11110;
                "4": font = 35'b00010_00110_01010_10010_11111_00010_00010;
                "5": font = 35'b11111_10000_10000_11110_00001_00001_11110;
                "6": font = 35'b01110_10000_10000_11110_10001_10001_01110;
                "7": font = 35'b11111_00001_00010_00100_01000_01000_01000;
                "P": font = 35'b11110_10001_10001_11110_10000_10000_10000;
                "W": font = 35'b10001_10001_10001_10101_10101_10101_01010;
                "I": font = 35'b01110_00100_00100_00100_00100_00100_01110;
                "N": font = 35'b10001_11001_10101_10011_10001_10001_10001;
                "S": font = 35'b01111_10000_10000_01110_00001_00001_11110;
                "R": font = 35'b11110_10001_10001_11110_10100_10010_10001;
                "E": font = 35'b11111_10000_10000_11110_10000_10000_11111;
                "T": font = 35'b11111_00100_00100_00100_00100_00100_00100;
                "-": font = 35'b00000_00000_00000_11111_00000_00000_00000;
                default: font = 0;
            endcase
        end
    endfunction
endmodule

// 把随机样本分成三档，再按 map_mode 选择一组地图尺寸。
// maze_cols、maze_rows 以格为单位，sprite_scale 是贴图的整数放大倍数。
// cell_size、tank_size 是正方形边长，wall_size 是墙厚，单位都是像素。
// maze_x、maze_y 是迷宫左上角坐标，maze_w、maze_h 是迷宫宽高，单位也是像素。
module maze_config (
    input  wire [15:0] random_value,
    output wire [1:0] map_mode,
    output reg  [3:0] maze_cols, maze_rows,
    output reg  [6:0] cell_size, tank_size,
    output reg  [3:0] wall_size,
    output reg  [2:0] sprite_scale,
    output wire [9:0] maze_x, maze_w,
    output reg  [9:0] maze_y, maze_h
);
    // LFSR 的非零值是 1～65535，每档各 21845 个值。
    assign map_mode = (random_value <= 16'd21845) ? 2'd0 :
                      (random_value <= 16'd43690) ? 2'd1 : 2'd2;

    // 三种地图都宽 576 像素，在 640 像素的画面里左右各留 32 像素。
    assign maze_x = 10'd32;
    assign maze_w = 10'd576;

    // 墙厚取每格边长的 1/12。坦克边长等于 16 像素的原贴图边长乘放大倍数。
    // 画面顶部预留 32 像素给状态栏，迷宫在余下的 448 像素内垂直居中。
    // 高 432 时，maze_y = 32 + (448 - 432) / 2 = 40。高 384 时，maze_y = 64。
    always @(*) begin
        case (map_mode)
            2'd1: begin
                // 中地图 8×6 格，每格 72 像素。高 6×72 = 432，坦克放大 3 倍到 48。
                maze_cols    = 4'd8;
                maze_rows    = 4'd6;
                cell_size    = 7'd72;
                wall_size    = 4'd6;
                tank_size    = 7'd48;
                sprite_scale = 3'd3;
                maze_y       = 10'd40;
                maze_h       = 10'd432;
            end
            2'd2: begin
                // 小地图 6×4 格，每格 96 像素。高 4×96 = 384，坦克放大 4 倍到 64。
                maze_cols    = 4'd6;
                maze_rows    = 4'd4;
                cell_size    = 7'd96;
                wall_size    = 4'd8;
                tank_size    = 7'd64;
                sprite_scale = 3'd4;
                maze_y       = 10'd64;
                maze_h       = 10'd384;
            end
            default: begin
                // 大地图（模式 0）。高 9×48 = 432，坦克放大 2 倍到 32。
                maze_cols    = 4'd12;
                maze_rows    = 4'd9;
                cell_size    = 7'd48;
                wall_size    = 4'd4;
                tank_size    = 7'd32;
                sprite_scale = 3'd2;
                maze_y       = 10'd40;
                maze_h       = 10'd432;
            end
        endcase
    end
endmodule

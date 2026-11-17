// 游戏显示侧，读取地图和坦克状态，计算 VGA 当前扫描像素的颜色。
module game_show (
    input  wire         clk,
    input  wire         rst,
    input  wire [1:0]   map_mode,
    input  wire [6:0]   cell_size,
    input  wire [3:0]   wall_size,
    input  wire [6:0]   tank_size,
    input  wire [2:0]   sprite_scale,
    input  wire [9:0]   maze_x, maze_y, maze_w, maze_h,
    input  wire [107:0] right_walls, bottom_walls,
    input  wire [19:0]  h_tank, v_tank,
    input  wire [9:0]   dir,
    input  wire [1:0]   tank_alive,
    input  wire [5:0]   bullet_radius,
    input  wire [9:0]   bullet_active,
    input  wire [99:0]  bullet_x, bullet_y,
    input  wire [2:0]   score_p1, score_p2,
    input  wire         match_over,
    output wire         frame_tick,
    output wire [3:0]   vgaRed, vgaGreen, vgaBlue,
    output wire         Hsync, Vsync
);
    `include "param.vh"

    wire [9:0] h_cnt, v_cnt;
    wire       video_on;
    wire       wall_pixel;
    wire [1:0] tank_pixel, bullet_pixel;
    wire [23:0] tank_rgb;
    wire [11:0] rgb;

    // h_cnt、v_cnt 是当前扫描坐标，video_on 标记 640×480 可见区。
    // 扫描回到 (0, 0) 时，frame_tick 拉高一个系统时钟周期。
    vga_timing u_vga (
        .clk        (clk),
        .rst        (rst),
        .h_cnt      (h_cnt),
        .v_cnt      (v_cnt),
        .h_sync     (Hsync),
        .v_sync     (Vsync),
        .video_on   (video_on),
        .frame_tick (frame_tick),
        .pix_en     ()
    );

    // 用扫描坐标查墙位，wall_pixel 表示当前像素落在墙上。
    maze_show u_maze_show (
        .h_cnt        (h_cnt),
        .v_cnt        (v_cnt),
        .map_mode     (map_mode),
        .cell_size    (cell_size),
        .wall_size    (wall_size),
        .maze_x       (maze_x),
        .maze_y       (maze_y),
        .maze_w       (maze_w),
        .maze_h       (maze_h),
        .right_walls  (right_walls),
        .bottom_walls (bottom_walls),
        .wall_pixel   (wall_pixel)
    );

    // 两辆坦克和两组子弹共用扫描坐标，各自判断当前像素。
    genvar p;
    generate for (p = 0; p < 2; p = p + 1) begin : draw_player
        wire sprite_pixel;
        tank_sprite #(.PLAYER2(p == 1)) u_tank_sprite (
            .h_cnt(h_cnt), .v_cnt(v_cnt), .h_tank(h_tank[p*10 +: 10]),
            .v_tank(v_tank[p*10 +: 10]), .dir(dir[p*5 +: 5]),
            .tank_size(tank_size), .sprite_scale(sprite_scale),
            .tank_pixel(sprite_pixel), .tank_rgb(tank_rgb[p*12 +: 12])
        );
        assign tank_pixel[p] = sprite_pixel && tank_alive[p];

        bullet_show u_bullet_show (
            .h_cnt(h_cnt), .v_cnt(v_cnt), .radius(bullet_radius),
            .active(bullet_active[p*MAX_BULLETS +: MAX_BULLETS]),
            .bullet_x(bullet_x[p*MAX_BULLETS*10 +: MAX_BULLETS*10]),
            .bullet_y(bullet_y[p*MAX_BULLETS*10 +: MAX_BULLETS*10]),
            .bullet_pixel(bullet_pixel[p])
        );
    end endgenerate

    // 顶栏盖在游戏画面上，比赛结束后用终局画面覆盖整个可见区。
    wire hud_overlay;
    wire [11:0] hud_rgb;
    hud_show u_hud (
        .h_cnt(h_cnt), .v_cnt(v_cnt), .score_p1(score_p1), .score_p2(score_p2),
        .match_over(match_over), .overlay(hud_overlay), .rgb(hud_rgb)
    );

    // 消隐时输出黑色，再按覆盖层、坦克、墙、子弹和地面的顺序取颜色。
    assign rgb = !video_on ? 12'h000 :
             hud_overlay ? hud_rgb :
             tank_pixel[0] ? tank_rgb[11:0] :
             tank_pixel[1] ? tank_rgb[23:12] :
             wall_pixel ? COLOR_WALL :
             (|bullet_pixel) ? COLOR_BULLET :
             COLOR_BG;
    assign {vgaRed, vgaGreen, vgaBlue} = rgb;
endmodule

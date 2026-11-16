// Basys3 板级顶层，连接开关、按键、VGA 接口和调试 LED。
module top_module (
    input  wire        clk,
    input  wire [15:0] sw,
    input  wire btnU,
    input  wire btnD,
    input  wire btnL,
    input  wire btnR,
    input  wire btnC,
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire        Hsync,
    output wire        Vsync,
    output wire [15:0] led
);
//两级同步SW15复位信号
    reg sw15_sample = 1;
    reg rst = 1;

    always @(posedge clk) begin
        sw15_sample <= sw[15];      // 第一级采样拨码开关
        rst         <= sw15_sample; // 第二级取上一拍的采样值
    end

    // 显示侧每帧送回一次更新脉冲，两个大模块共用板载 clk。
    wire       frame_tick;

    // 从控制侧送往显示侧的数据：地图配置、墙位和坦克状态。
    wire [1:0] map_mode;
    wire [6:0] cell_size;
    wire [3:0] wall_size;
    wire [6:0] tank_size;
    wire [2:0] sprite_scale;
    wire [9:0] maze_x, maze_y, maze_w, maze_h;
    wire [107:0] right_walls, bottom_walls;
    wire [9:0] h_tank, v_tank;
    wire [4:0] dir;
    wire [5:0] bullet_radius;
    wire [4:0] bullet_active;
    wire [49:0] bullet_x, bullet_y;

    // 读取板上按键，在 frame_tick 到来时更新坦克位置和朝向。
    game_control u_game_control (
        .clk           (clk),
        .rst           (rst),
        .frame_tick    (frame_tick),
        .btnU          (btnU),
        .btnD          (btnD),
        .btnL          (btnL),
        .btnR          (btnR),
        .btnC          (btnC),
        .map_mode      (map_mode),
        .cell_size     (cell_size),
        .wall_size     (wall_size),
        .tank_size     (tank_size),
        .sprite_scale  (sprite_scale),
        .maze_x        (maze_x),
        .maze_y        (maze_y),
        .maze_w        (maze_w),
        .maze_h        (maze_h),
        .right_walls   (right_walls),
        .bottom_walls  (bottom_walls),
        .h_tank        (h_tank),
        .v_tank        (v_tank),
        .dir           (dir),
        .bullet_radius (bullet_radius),
        .bullet_active (bullet_active),
        .bullet_x      (bullet_x),
        .bullet_y      (bullet_y)
    );

    // 按 VGA 扫描坐标读取游戏状态，输出 RGB 和行场同步信号。
    game_show u_game_show (
        .clk           (clk),
        .rst           (rst),
        .map_mode      (map_mode),
        .cell_size     (cell_size),
        .wall_size     (wall_size),
        .tank_size     (tank_size),
        .sprite_scale  (sprite_scale),
        .maze_x        (maze_x),
        .maze_y        (maze_y),
        .maze_w        (maze_w),
        .maze_h        (maze_h),
        .right_walls   (right_walls),
        .bottom_walls  (bottom_walls),
        .h_tank        (h_tank),
        .v_tank        (v_tank),
        .dir           (dir),
        .bullet_radius (bullet_radius),
        .bullet_active (bullet_active),
        .bullet_x      (bullet_x),
        .bullet_y      (bullet_y),
        .frame_tick    (frame_tick),
        .vgaRed        (vgaRed),
        .vgaGreen      (vgaGreen),
        .vgaBlue       (vgaBlue),
        .Hsync         (Hsync),
        .Vsync         (Vsync)
    );

    // 心跳灯：每 60 帧（约 1 秒）翻转一次，用来确认电路在运行
    reg heartbeat;
    reg [5:0] frame_cnt;

    always @(posedge clk) begin
        if (rst) begin
            frame_cnt <= 0;
            heartbeat <= 0;
        end
        else if (frame_tick) begin
            if (frame_cnt == 59) begin
                frame_cnt <= 0;
                heartbeat <= ~heartbeat;
            end
            else begin
                frame_cnt <= frame_cnt + 1;
            end
        end
    end

    // LED15 显示心跳，LED[4:0] 显示坦克的朝向编号(方便调试)。
    assign led[15]   = heartbeat;
    assign led[14:5] = 10'b0;
    assign led[4:0]  = dir;
endmodule

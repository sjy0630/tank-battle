// 游戏控制侧，提供当前地图和坦克状态给 game_show。
module game_control (
    input  wire         clk,
    input  wire         rst,
    input  wire         frame_tick,
    input  wire         btnU, btnD, btnL, btnR, btnC,
    output wire [1:0]   map_mode,
    output wire [6:0]   cell_size,
    output wire [3:0]   wall_size,
    output wire [6:0]   tank_size,
    output wire [2:0]   sprite_scale,
    output wire [9:0]   maze_x, maze_y, maze_w, maze_h,
    output wire [107:0] right_walls, bottom_walls,
    output wire [9:0]   h_tank, v_tank,
    output wire [4:0]   dir,
    output wire [5:0]   bullet_radius,
    output wire [4:0]   bullet_active,
    output wire [49:0]  bullet_x, bullet_y
);
    `include "param.vh"
    // 上电时用大地图。LFSR 持续推进，每次进入复位时锁存一次随机样本。
    reg [15:0] lfsr = 16'd1;
    reg [15:0] map_random = 16'd1;
    reg reset_held = 1'b1;
    always @(posedge clk) begin
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        reset_held <= rst;
        if (rst && !reset_held)
            map_random <= lfsr;
    end

    // 坦克多复位一拍，确保用新地图的出生点。
    wire tank_rst = rst || reset_held;
    wire [3:0] maze_rows;
    wire [9:0] half_cell = {3'b000, cell_size} >> 1;
    // 三档列数都是偶数，出生点取最靠近迷宫中心的右侧格心。
    // 偶数行取中心偏下的格心，奇数行的中线正好穿过中央格心。
    wire [9:0] spawn_x = maze_x + (maze_w >> 1) + half_cell;
    wire [9:0] spawn_y = maze_y + (maze_h >> 1) + (maze_rows[0] ? 10'd0 : half_cell);

    // 配置、固定墙位和显示侧共用同一个 map_mode。
    maze_config u_config (
        .random_value (map_random),
        .map_mode     (map_mode),
        .maze_cols    (),
        .maze_rows    (maze_rows),
        .cell_size    (cell_size),
        .wall_size    (wall_size),
        .tank_size    (tank_size),
        .sprite_scale (sprite_scale),
        .maze_x       (maze_x),
        .maze_y       (maze_y),
        .maze_w       (maze_w),
        .maze_h       (maze_h)
    );

    maze_fixed u_maze_fixed (
        .map_mode     (map_mode),
        .right_walls  (right_walls),
        .bottom_walls (bottom_walls)
    );

    reg up,down,left,right,up1,down1,left1,right1,fire, fire1;

    always @(posedge clk)begin //两级同步按键
        if(rst) begin
            up <= 0;
            down <= 0;
            left <= 0;
            right <= 0;
            fire <= 0;
        end else begin
            up <= btnU;
            down <= btnD;
            left <= btnL;
            right <= btnR;
            fire <= btnC;
        end
        up1 <= up;
        down1 <= down;
        left1 <= left;
        right1 <= right;
        fire1 <= fire;
    end

    // frame_tick 发起本帧的移动，查墙完成后提交新的贴图中心坐标。
    wire signed [9:0] forward_dx, forward_dy;
    tank_control u_tank_control (
        .clk        (clk),
        .rst        (tank_rst),
        .spawn_x    (spawn_x),
        .spawn_y    (spawn_y),
        .sprite_scale (sprite_scale),
        .map_mode   (map_mode),
        .cell_size  (cell_size),
        .wall_size  (wall_size),
        .maze_x     (maze_x),
        .maze_y     (maze_y),
        .maze_w     (maze_w),
        .maze_h     (maze_h),
        .right_walls (right_walls),
        .bottom_walls (bottom_walls),
        .up         (up1),
        .down       (down1),
        .left       (left1),
        .right      (right1),
        .frame_tick (frame_tick),
        .h_tank      (h_tank),
        .v_tank      (v_tank),
        .dir        (dir),
        .forward_dx (forward_dx),
        .forward_dy (forward_dy)
    );

    // 大/中/小地图的子弹半径为 3、5、6 像素，中档将 4.5 向上取整。
    assign bullet_radius = (BULLET_R * sprite_scale + 1) >> 1;
    bullet_control u_bullet_control (
        .clk(clk), .rst(tank_rst), .frame_tick(frame_tick), .fire(fire1),
        .h_tank(h_tank), .v_tank(v_tank), .forward_dx(forward_dx), .forward_dy(forward_dy),
        .radius(bullet_radius), .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
        .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
        .right_walls(right_walls), .bottom_walls(bottom_walls),
        .active(bullet_active), .bullet_x(bullet_x), .bullet_y(bullet_y)
    );
endmodule

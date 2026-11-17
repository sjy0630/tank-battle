// 游戏控制侧，提供当前地图和坦克状态给 game_show。
module game_control (
    input  wire         clk,
    input  wire         rst,
    input  wire         frame_tick,
    input  wire         btnU, btnD, btnL, btnR, btnC,
    input  wire [4:0]   p1_keys, p2_keys,
    output wire [1:0]   map_mode,
    output wire [6:0]   cell_size,
    output wire [3:0]   wall_size,
    output wire [6:0]   tank_size,
    output wire [2:0]   sprite_scale,
    output wire [9:0]   maze_x, maze_y, maze_w, maze_h,
    output wire [107:0] right_walls, bottom_walls,
    output wire [19:0]  h_tank, v_tank,
    output wire [9:0]   dir,
    output wire [1:0]   tank_alive,
    output wire [5:0]   bullet_radius,
    output wire [9:0]   bullet_active,
    output wire [99:0]  bullet_x, bullet_y,
    output wire [2:0]   score_p1, score_p2,
    output wire         match_over
);
    `include "param.vh"
    // LFSR 一直推进。复位或开始下一回合时取样，保存本回合的墙位种子。
    reg [15:0] lfsr = 16'd1;
    reg [15:0] maze_seed = 16'd1;
    reg reset_held = 1'b1;
    wire restart_round;
    // 上电生成一次。之后等地图尺寸和种子更新一拍，再启动生成器。
    reg start_maze = 1'b1;
    wire new_match = rst && !reset_held;
    always @(posedge clk) begin
        lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
        reset_held <= rst;
        start_maze <= new_match || restart_round;
        if (new_match || restart_round)
            maze_seed <= lfsr;
    end

    // 生成器按当前地图的行列开墙，控制侧和显示侧共用这份墙位。
    wire [3:0] maze_cols, maze_rows;
    maze_config u_config (
        .clk          (clk),
        .new_match    (new_match),
        .new_round    (restart_round),
        .random_value (lfsr),
        .map_mode     (map_mode),
        .maze_cols    (maze_cols),
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

    wire maze_busy;
    maze_gen u_maze_gen (
        .clk          (clk),
        .start        (start_maze),
        .seed         (maze_seed),
        .maze_cols    (maze_cols),
        .maze_rows    (maze_rows),
        .busy         (maze_busy),
        .right_walls  (right_walls),
        .bottom_walls (bottom_walls)
    );

    // 对键盘按键输入进行两级同步
    reg [4:0] board_keys_sync, board_keys;
    always @(posedge clk) begin
        if (rst) begin
            board_keys_sync <= 0;
            board_keys <= 0;
        end else begin
            board_keys_sync <= {btnC, btnR, btnL, btnD, btnU};
            board_keys <= board_keys_sync;
        end
    end

    wire playing;
    // 等新墙位生成完再释放坦克和子弹，坦克用新地图的出生坐标。
    wire player_rst = rst || reset_held || restart_round || start_maze || maze_busy;
    wire [1:0] hit_p1, hit_p2;
    round_control u_round (
        .clk(clk), .rst(rst), .frame_tick(frame_tick),
        .hit_p1(|hit_p1), .hit_p2(|hit_p2),
        .playing(playing), .match_over(match_over), .restart_round(restart_round),
        .tank_alive(tank_alive), .score_p1(score_p1), .score_p2(score_p2)
    );

    // 查墙是组合逻辑，回合进行中直接在帧边界更新位置和子弹。
    wire physics_tick = frame_tick && playing && !player_rst;

    wire [9:0] half_cell = {3'b000, cell_size} >> 1;
    wire [5:0] tank_radius = (TANK_R * sprite_scale) >> 1;
    assign bullet_radius = (BULLET_R * sprite_scale + 1) >> 1;
    wire [6:0] hit_distance = tank_radius + bullet_radius;

    genvar p, n, t;
    generate for (p = 0; p < 2; p = p + 1) begin : players//生成两个玩家
        // 红蓝两车分别在左上、右下格心出生。
        wire [9:0] spawn_x = p == 0 ? maze_x + half_cell : maze_x + maze_w - half_cell;
        wire [9:0] spawn_y = p == 0 ? maze_y + half_cell : maze_y + maze_h - half_cell;
        wire [4:0] keys = p == 0 ? (p1_keys | board_keys) : p2_keys;
        wire [9:0] player_x, player_y;
        wire [4:0] player_dir;
        wire signed [9:0] forward_dx, forward_dy;
        wire [MAX_BULLETS-1:0] active, hits_p1, hits_p2;
        wire [MAX_BULLETS*10-1:0] shot_x, shot_y;

        tank_control #(.START_DIRECTION(p == 0 ? 5'd16 : 5'd0)) u_tank (
            .clk(clk), .rst(player_rst), .frame_tick(physics_tick),
            .up(keys[0]), .down(keys[1]), .left(keys[2]), .right(keys[3]),
            .spawn_x(spawn_x), .spawn_y(spawn_y), .sprite_scale(sprite_scale),
            .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
            .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
            .right_walls(right_walls), .bottom_walls(bottom_walls),
            .h_tank(player_x), .v_tank(player_y), .dir(player_dir),
            .forward_dx(forward_dx), .forward_dy(forward_dy)
        );

        bullet_control u_bullets (
            .clk(clk), .rst(player_rst), .frame_tick(physics_tick), .fire(keys[4]),
            .h_tank(player_x), .v_tank(player_y), .forward_dx(forward_dx), .forward_dy(forward_dy),
            .radius(bullet_radius), .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
            .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
            .right_walls(right_walls), .bottom_walls(bottom_walls),
            .active(active), .bullet_x(shot_x), .bullet_y(shot_y)
        );

        assign h_tank[p*10 +: 10] = player_x;
        assign v_tank[p*10 +: 10] = player_y;
        assign dir[p*5 +: 5] = player_dir;
        assign bullet_active[p*MAX_BULLETS +: MAX_BULLETS] = active;
        assign bullet_x[p*MAX_BULLETS*10 +: MAX_BULLETS*10] = shot_x;
        assign bullet_y[p*MAX_BULLETS*10 +: MAX_BULLETS*10] = shot_y;

        // 每颗子弹检查是否碰撞坦克
        for (n = 0; n < MAX_BULLETS; n = n + 1) begin : hit_test
            wire [9:0] x = shot_x[n*10 +: 10];
            wire [9:0] y = shot_y[n*10 +: 10];
            wire [1:0] overlap_x, overlap_y;
            wire [1:0] overlap = overlap_x & overlap_y;
            reg shot_active, left_owner;
            always @(posedge clk) begin
                shot_active <= active[n] && !player_rst;
                if (player_rst || !shot_active)
                    left_owner <= 0;
                else if (!overlap[p])
                    left_owner <= 1;//如果离开过发射玩家的碰撞箱，说明已经发射，后续可以对发射者造成伤害
            end

            for (t = 0; t < 2; t = t + 1) begin : targets
                wire [9:0] tx = h_tank[t*10 +: 10];
                wire [9:0] ty = v_tank[t*10 +: 10];
                reg same_x, same_y;
                always @(posedge clk) begin
                    same_x <= x + hit_distance > tx && tx + hit_distance > x;
                    same_y <= y + hit_distance > ty && ty + hit_distance > y;
                end
                assign overlap_x[t] = same_x;
                assign overlap_y[t] = same_y;
            end

            assign hits_p1[n] = shot_active && overlap[0] && (p != 0 || left_owner);
            assign hits_p2[n] = shot_active && overlap[1] && (p != 1 || left_owner);
        end
        assign hit_p1[p] = |hits_p1;
        assign hit_p2[p] = |hits_p2;
    end endgenerate
endmodule

// Basys3 板级顶层，连接开关、按键、VGA 接口和调试 LED。
module top_module (
    input  wire        clk,
    input  wire [15:0] sw,
    input  wire btnU,
    input  wire btnD,
    input  wire btnL,
    input  wire btnR,
    input  wire btnC,
    input  wire PS2Clk, PS2Data,
    input  wire uart_rx,
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,
    output wire        Hsync,
    output wire        Vsync,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an,
    output wire [15:0] led
);
    // 板载 100 MHz 先送入 MMCM。内部频率为 800 MHz，再除以 32 得到 25 MHz。
    // 组合查墙在 100 MHz 下未过时序，25 MHz 给整套游戏统一留出 40 ns。
    wire feedback, feedback_buf, clock_25, game_clk, clock_locked;
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0),
        .DIVCLK_DIVIDE(1),
        .CLKFBOUT_MULT_F(8.0),
        .CLKOUT0_DIVIDE_F(32.0)
    ) u_work_clock (
        .CLKIN1(clk), .CLKFBIN(feedback_buf), .CLKFBOUT(feedback),
        .CLKOUT0(clock_25), .LOCKED(clock_locked), .PWRDWN(1'b0), .RST(1'b0)
    );
    BUFG u_clock_feedback (.I(feedback), .O(feedback_buf));
    BUFG u_game_clock (.I(clock_25), .O(game_clk));

    // 等 MMCM 锁定后再释放复位。SW15 和锁定状态在工作时钟下做两级同步。
    reg sw15_sample = 1;
    reg rst = 1;

    always @(posedge game_clk) begin
        sw15_sample <= sw[15] || !clock_locked;
        rst         <= sw15_sample; // 第二级取上一拍的采样值
    end

    wire [4:0] ps2_p1_keys, ps2_p2_keys;
    wire ps2_clock_seen, ps2_byte_seen, ps2_frame_error;
    wire [7:0] ps2_last_byte;
    ps2_keyboard u_keyboard (
        .clk(game_clk), .rst(rst), .ps2_clk(PS2Clk), .ps2_data(PS2Data),
        .p1_keys(ps2_p1_keys), .p2_keys(ps2_p2_keys),
        .clock_seen(ps2_clock_seen), .byte_seen(ps2_byte_seen),
        .frame_error(ps2_frame_error), .last_byte(ps2_last_byte)
    );

    // 显示侧每帧送回一次更新脉冲，两个大模块共用 25 MHz 工作时钟。
    wire       frame_tick;

    // J4 接收电脑键盘，和 PS/2 一起接到原来的按键入口。
    wire [4:0] uart_p1_keys, uart_p2_keys;
    wire uart_packet_seen, uart_link_alive;
    uart_keyboard u_uart_keyboard (
        .clk(game_clk), .rst(rst), .rx(uart_rx), .frame_tick(frame_tick),
        .p1_keys(uart_p1_keys), .p2_keys(uart_p2_keys),
        .packet_seen(uart_packet_seen), .link_alive(uart_link_alive)
    );
    wire [4:0] p1_keys = ps2_p1_keys | uart_p1_keys;
    wire [4:0] p2_keys = ps2_p2_keys | uart_p2_keys;

    // 从控制侧送往显示侧的数据：地图配置、墙位和坦克状态。
    wire [1:0] map_mode;
    wire [6:0] cell_size;
    wire [3:0] wall_size;
    wire [6:0] tank_size;
    wire [2:0] sprite_scale;
    wire [9:0] maze_x, maze_y, maze_w, maze_h;
    wire [107:0] right_walls, bottom_walls;
    wire [19:0] h_tank, v_tank;
    wire [9:0] dir;
    wire [1:0] tank_alive;
    wire [5:0] bullet_radius;
    wire [9:0] bullet_active;
    wire [99:0] bullet_x, bullet_y;
    wire [2:0] score_p1, score_p2;
    wire match_over;

    // 读取板上按键，在 frame_tick 到来时更新坦克位置和朝向。
    game_control u_game_control (
        .clk           (game_clk),
        .rst           (rst),
        .frame_tick    (frame_tick),
        .btnU          (btnU),
        .btnD          (btnD),
        .btnL          (btnL),
        .btnR          (btnR),
        .btnC          (btnC),
        .p1_keys       (p1_keys),
        .p2_keys       (p2_keys),
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
        .tank_alive    (tank_alive),
        .bullet_radius (bullet_radius),
        .bullet_active (bullet_active),
        .bullet_x      (bullet_x),
        .bullet_y      (bullet_y),
        .score_p1      (score_p1),
        .score_p2      (score_p2),
        .match_over    (match_over)
    );

    // 按 VGA 扫描坐标读取游戏状态，输出 RGB 和行场同步信号。
    game_show u_game_show (
        .clk           (game_clk),
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
        .tank_alive    (tank_alive),
        .bullet_radius (bullet_radius),
        .bullet_active (bullet_active),
        .bullet_x      (bullet_x),
        .bullet_y      (bullet_y),
        .score_p1      (score_p1),
        .score_p2      (score_p2),
        .match_over    (match_over),
        .frame_tick    (frame_tick),
        .vgaRed        (vgaRed),
        .vgaGreen      (vgaGreen),
        .vgaBlue       (vgaBlue),
        .Hsync         (Hsync),
        .Vsync         (Vsync)
    );

    // 左边一位显示红方，右边一位显示蓝方。中间两位关闭。
    wire [3:0] score_an;
    seg7_hex u_score (
        .clk(game_clk), .rst(rst), .value({1'b0, score_p1, 8'b0, 1'b0, score_p2}),
        .seg(seg), .dp(dp), .an(score_an)
    );
    assign an = score_an | 4'b0110;

    // 心跳灯：每 60 帧（约 1 秒）翻转一次，用来确认电路在运行
    reg heartbeat;
    reg [5:0] frame_cnt;

    always @(posedge game_clk) begin
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

    // SW14 打开键盘诊断。LD13/12/11 分别记住时钟、有效字节、帧错。
    // LD10 跟随游戏按键，LD9 记住收到串口包，LD8 表示串口仍在收包。
    // LD[7:0] 显示最后一次有效 PS/2 扫描码。
    wire [13:0] keyboard_leds =
        {ps2_clock_seen, ps2_byte_seen, ps2_frame_error, |{p1_keys, p2_keys},
         uart_packet_seen, uart_link_alive, ps2_last_byte};
    assign led[15]   = heartbeat;
    assign led[14]   = sw[14] || match_over;
    assign led[13:0] = sw[14] ? keyboard_leds : 14'b0;
endmodule

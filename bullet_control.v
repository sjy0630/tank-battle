// 五颗子弹各自更新状态，这里负责把发射脉冲给第一个空槽。
module bullet_control (
    input wire clk, rst, frame_tick, fire,
    input wire [9:0] h_tank, v_tank,
    input wire signed [9:0] forward_dx, forward_dy,
    input wire [5:0] radius,
    input wire [1:0] map_mode,
    input wire [6:0] cell_size,
    input wire [3:0] wall_size,
    input wire [9:0] maze_x, maze_y, maze_w, maze_h,
    input wire [107:0] right_walls, bottom_walls,
    output wire [4:0] active,
    output wire [49:0] bullet_x, bullet_y
);
    `include "param.vh"
    reg fire_previous;

    // 在帧边界检测按下，按住只发一次。
    wire fire_press = frame_tick && fire && !fire_previous;
    always @(posedge clk) begin
        if (rst)
            fire_previous <= 0;
        else if (frame_tick)
            fire_previous <= fire;
    end

    wire [MAX_BULLETS-1:0] idle;
    wire [MAX_BULLETS:0] earlier_idle;
    assign earlier_idle[0] = 1'b0;
    assign active = ~idle;

    // 从坦克中心发射，初速为坦克前进速度的两倍。
    wire signed [9:0] shot_dx = forward_dx <<< 1;
    wire signed [9:0] shot_dy = forward_dy <<< 1;

    genvar n;
    generate for (n = 0; n < MAX_BULLETS; n = n + 1) begin : slots
        // 前面的槽都在飞时，这个空闲槽才有权接收 launch。轮流从小到大让子弹槽发子弹
        wire launch = fire_press && idle[n] && !earlier_idle[n];
        assign earlier_idle[n+1] = earlier_idle[n] || idle[n];

        bullet u_bullet (
            .clk(clk), .rst(rst), .frame_tick(frame_tick), .launch(launch),
            .start_x(h_tank), .start_y(v_tank), .start_dx(shot_dx), .start_dy(shot_dy),
            .radius(radius), .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
            .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
            .right_walls(right_walls), .bottom_walls(bottom_walls),
            .idle(idle[n]), .bullet_x(bullet_x[n*10 +: 10]), .bullet_y(bullet_y[n*10 +: 10])
        );
    end endgenerate
endmodule

// 每帧轮询 5 个子弹槽，共用一套分轴查墙电路。
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
    output reg [4:0] active,
    output wire [49:0] bullet_x, bullet_y
);
    `include "param.vh"
    localparam IDLE = 3'd0, CHECK_SLOT = 3'd1, MOVE_SLOT = 3'd2,
               WAIT_MOVE = 3'd3, FIRE = 3'd4;

    reg [2:0] state, slot;
    reg fire_previous, fire_request;
    reg [9:0] shot_x, shot_y;
    reg signed [9:0] shot_dx, shot_dy;
    reg signed [FRAC_BITS+9:0] x [0:MAX_BULLETS-1];
    reg signed [FRAC_BITS+9:0] y [0:MAX_BULLETS-1];
    reg signed [9:0] dx [0:MAX_BULLETS-1];
    reg signed [9:0] dy [0:MAX_BULLETS-1];
    reg [8:0] life [0:MAX_BULLETS-1];

    genvar n;
    generate for (n = 0; n < MAX_BULLETS; n = n + 1) begin : export_pos
        assign bullet_x[n*10 +: 10] = x[n][FRAC_BITS +: 10];
        assign bullet_y[n*10 +: 10] = y[n][FRAC_BITS +: 10];
    end endgenerate

    wire move_done, hit_x, hit_y;
    wire signed [FRAC_BITS+9:0] next_x, next_y;
    wall_move #(.FRAC_BITS(FRAC_BITS)) u_wall_move (
        .clk(clk), .rst(rst), .start(state == MOVE_SLOT),
        .x(x[slot]), .y(y[slot]), .dx(dx[slot]), .dy(dy[slot]), .radius(radius),
        .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
        .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
        .right_walls(right_walls), .bottom_walls(bottom_walls),
        .done(move_done), .hit_x(hit_x), .hit_y(hit_y), .next_x(next_x), .next_y(next_y)
    );

    // 从高往低扫描，最后留下编号最小的空槽。
    integer i;
    reg [2:0] free_slot;
    always @(*) begin
        free_slot = MAX_BULLETS;
        for (i = MAX_BULLETS-1; i >= 0; i = i - 1)
            if (!active[i])
                free_slot = i;
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            slot <= 0;
            active <= 0;
            fire_previous <= 0;
            fire_request <= 0;
        end else begin
            case (state)
                IDLE: if (frame_tick) begin
                    // 按住只发一次，在帧边界记录按下的变化。
                    fire_request <= fire && !fire_previous;
                    fire_previous <= fire;
                    if (fire && !fire_previous) begin
                        shot_x <= h_tank;
                        shot_y <= v_tank;
                        shot_dx <= forward_dx <<< 1;
                        shot_dy <= forward_dy <<< 1;
                    end
                    slot <= 0;
                    state <= CHECK_SLOT;
                end
                CHECK_SLOT: begin
                    if (active[slot] && life[slot] > 1) begin
                        state <= MOVE_SLOT;
                    end else begin
                        active[slot] <= 0;
                        if (slot == MAX_BULLETS-1)
                            state <= FIRE;
                        else
                            slot <= slot + 1'b1;
                    end
                end
                MOVE_SLOT: state <= WAIT_MOVE;
                WAIT_MOVE: if (move_done) begin
                    x[slot] <= next_x;
                    y[slot] <= next_y;
                    // 撞到哪个轴的墙，就反转该轴的速度分量。
                    if (hit_x)
                        dx[slot] <= -dx[slot];
                    if (hit_y)
                        dy[slot] <= -dy[slot];
                    life[slot] <= life[slot] - 1'b1;
                    if (slot == MAX_BULLETS-1)
                        state <= FIRE;
                    else begin
                        slot <= slot + 1'b1;
                        state <= CHECK_SLOT;
                    end
                end
                FIRE: begin
                    if (fire_request && free_slot < MAX_BULLETS) begin
                        // 从坦克中心发射，避免贴墙时把子弹直接放进墙里。
                        active[free_slot] <= 1;
                        x[free_slot] <= shot_x << FRAC_BITS;
                        y[free_slot] <= shot_y << FRAC_BITS;
                        dx[free_slot] <= shot_dx;
                        dy[free_slot] <= shot_dy;
                        life[free_slot] <= BULLET_LIFE;
                    end
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

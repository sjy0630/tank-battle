// 单颗子弹维护自己的位置、速度和寿命。
module bullet (
    input wire clk, rst, frame_tick, launch,
    input wire [9:0] start_x, start_y,
    input wire signed [9:0] start_dx, start_dy,
    input wire [5:0] radius,
    input wire [1:0] map_mode,
    input wire [6:0] cell_size,
    input wire [3:0] wall_size,
    input wire [9:0] maze_x, maze_y, maze_w, maze_h,
    input wire [107:0] right_walls, bottom_walls,
    output wire idle,
    output wire [9:0] bullet_x, bullet_y
);
    `include "param.vh"
    localparam IDLE = 1'b0, FLYING = 1'b1;
    reg state;
    reg signed [FRAC_BITS+9:0] pos_x, pos_y;
    reg signed [9:0] dx, dy;
    reg [8:0] age;

    assign idle = (state == IDLE);
    assign bullet_x = pos_x[FRAC_BITS +: 10];
    assign bullet_y = pos_y[FRAC_BITS +: 10];

    wire signed [FRAC_BITS+9:0] trial_x = pos_x + dx;
    wire signed [FRAC_BITS+9:0] trial_y = pos_y + dy;
    wire hit_x, hit_y;
    maze_collision u_collision (
        .x(bullet_x), .y(bullet_y),
        .next_x(trial_x[FRAC_BITS +: 10]), .next_y(trial_y[FRAC_BITS +: 10]),
        .radius(radius),
        .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
        .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
        .right_walls(right_walls), .bottom_walls(bottom_walls),
        .hit_x(hit_x), .hit_y(hit_y)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: if (launch) begin
                    pos_x <= start_x << FRAC_BITS;
                    pos_y <= start_y << FRAC_BITS;
                    dx <= start_dx;
                    dy <= start_dy;
                    age <= 0;
                    state <= FLYING;
                end
                FLYING: if (frame_tick) begin
                    // 被阻挡的轴保留原位置，并反转速度分量。
                    if (hit_x)
                        dx <= -dx;
                    else
                        pos_x <= trial_x;
                    if (hit_y)
                        dy <= -dy;
                    else
                        pos_y <= trial_y;

                    age <= age + 1'b1;
                    if (age == BULLET_LIFE-1)
                        state <= IDLE;
                end
            endcase
        end
    end
endmodule

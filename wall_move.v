// 坦克和子弹共用的分轴移动。先试 X，再用接受后的 X 试 Y。
module wall_move #(
    parameter FRAC_BITS = 6
) (
    input wire clk, rst, start,
    input wire signed [FRAC_BITS+9:0] x, y,
    input wire signed [9:0] dx, dy,
    input wire [5:0] radius,
    input wire [1:0] map_mode,
    input wire [6:0] cell_size,
    input wire [3:0] wall_size,
    input wire [9:0] maze_x, maze_y, maze_w, maze_h,
    input wire [107:0] right_walls, bottom_walls,
    output reg done, hit_x, hit_y,
    output reg signed [FRAC_BITS+9:0] next_x, next_y
);
    localparam IDLE = 3'd0, ASK_X = 3'd1, WAIT_X = 3'd2,
               ASK_Y = 3'd3, WAIT_Y = 3'd4;
    reg [2:0] state;
    reg signed [FRAC_BITS+9:0] trial_x, trial_y;
    wire [9:0] query_x = state == ASK_X ? trial_x[FRAC_BITS +: 10] : next_x[FRAC_BITS +: 10];
    wire [9:0] query_y = state == ASK_X ? next_y[FRAC_BITS +: 10] : trial_y[FRAC_BITS +: 10];
    wire valid, hit;

    maze_collision u_collision (
        .clk(clk), .rst(rst), .request(state == ASK_X || state == ASK_Y),
        .x(query_x), .y(query_y), .radius(radius),
        .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
        .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
        .right_walls(right_walls), .bottom_walls(bottom_walls),
        .valid(valid), .hit(hit)
    );

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            done <= 0;
            hit_x <= 0;
            hit_y <= 0;
            next_x <= 0;
            next_y <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (start) begin
                    next_x <= x;
                    next_y <= y;
                    trial_x <= x + dx;
                    trial_y <= y + dy;
                    state <= ASK_X;
                end
                ASK_X: state <= WAIT_X;
                WAIT_X: if (valid) begin
                    hit_x <= hit;
                    if (!hit)
                        next_x <= trial_x;
                    state <= ASK_Y;
                end
                ASK_Y: state <= WAIT_Y;
                WAIT_Y: if (valid) begin
                    hit_y <= hit;
                    if (!hit)
                        next_y <= trial_y;
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

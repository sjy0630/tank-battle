// 查询一个方形碰撞盒是否与迷宫的墙重叠。
module maze_collision (
    input wire clk, rst, request,
    input wire [9:0] x, y,
    input wire [5:0] radius,
    input wire [1:0] map_mode,
    input wire [6:0] cell_size,
    input wire [3:0] wall_size,
    input wire [9:0] maze_x, maze_y, maze_w, maze_h,
    input wire [107:0] right_walls, bottom_walls,
    output reg valid, hit
);
    `include "param.vh"

    // 盒子范围为 [中心-半径, 中心+半径)，取最后一个覆盖像素作为上界。
    wire [10:0] x_lo = {1'b0, x} - radius;
    wire [10:0] y_lo = {1'b0, y} - radius;
    wire [10:0] x_hi = {1'b0, x} + radius - 11'd1;
    wire [10:0] y_hi = {1'b0, y} + radius - 11'd1;
    wire outside = x_lo[10] || y_lo[10] ||
                   x_lo < {1'b0, maze_x} + wall_size ||
                   y_lo < {1'b0, maze_y} + wall_size ||
                   x_hi >= {1'b0, maze_x} + maze_w ||
                   y_hi >= {1'b0, maze_y} + maze_h;

    // 三档格长都能被 8 整除。先用高 7 位做除法，再拼回格内偏移的低 3 位。
    function [10:0] grid_position;
        input [9:0] pixel;
        input [1:0] mode;
        reg [3:0] cell_index, remainder;
        begin
            case (mode)
                2'd1: begin
                    cell_index = pixel[9:3] / 7'd9;
                    remainder  = pixel[9:3] % 7'd9;
                end
                2'd2: begin
                    cell_index = pixel[9:3] / 7'd12;
                    remainder  = pixel[9:3] % 7'd12;
                end
                default: begin
                    cell_index = pixel[9:3] / 7'd6;
                    remainder  = pixel[9:3] % 7'd6;
                end
            endcase
            grid_position = {cell_index, remainder, pixel[2:0]};
        end
    endfunction

    reg [2:0] pending;
    reg [9:0] rel_x_lo, rel_y_lo, rel_x_hi, rel_y_hi;
    reg outside_bounds, outside_grid, outside_walls;
    reg [10:0] grid_x_lo, grid_y_lo, grid_x_hi, grid_y_hi;
    reg [6:0] idx00, idx01, idx10, idx11;
    reg spans_cols, spans_rows, right_edge, bottom_edge;
    wire [6:0] wall_start = cell_size - wall_size;

    always @(posedge clk) begin
        if (rst) begin
            pending <= 0;
            valid <= 0;
            hit <= 0;
        end else begin
            // 逐拍完成相对坐标、格子坐标、墙位索引和位图查询。
            pending <= {pending[1:0], request};
            valid <= pending[2];

            rel_x_lo <= x_lo - maze_x;
            rel_y_lo <= y_lo - maze_y;
            rel_x_hi <= x_hi - maze_x;
            rel_y_hi <= y_hi - maze_y;
            outside_bounds <= outside;

            grid_x_lo <= grid_position(rel_x_lo, map_mode);
            grid_y_lo <= grid_position(rel_y_lo, map_mode);
            grid_x_hi <= grid_position(rel_x_hi, map_mode);
            grid_y_hi <= grid_position(rel_y_hi, map_mode);
            outside_grid <= outside_bounds;

            // 盒子小于一格，因此只需考虑首尾两列和首尾两行。
            idx00 <= grid_y_lo[10:7] * MAX_COLS + grid_x_lo[10:7];
            idx01 <= grid_y_lo[10:7] * MAX_COLS + grid_x_hi[10:7];
            idx10 <= grid_y_hi[10:7] * MAX_COLS + grid_x_lo[10:7];
            idx11 <= grid_y_hi[10:7] * MAX_COLS + grid_x_hi[10:7];
            spans_cols <= grid_x_lo[10:7] != grid_x_hi[10:7];
            spans_rows <= grid_y_lo[10:7] != grid_y_hi[10:7];
            right_edge <= grid_x_hi[6:0] >= wall_start;
            bottom_edge <= grid_y_hi[6:0] >= wall_start;
            outside_walls <= outside_grid;

            // 跨到下一列就已经覆盖前一列的右墙带，跨行时同理。
            hit <= outside_walls ||
                   (spans_cols && (right_walls[idx00] || right_walls[idx10])) ||
                   (right_edge && (right_walls[idx01] || right_walls[idx11])) ||
                   (spans_rows && (bottom_walls[idx00] || bottom_walls[idx01])) ||
                   (bottom_edge && (bottom_walls[idx10] || bottom_walls[idx11]));
        end
    end
endmodule

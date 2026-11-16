//完成整步移动检测，返回各轴是否被阻挡。
module maze_collision (
    input wire [9:0] x, y,
    input wire [9:0] next_x, next_y,
    input wire [5:0] radius,
    input wire [1:0] map_mode,
    input wire [6:0] cell_size,
    input wire [3:0] wall_size,
    input wire [9:0] maze_x, maze_y, maze_w, maze_h,
    input wire [107:0] right_walls, bottom_walls,
    output wire hit_x, hit_y
);
    // 先尝试 X 位移，Y 保持原位置。
    maze_overlap u_check_x (
        .x(next_x), .y(y), .radius(radius),
        .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
        .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
        .right_walls(right_walls), .bottom_walls(bottom_walls),
        .hit(hit_x)
    );

    // X 被阻挡时采用原 X，再判断 Y 位移
    wire [9:0] accepted_x = hit_x ? x : next_x;
    maze_overlap u_check_y (
        .x(accepted_x), .y(next_y), .radius(radius),
        .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
        .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
        .right_walls(right_walls), .bottom_walls(bottom_walls),
        .hit(hit_y)
    );
endmodule

// 查询一个方形碰撞盒是否与迷宫的墙重叠。
module maze_overlap (
    input wire [9:0] x, y,
    input wire [5:0] radius,
    input wire [1:0] map_mode,
    input wire [6:0] cell_size,
    input wire [3:0] wall_size,
    input wire [9:0] maze_x, maze_y, maze_w, maze_h,
    input wire [107:0] right_walls, bottom_walls,
    output wire hit
);
    `include "param.vh"

    // 得到碰撞箱范围
    wire [9:0] x_lo = x - radius;
    wire [9:0] y_lo = y - radius;
    wire [9:0] x_hi = x + radius - 10'd1;
    wire [9:0] y_hi = y + radius - 10'd1;
    // 判断有没有直接出地图迷宫边界
    wire outside = x < maze_x + wall_size + radius ||
                   y < maze_y + wall_size + radius ||
                   x > maze_x + maze_w - radius ||
                   y > maze_y + maze_h - radius;

    // 把一个坐标换算成是格子编号+格内位置
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
            grid_position = {cell_index, remainder, pixel[2:0]};//4位格子编号+7位格内位置
        end
    endfunction

    wire [9:0] rel_x_lo = x_lo - maze_x;//得到碰撞盒坐标范围在迷宫内部的坐标
    wire [9:0] rel_y_lo = y_lo - maze_y;
    wire [9:0] rel_x_hi = x_hi - maze_x;
    wire [9:0] rel_y_hi = y_hi - maze_y;
    wire [10:0] grid_x_lo = grid_position(rel_x_lo, map_mode);//将迷宫内部坐标转换为格子位置
    wire [10:0] grid_y_lo = grid_position(rel_y_lo, map_mode);
    wire [10:0] grid_x_hi = grid_position(rel_x_hi, map_mode);
    wire [10:0] grid_y_hi = grid_position(rel_y_hi, map_mode);

    // 根据碰撞箱所在的位置得到需要查询的index，进一步查询这个格子有没有墙
    wire [6:0] idx00 = grid_y_lo[10:7] * MAX_COLS + grid_x_lo[10:7];
    wire [6:0] idx01 = grid_y_lo[10:7] * MAX_COLS + grid_x_hi[10:7];
    wire [6:0] idx10 = grid_y_hi[10:7] * MAX_COLS + grid_x_lo[10:7];
    wire [6:0] idx11 = grid_y_hi[10:7] * MAX_COLS + grid_x_hi[10:7];
    wire spans_cols = grid_x_lo[10:7] != grid_x_hi[10:7];//判断碰撞箱有没有跨越格子边界
    wire spans_rows = grid_y_lo[10:7] != grid_y_hi[10:7];
    wire [6:0] wall_start = cell_size - wall_size;
    wire right_edge = grid_x_hi[6:0] >= wall_start;//判断碰撞箱有没有碰到格子内的墙
    wire bottom_edge = grid_y_hi[6:0] >= wall_start;

    //碰撞包括跨有墙的格子和碰到格子内的墙
    assign hit = outside ||
                 (spans_cols && (right_walls[idx00] || right_walls[idx10])) ||
                 (right_edge && (right_walls[idx01] || right_walls[idx11])) ||
                 (spans_rows && (bottom_walls[idx00] || bottom_walls[idx01])) ||
                 (bottom_edge && (bottom_walls[idx10] || bottom_walls[idx11]));
endmodule

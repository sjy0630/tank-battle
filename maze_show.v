//负责迷宫的渲染


module maze_show (
    input wire [9:0] h_cnt,
    input wire [9:0] v_cnt,
    input wire [1:0] map_mode,
    //获取当前地图的配置
    input wire [6:0] cell_size,
    input wire [3:0] wall_size,
    input wire [9:0] maze_x, maze_y,
    input wire [9:0] maze_w, maze_h,
    input wire [107:0] right_walls,
    input wire [107:0] bottom_walls,
    output wire wall_pixel
);

    `include "param.vh"


    //判断范围和计算相对坐标
    wire in_maze;
    wire [9:0] rel_x, rel_y;

    assign in_maze =
        (h_cnt >= maze_x) &&
        (h_cnt <  maze_x + maze_w) &&
        (v_cnt >= maze_y) &&
        (v_cnt <  maze_y + maze_h);

    assign rel_x = in_maze ? h_cnt - maze_x : 10'd0;
    assign rel_y = in_maze ? v_cnt - maze_y : 10'd0;



    //计算格子坐标及格子内部坐标

    reg [3:0] col, row;
    reg [6:0] local_x, local_y;

    always @(*) begin
        case (map_mode)

            2'd1: begin
                // 中地图：8×6，每格72像素
                col     = rel_x / 72;
                row     = rel_y / 72;
                local_x = rel_x % 72;
                local_y = rel_y % 72;
            end

            2'd2: begin
                // 小地图：6×4，每格96像素
                col     = rel_x / 96;
                row     = rel_y / 96;
                local_x = rel_x % 96;
                local_y = rel_y % 96;
            end

            default: begin
                // 大地图：12×9，每格48像素
                col     = rel_x / 48;
                row     = rel_y / 48;
                local_x = rel_x % 48;
                local_y = rel_y % 48;
            end

        endcase
    end


    //查询墙壁数据
    wire [6:0] index;

    // 始终使用最大的范围存储，方便统一和迷宫生成算法的编写
    assign index = row * MAX_COLS + col;

    wire right_hit, bottom_hit;
    wire left_border, top_border;

    // 当前格子的右墙
    assign right_hit =
        (local_x >= cell_size - wall_size) &&
        right_walls[index];

    // 当前格子的下墙
    assign bottom_hit =
        (local_y >= cell_size - wall_size) &&
        bottom_walls[index];

    // 迷宫最左侧的外围墙
    assign left_border = (rel_x < wall_size);

    // 迷宫最上方的外围墙
    assign top_border = (rel_y < wall_size);



    //最终墙壁像素输出
    assign wall_pixel = in_maze &&
        (right_hit || bottom_hit ||
         left_border || top_border);

endmodule



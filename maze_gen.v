// 随机迷宫生成器：随机深度优先搜索（DFS）+ 额外拆除内墙。
// 生成流程：全部封闭 -> DFS 打通全部格子 -> 拆少量内墙形成环路 -> 提交地图。
// DFS 只向未访问的格子开路，N 个格子恰好开出 N-1 条通路，保证全图连通且无环；
// 后续每额外拆一面内墙，就在原来的连通结构上增加一个独立环路，提供绕行路线。
//
// 墙位约定：1 表示有墙，0 表示通路。每格只保存右墙和下墙，避免重复存储：
// 当前格的左墙由左邻格的右墙表示，上墙由上邻格的下墙表示。
// 最左侧、最上侧的外围墙由显示和碰撞模块单独处理。
//
// 接口约定：start 通常只拉高一个时钟周期；生成期间行列配置应保持不变。
// 支持的配置为 12x9、8x6、6x4，存储空间统一按最大地图 12x9 分配。
module maze_gen (
    input wire clk, start,                  // 上升沿工作；start 优先于当前生成过程
    input wire [15:0] seed,                 // 伪随机初始种子；相同配置和种子可复现地图
    input wire [3:0] maze_cols, maze_rows,   // 本次生成的有效列数、行数，以格为单位
    output wire busy,                      // 非空闲状态为 1，提交完成后恢复为 0
    output reg [107:0] right_walls = {108{1'b1}},  // 已提交地图：每格的右墙
    output reg [107:0] bottom_walls = {108{1'b1}}  // 已提交地图：每格的下墙
);
    `include "param.vh"
    // IDLE：等待；SEARCH：DFS；PICK：抽扫描起点；REMOVE：找墙并拆墙；PUBLISH：提交。
    localparam IDLE = 3'd0, SEARCH = 3'd1, PICK = 3'd2,
               REMOVE = 3'd3, PUBLISH = 3'd4;
    // 方向编码按“右 -> 下 -> 左 -> 上”循环，与 available 的位编号一致。
    localparam [1:0] RIGHT = 2'd0, DOWN = 2'd1, LEFT = 2'd2, UP = 2'd3;

    reg [2:0] state = IDLE;
    reg [15:0] random_value;                // 生成器内部的 16 位 LFSR 状态
    reg [3:0] col, row;                     // 当前格子坐标，从 0 开始编号
    reg [107:0] visited, next_right, next_bottom; // 访问标记，以及尚未提交的两份墙位
    reg [7:0] stack [0:MAX_ROWS*MAX_COLS-1]; // 显式回溯栈：每项为 {row[3:0], col[3:0]}
    reg [6:0] depth;                        // 栈中有效项数，也是下一次入栈的写入位置
    reg [3:0] walls_left;                   // DFS 结束后，还需要额外拆除的内墙数量

    assign busy = state != IDLE;
    // 即使是小地图，每行存储跨度也固定为 MAX_COLS=12，而不是 maze_cols。
    // 例如 (row=1,col=2) 的编号始终为 14；上下邻格相差 12，左右邻格相差 1。
    wire [6:0] index = row * MAX_COLS + col;
    wire [6:0] right_index = index + 7'd1;
    wire [6:0] down_index = index + MAX_COLS;
    wire [6:0] left_index = index - 7'd1;
    wire [6:0] up_index = index - MAX_COLS;
    // 判断邻格是否位于本次地图内，防止 DFS 和额外拆墙越过外围边界。
    wire inside_right = col + 4'd1 < maze_cols;
    wire inside_down = row + 4'd1 < maze_rows;

    // 可选方向必须同时满足“没有越界”和“邻格尚未访问”。
    // available[3:0] 从高到低为上、左、下、右，即 bit0=右、bit1=下、bit2=左、bit3=上。
    // 左边界、上边界处不使用相应邻格的 visited 值，由边界条件排除该方向。
    wire [3:0] available = {row != 0 && !visited[up_index],
                            col != 0 && !visited[left_index],
                            inside_down && !visited[down_index],
                            inside_right && !visited[right_index]};
    // 将位向量重复一遍，再从随机位置取连续 4 位，实现循环旋转检查顺序。
    // 语法 [起始位 +: 4] 表示从起始位开始，向高位选取 4 位。
    // 例如起始方向为 LEFT(2)，order[0..3] 依次对应左、上、右、下。
    wire [7:0] doubled = {available, available};
    wire [3:0] order = doubled[random_value[1:0] +: 4];
    // 优先选择旋转后第一个可走方向；只有 |available 为 1 时才使用选择结果。
    wire [1:0] offset = order[0] ? 2'd0 : order[1] ? 2'd1 : order[2] ? 2'd2 : 2'd3;
    // 两位加法结果截断，相当于 (起始方向 + 偏移) % 4。
    // 这是随机起点加固定循环顺序，并非在可走方向之间严格等概率抽取。
    wire [1:0] direction = random_value[1:0] + offset;

    // 额外拆墙阶段只考虑仍然关闭的内墙；每面内墙只需由右墙或下墙检查一次。
    wire closed_right = inside_right && next_right[index];
    wire closed_down = inside_down && next_bottom[index];

    always @(posedge clk) begin
        if (start) begin
            // start 的优先级最高：即使正在生成，也会丢弃当前进度并重新开始。
            // 这里只重置工作墙位，已提交的输出墙位仍保持原值。
            state <= SEARCH;
            // LFSR 若从全零开始会永远为零，因此把零种子替换为 1。
            random_value <= seed == 0 ? 16'd1 : seed;
            row <= 0;
            col <= 0;
            visited <= 108'd1; // 仅 bit0 为 1，表示起点 (0,0) 已访问
            // 所有墙先封闭；只有后续确认的通路才会把相应墙位置 0。
            next_right <= {108{1'b1}};
            next_bottom <= {108{1'b1}};
            depth <= 0;
            walls_left <= 0;
        end else if (busy) begin
            // 忙碌期间每拍推进 LFSR：左移一位，新最低位由旧 bit15/13/12/10 异或得到。
            // 以下状态逻辑本拍读取的仍是旧 random_value，新值在时钟沿后生效。
            random_value <= {random_value[14:0],
                             random_value[15] ^ random_value[13] ^ random_value[12] ^ random_value[10]};
            case (state)
                SEARCH: begin
                    // |available 是归约或：任意一个方向可走，结果即为 1。
                    if (|available) begin
                        // 前进一步：先将当前格压栈，供走入死胡同后回退。
                        // 本拍同时开墙、更新坐标并标记邻格；下一拍在新格继续搜索。
                        stack[depth] <= {row, col};
                        depth <= depth + 1'b1;
                        case (direction)
                            RIGHT: begin
                                // 右行：拆当前格右墙，进入右邻格。
                                next_right[index] <= 0;
                                col <= col + 1'b1;
                                visited[right_index] <= 1;
                            end
                            DOWN: begin
                                // 下行：拆当前格下墙，进入下邻格。
                                next_bottom[index] <= 0;
                                row <= row + 1'b1;
                                visited[down_index] <= 1;
                            end
                            LEFT: begin
                                // 左行：共用墙保存在左邻格中，所以拆 left_index 的右墙。
                                next_right[left_index] <= 0;
                                col <= col - 1'b1;
                                visited[left_index] <= 1;
                            end
                            UP: begin
                                // 上行：共用墙保存在上邻格中，所以拆 up_index 的下墙。
                                next_bottom[up_index] <= 0;
                                row <= row - 1'b1;
                                visited[up_index] <= 1;
                            end
                        endcase
                    end else if (depth != 0) begin
                        // 当前格没有未访问的邻格，弹栈退回上一层，寻找其他未探索分支。
                        // 回退不会补回墙，也不会清除 visited，避免重复开路形成环路。
                        {row, col} <= stack[depth - 1'b1];
                        depth <= depth - 1'b1;
                    end else begin
                        // 无路可走且栈空，说明已从所有分支退回起点，DFS 遍历完成。
                        // 此时 N 个有效格子已由 N-1 条通路连通；接下来额外拆墙形成环路。
                        // 小图 6×4 拆 1～2 面，中图 8×6 拆 2～5 面，大图 12×9 拆 4～11 面。
                        case (maze_cols)
                            4'd6: walls_left <= 4'd1 + {3'b0, random_value[2]};
                            4'd8: walls_left <= 4'd2 + {2'b0, random_value[3:2]};
                            default: walls_left <= 4'd4 + {1'b0, random_value[4:2]};
                        endcase
                        state <= PICK;
                    end
                end
                PICK: begin
                    // 拒绝采样：仅当随机行、列都有效时，才接受这个扫描起点。
                    // 任一坐标越界就留在 PICK，等 LFSR 下一拍产生新候选值后重试。
                    // 接受后本拍更新坐标，下一拍进入 REMOVE 再检查这个格子的墙。
                    if (random_value[3:0] < maze_cols && random_value[7:4] < maze_rows) begin
                        col <= random_value[3:0];
                        row <= random_value[7:4];
                        state <= REMOVE;
                    end
                end
                REMOVE: begin
                    if (closed_right || closed_down) begin
                        // 只有右墙可拆时选右墙；只有下墙可拆拆下墙；两面都可拆时由随机最低位决定。
                        if (closed_right && (!closed_down || random_value[0]))
                            next_right[index] <= 0;
                        else
                            next_bottom[index] <= 0;
                        // 拆过的墙已变为 0，后续不会被再次计数。
                        walls_left <= walls_left - 1'b1;
                        // 非阻塞赋值读取旧值：本拍拆除前若只剩 1 面，拆完就转入提交。
                        state <= walls_left == 1 ? PUBLISH : PICK;
                    // 本格没有可拆墙时，按从左到右、从上到下的顺序继续扫描。
                    end else if (inside_right)
                        col <= col + 1'b1;
                    else begin
                        // 行尾回到第 0 列；最后一行之后回绕到第 0 行，循环查找。
                        // 三种支持尺寸在拆够目标数量前都有剩余内墙，因此可继续找到目标。
                        col <= 0;
                        row <= inside_down ? row + 1'b1 : 4'd0;
                    end
                end
                PUBLISH: begin
                    // 一次性提交两份完整墙位，生成中的中间结果不送给碰撞和绘制模块。
                    // 同一时钟沿回到 IDLE，输出更新后 busy 随之变为 0。
                    right_walls <= next_right;
                    bottom_walls <= next_bottom;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

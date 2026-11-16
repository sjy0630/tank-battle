module tank_control(
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_tick,   // 每帧更新一次位置
    input  wire       up, down, left, right,   // 已经同步好的按键
    input  wire [9:0] spawn_x, spawn_y,
    input  wire [2:0] sprite_scale,
    input  wire [1:0] map_mode,
    input  wire [6:0] cell_size,
    input  wire [3:0] wall_size,
    input  wire [9:0] maze_x, maze_y, maze_w, maze_h,
    input  wire [107:0] right_walls, bottom_walls,
    output wire [9:0] h_tank,v_tank, //坦克的位置，这里位置是坦克贴图的中心
    output wire [4:0] dir,//坦克的角度姿态
    output wire signed [9:0] forward_dx, forward_dy
);
    `include "param.vh"

    reg signed [7:0]tank_angle; //坦克角度,取前5位位最终姿态，每帧加减ROT_SPEED，按60帧每秒来算转一圈大约1.4秒
    reg signed [FRAC_BITS+9:0] pos_x,pos_y;//坦克位置，取前10位最终位置
    assign h_tank = pos_x[FRAC_BITS +: 10];
    assign v_tank = pos_y[FRAC_BITS +: 10];
    assign dir = tank_angle[7:3];
    always @(posedge clk) begin
        if(rst) begin
            tank_angle <= 0;
        end
        else if(frame_tick) begin
            if(left & !right)
                tank_angle <= tank_angle - ROT_SPEED;
            if(right & !left)
                tank_angle <= tank_angle + ROT_SPEED;
        end
    end
 
    // 32 个方向的基础位移（单位：1/64 像素），大地图速度 1.5 像素/帧
    // vx = round(96*sin θ)，vy = round(-96*cos θ)，θ = dir * 11.25°
    reg signed [7:0] vx, vy;
    always @(*) begin //该死的vivado没有三角函数，所以要把不同姿态的对应x，y速度分别算出来
        case (dir)
            5'd0 : begin vx =    8'sd0; vy =  -8'sd96; end   // 朝上
            5'd1 : begin vx =   8'sd19; vy =  -8'sd94; end
            5'd2 : begin vx =   8'sd37; vy =  -8'sd89; end
            5'd3 : begin vx =   8'sd53; vy =  -8'sd80; end
            5'd4 : begin vx =   8'sd68; vy =  -8'sd68; end   // 右上 45°
            5'd5 : begin vx =   8'sd80; vy =  -8'sd53; end
            5'd6 : begin vx =   8'sd89; vy =  -8'sd37; end
            5'd7 : begin vx =   8'sd94; vy =  -8'sd19; end
            5'd8 : begin vx =   8'sd96; vy =    8'sd0; end   // 朝右
            5'd9 : begin vx =   8'sd94; vy =   8'sd19; end
            5'd10: begin vx =   8'sd89; vy =   8'sd37; end
            5'd11: begin vx =   8'sd80; vy =   8'sd53; end
            5'd12: begin vx =   8'sd68; vy =   8'sd68; end
            5'd13: begin vx =   8'sd53; vy =   8'sd80; end
            5'd14: begin vx =   8'sd37; vy =   8'sd89; end
            5'd15: begin vx =   8'sd19; vy =   8'sd94; end
            5'd16: begin vx =    8'sd0; vy =   8'sd96; end   // 朝下
            5'd17: begin vx =  -8'sd19; vy =   8'sd94; end
            5'd18: begin vx =  -8'sd37; vy =   8'sd89; end
            5'd19: begin vx =  -8'sd53; vy =   8'sd80; end
            5'd20: begin vx =  -8'sd68; vy =   8'sd68; end
            5'd21: begin vx =  -8'sd80; vy =   8'sd53; end
            5'd22: begin vx =  -8'sd89; vy =   8'sd37; end
            5'd23: begin vx =  -8'sd94; vy =   8'sd19; end
            5'd24: begin vx =  -8'sd96; vy =    8'sd0; end   // 朝左
            5'd25: begin vx =  -8'sd94; vy =  -8'sd19; end
            5'd26: begin vx =  -8'sd89; vy =  -8'sd37; end
            5'd27: begin vx =  -8'sd80; vy =  -8'sd53; end
            5'd28: begin vx =  -8'sd68; vy =  -8'sd68; end
            5'd29: begin vx =  -8'sd53; vy =  -8'sd80; end
            5'd30: begin vx =  -8'sd37; vy =  -8'sd89; end
            5'd31: begin vx =  -8'sd19; vy =  -8'sd94; end
        endcase
    end


    // 用带符号的宽位移做 3/2 或 2 倍缩放，正负方向都向零取整。
    wire signed [9:0] base_dx = {{2{vx[7]}}, vx};
    wire signed [9:0] base_dy = {{2{vy[7]}}, vy};
    reg signed [9:0] dx, dy;
    always @(*) begin
        case (sprite_scale)
            3'd3: begin
                dx = (base_dx * 10'sd3) / 10'sd2;
                dy = (base_dy * 10'sd3) / 10'sd2;
            end
            3'd4: begin
                dx = base_dx <<< 1;
                dy = base_dy <<< 1;
            end
            default: begin
                dx = base_dx;
                dy = base_dy;
            end
        endcase
    end

    assign forward_dx = dx;
    assign forward_dy = dy;

    wire [5:0] radius = (TANK_R * sprite_scale) >> 1;
    wire hit_x, hit_y;
    maze_collision u_collision (
        .x(h_tank), .y(v_tank),
        .next_x((pos_x + (down ? -dx : dx)) >> FRAC_BITS),
        .next_y((pos_y + (down ? -dy : dy)) >> FRAC_BITS),
        .radius(radius),
        .map_mode(map_mode), .cell_size(cell_size), .wall_size(wall_size),
        .maze_x(maze_x), .maze_y(maze_y), .maze_w(maze_w), .maze_h(maze_h),
        .right_walls(right_walls), .bottom_walls(bottom_walls),
        .hit_x(hit_x), .hit_y(hit_y)
    );

    always @(posedge clk) begin //位置移动控制逻辑
        if(rst) begin
            // 出生点以像素输入，左移 FRAC_BITS 位换成定点数。
            pos_x <= spawn_x << FRAC_BITS;
            pos_y <= spawn_y << FRAC_BITS;
        end else if (frame_tick && (up ^ down)) begin
            pos_x <= pos_x + (hit_x ? 10'sd0 : (down ? -dx : dx));
            pos_y <= pos_y + (hit_y ? 10'sd0 : (down ? -dy : dy));
        end
    end



endmodule

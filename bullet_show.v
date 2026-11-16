// 按每个有效子弹的中心和半径绘制方形像素区域。
module bullet_show (
    input wire [9:0] h_cnt, v_cnt,
    input wire [5:0] radius,
    input wire [4:0] active,
    input wire [49:0] bullet_x, bullet_y,
    output wire bullet_pixel
);
    `include "param.vh"
    wire [MAX_BULLETS-1:0] hit;
    genvar n;
    generate for (n = 0; n < MAX_BULLETS; n = n + 1) begin : draw_bullet
        wire [9:0] x = bullet_x[n*10 +: 10];
        wire [9:0] y = bullet_y[n*10 +: 10];
        assign hit[n] = active[n] &&
                        h_cnt + radius >= x && h_cnt < x + radius &&
                         v_cnt + radius >= y && v_cnt < y + radius;
    end endgenerate
    assign bullet_pixel = |hit;//这个像素只要有子弹像素就画上去
endmodule

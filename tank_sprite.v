module tank_sprite (
    input  wire [9:0] h_cnt,
    input  wire [9:0] v_cnt,
    input  wire [9:0] h_tank,
    input  wire [9:0] v_tank,
    input  wire [4:0] dir,
    input  wire [6:0] tank_size,
    input  wire [2:0] sprite_scale,
    output wire tank_pixel,
    output reg  [11:0] tank_rgb
);

    `include "param.vh"


    reg [1:0] sprite_rom [0:8191];

    initial begin
        $readmemh("tank.mem", sprite_rom);
    end//把提前准备好的坦克贴图存进ROM中

    // 以坦克中心为基准，判断当前像素是否落在缩放后的贴图范围内。
    wire [10:0] half_size = {4'b0000, tank_size} >> 1;
    wire in_tank;
    assign in_tank =  (h_cnt + half_size >= h_tank) &&
    (h_cnt < h_tank + half_size) &&
    (v_cnt + half_size >= v_tank) &&
    (v_cnt < v_tank + half_size);

    reg [3:0] sprite_x, sprite_y;
    wire [12:0] rom_addr;

    // 屏幕上的贴图内坐标除以放大倍数，得到 16×16 ROM 的坐标。
    wire [6:0] offset_x = in_tank ? h_cnt - h_tank + half_size : 7'd0;
    wire [6:0] offset_y = in_tank ? v_cnt - v_tank + half_size : 7'd0;
    always @(*) begin
        case (sprite_scale)
            3'd3: begin
                sprite_x = offset_x / 7'd3;
                sprite_y = offset_y / 7'd3;
            end
            3'd4: begin
                sprite_x = offset_x >> 2;
                sprite_y = offset_y >> 2;
            end
            default: begin
                sprite_x = offset_x >> 1;
                sprite_y = offset_y >> 1;
            end
        endcase
    end

    assign rom_addr ={dir,sprite_y,sprite_x};

    wire [1:0] pixel_data;

    assign pixel_data = sprite_rom[rom_addr];

    // 只有在贴图范围内，且像素不透明，才显示坦克
    assign tank_pixel = in_tank &&
                        (pixel_data != 2'b00);

    always @(*) begin
        case (pixel_data)
            2'b01: tank_rgb = COLOR_P1;//车身
            2'b10: tank_rgb = 12'h632;//履带
            2'b11: tank_rgb = 12'hA32;//炮塔和炮管
            default: tank_rgb = COLOR_BG;//背景
        endcase
    end

endmodule

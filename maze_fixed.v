module maze_fixed (
    input wire [1:0] map_mode,
    output reg [107:0] right_walls,
    output reg [107:0] bottom_walls
);

    always @(*) begin
    case (map_mode)
    2'd1: begin// 中地图：8×6
    right_walls  = 108'hFFFFFFFFFFD4FE3FAFF9CFA4F80;
    bottom_walls = 108'hFFFFFFFFFFFFF50F08FA0FC4FB2;
    end
    2'd2: begin
    // 小地图：6×4
    right_walls  = 108'hFFFFFFFFFFFFFFFFE3FEFFE2FE0;
    bottom_walls = 108'hFFFFFFFFFFFFFFFFFFFD8FE0FE2;
    end
    default: begin
    // 大地图：12×9
    right_walls  = 108'h947B4699AF25D86DC0980990800;
    bottom_walls = 108'hFFF530972C8A01447207A4B6CDE;
    end
    endcase
    end

endmodule
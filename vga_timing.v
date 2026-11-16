module vga_timing(
    input clk,
    input rst,
    output reg [9:0] h_cnt,
    output reg [9:0] v_cnt,
    output reg h_sync,
    output reg v_sync,
    output reg video_on,
    output reg frame_tick,
    output pix_en
    );
    reg [1:0]cnt;
    always @(posedge clk) begin
        if (rst) begin
            cnt <=0;
        end
        else begin
        cnt <= cnt+1;
        end
    end
    assign pix_en = (cnt == 2'b11);
    //时钟分频，25MHz，同时传给输出，在其他模块也可以用分频后的时钟信号

    `include "param.vh"
    always @(posedge clk)begin
        frame_tick <= 0;
        if (rst) begin
            h_cnt <= 0;
            v_cnt <= 0;
            frame_tick <= 0;
        end
        else if(h_cnt< H_TOTAL-1 && pix_en)begin
            h_cnt <= h_cnt+1;
        end
        else if(pix_en)begin
            h_cnt <= 0;
            if(v_cnt < V_TOTAL-1)begin
            v_cnt <= v_cnt+1; end
            else begin
            v_cnt <= 0;
            frame_tick <= 1;
            end
        end
    end    //h_cnt,v_cnt计数逻辑与frame_tick的触发

    always @(*)begin
        v_sync = 1;
        h_sync = 1;
        if(rst) begin
            v_sync = 1;
        end
        else if(v_cnt >= V_VISIBLE + V_FP && v_cnt < V_VISIBLE +  V_FP + V_SYNC)begin
            v_sync =0;end
        if(rst) begin
            h_sync = 1;
        end
        else if(h_cnt >= H_VISIBLE + H_FP && h_cnt < H_VISIBLE + H_FP + H_SYNC)begin
            h_sync = 0; end
    end //v_sync,h_sync的判断

    always @(*) begin
        video_on = 0;
        if(v_cnt < V_VISIBLE && h_cnt < H_VISIBLE && !rst) begin
            video_on = 1;end
    end//video_on的判定逻辑

endmodule

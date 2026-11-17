// 根据双方命中结果计分，并控制回合间隔。
module round_control (
    input wire clk, rst, frame_tick, hit_p1, hit_p2,
    output wire playing, match_over,
    output reg restart_round,
    output reg [1:0] tank_alive,
    output reg [2:0] score_p1, score_p2
);
    `include "param.vh"
    localparam PLAYING = 2'd0, ROUND_WAIT = 2'd1, FINISHED = 2'd2;
    reg [1:0] state;
    reg [6:0] wait_frames;
    assign playing = state == PLAYING;
    assign match_over = state == FINISHED;

    always @(posedge clk) begin
        if (rst) begin
            state <= PLAYING;
            tank_alive <= 2'b11;
            score_p1 <= 0;
            score_p2 <= 0;
            wait_frames <= 0;
            restart_round <= 0;
        end else begin
            restart_round <= 0;
            if (frame_tick) begin
                case (state)
                    PLAYING: if (hit_p1 || hit_p2) begin
                        tank_alive <= {~hit_p2, ~hit_p1};
                        wait_frames <= 0;
                        state <= ROUND_WAIT;
                        // 同一帧双方都命中时为平局。
                        if (hit_p2 && !hit_p1) begin
                            score_p1 <= score_p1 + 1'b1;
                            if (score_p1 == WIN_SCORE-1)
                                state <= FINISHED;
                        end
                        if (hit_p1 && !hit_p2) begin
                            score_p2 <= score_p2 + 1'b1;
                            if (score_p2 == WIN_SCORE-1)
                                state <= FINISHED;
                        end
                    end
                    ROUND_WAIT: if (wait_frames == ROUND_DELAY-1) begin
                        restart_round <= 1;
                        tank_alive <= 2'b11;
                        state <= PLAYING;
                    end else
                        wait_frames <= wait_frames + 1'b1;
                    FINISHED: begin end
                    default: state <= PLAYING;
                endcase
            end
        end
    end
endmodule

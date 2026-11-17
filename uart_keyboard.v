// 电脑通过 J4 送来两位玩家的按键状态，串口为 115200、8N1。
module uart_keyboard (
    input wire clk, rst, rx, frame_tick,
    output reg [4:0] p1_keys, p2_keys,
    output reg packet_seen, link_alive
);
    localparam [9:0] BIT_CLKS = 868; // 100 MHz 下一个串口位约 868 拍
    // J4 的接收线和板载时钟不同步，先经过两级寄存器，再用 rx_sync。
    reg rx_sample, rx_sync;
    reg [9:0] count;
    // 0 等待，1 检查起始位，2～9 接收 8 个数据位，10 检查停止位。
    reg [3:0] bit_index;
    reg [7:0] data;
    reg byte_ready, frame_error;

    always @(posedge clk) begin
        if (rst) begin
            rx_sample <= 1'b1;
            rx_sync <= 1'b1;
            count <= 0;
            bit_index <= 0;
            data <= 0;
            byte_ready <= 0;
            frame_error <= 0;
        end else begin
            rx_sample <= rx;
            rx_sync <= rx_sample;
            // 收好一个字节或遇到停止位错误时，相应信号只拉高一拍。
            byte_ready <= 0;
            frame_error <= 0;
            if (bit_index == 0) begin
                if (!rx_sync) begin
                    // 空闲时线路为高。看到低电平后先等半个位，在起始位中央确认。
                    count <= BIT_CLKS / 2 - 1'b1;
                    bit_index <= 1;
                end
            end else if (count != 0) begin
                count <= count - 1'b1;
            end else begin
                // 确认起始位后，每隔一整个位采样一次，采样点仍在位的中央。
                count <= BIT_CLKS - 1'b1;
                bit_index <= bit_index + 1'b1;
                case (bit_index)
                    1: if (rx_sync) bit_index <= 0; // 起始位中间要为低
                    10: begin
                        bit_index <= 0;
                        byte_ready <= rx_sync; // 停止位要为高
                        frame_error <= !rx_sync;
                    end
                    default: data <= {rx_sync, data[7:1]}; // 低位先到，连续右移后恢复原字节位序
                endcase
            end
        end
    end

    // 两个字节的高三位分别是 101、110，低五位是各自的按键。
    // 低五位从高到低是开火、右转、左转、后退、前进。按 W 时收到 A1 C0。
    // 收齐后一起更新。近 1/4 秒没有新包，就松开串口上的所有键。
    reg [4:0] p1_next;
    reg p1_received;
    reg [3:0] quiet_frames;
    // 已暂存红方字节，再收到蓝方字节，就能同时更新双方按键。
    wire packet_ready = byte_ready && data[7:5] == 3'b110 && p1_received;

    always @(posedge clk) begin
        if (rst) begin
            p1_next <= 0;
            p1_received <= 0;
            p1_keys <= 0;
            p2_keys <= 0;
            packet_seen <= 0;
            link_alive <= 0;
            quiet_frames <= 0;
        end else begin
            if (byte_ready) begin
                p1_received <= data[7:5] == 3'b101;
                if (data[7:5] == 3'b101)
                    p1_next <= data[4:0];
            end
            // 停止位出错时丢掉已暂存的红方字节，等下一组完整数据。
            if (frame_error)
                p1_received <= 0;

            if (packet_ready) begin
                p1_keys <= p1_next;
                p2_keys <= data[4:0];
                packet_seen <= 1;
                link_alive <= 1;
                quiet_frames <= 0;
            end else if (frame_tick) begin
                // 连续 15 个 VGA 帧没收到完整数据，就清掉双方按键。
                if (quiet_frames == 14) begin
                    p1_received <= 0;
                    p1_keys <= 0;
                    p2_keys <= 0;
                    link_alive <= 0;
                    quiet_frames <= 0;
                end else
                    quiet_frames <= quiet_frames + 1'b1;
            end
        end
    end
endmodule

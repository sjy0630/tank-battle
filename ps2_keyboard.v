// Basys3 USB HID 桥输出 PS/2 Set 2 扫描码。每个键单独记录按住状态。
module ps2_keyboard (
    input wire clk, rst, ps2_clk, ps2_data,
    output reg [4:0] p1_keys, p2_keys,
    output reg clock_seen, byte_seen, frame_error,
    output reg [7:0] last_byte
);
    // 端口位序为 {开火, 右转, 左转, 后退, 前进}。
    // J2 上的键盘先经过板载 USB 转 PS/2 芯片。时钟和数据都要同步到 clk。
    reg ps2_clk_sample, ps2_clk_sync, ps2_clk_prev;
    reg ps2_data_sample, ps2_data_sync;
    // 比较同步后的时钟和它的上一拍。先高后低，就读同步后的数据位。
    wire falling_edge = ps2_clk_prev && !ps2_clk_sync;
    wire data_bit = ps2_data_sync;
    // 0 等待起始位，1～8 收数据，9 查奇校验，10 查停止位。
    reg [3:0] bit_count;
    reg [7:0] scan_code;
    reg parity_ok, extended, releasing;
    reg [17:0] timeout_count;

    always @(posedge clk) begin
        if (rst) begin
            // PS/2 空闲时两根线都是高电平。
            ps2_clk_sample <= 1'b1;
            ps2_clk_sync   <= 1'b1;
            ps2_clk_prev   <= 1'b1;
            ps2_data_sample <= 1'b1;
            ps2_data_sync   <= 1'b1;
        end else begin
            ps2_clk_sample <= ps2_clk;
            ps2_clk_sync   <= ps2_clk_sample;
            ps2_clk_prev   <= ps2_clk_sync;
            ps2_data_sample <= ps2_data;
            ps2_data_sync   <= ps2_data_sample;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            bit_count <= 0;
            timeout_count <= 0;
            parity_ok <= 0;
            extended <= 0;
            releasing <= 0;
            p1_keys <= 0;
            p2_keys <= 0;
            // 诊断标志置位后保留到复位，last_byte 记录最近的有效字节。
            clock_seen <= 0;
            byte_seen <= 0;
            frame_error <= 0;
            last_byte <= 0;
        end else if (falling_edge) begin
            clock_seen <= 1;
            timeout_count <= 0;
            if (bit_count == 0) begin
                // 起始位为低才开始收这一帧。
                if (!data_bit)
                    bit_count <= 1;
            end else if (bit_count <= 8) begin
                // 低位先到，第一个数据位存到 scan_code[0]。
                scan_code[bit_count-1'b1] <= data_bit;
                bit_count <= bit_count + 1'b1;
            end else if (bit_count == 9) begin
                // 对数据和校验位一起做归约异或。1 的总数为奇数时，结果为 1。
                parity_ok <= ^{scan_code, data_bit};
                bit_count <= 10;
            end else begin
                bit_count <= 0;
                // 停止位为高且奇校验通过，才接受这个字节。
                if (data_bit && parity_ok) begin
                    byte_seen <= 1;
                    last_byte <= scan_code;
                end else
                    frame_error <= 1;
                // E0 表示扩展键，F0 表示松键。收到前缀时先记住，等实际键码。
                // 比如 W 按下是 1D，松开是 F0 1D。上方向键松开是 E0 F0 75。
                if (data_bit && parity_ok && scan_code == 8'hE0)
                    extended <= 1;
                else if (data_bit && parity_ok && scan_code == 8'hF0)
                    releasing <= 1;
                else begin
                    // 用这一拍开始时保存的前缀解码，拍末清掉前缀。
                    // releasing 为 0 就把该键置 1，为 1 就把该键清 0。
                    extended <= 0;
                    releasing <= 0;
                    if (data_bit && parity_ok) begin
                        case ({extended, scan_code})
                            9'h01D: p1_keys[0] <= !releasing; // W
                            9'h01B: p1_keys[1] <= !releasing; // S
                            9'h01C: p1_keys[2] <= !releasing; // A
                            9'h023: p1_keys[3] <= !releasing; // D
                            9'h029: p1_keys[4] <= !releasing; // Space
                            9'h175: p2_keys[0] <= !releasing; // Up
                            9'h172: p2_keys[1] <= !releasing; // Down
                            9'h16B: p2_keys[2] <= !releasing; // Left
                            9'h174: p2_keys[3] <= !releasing; // Right
                            9'h05A: p2_keys[4] <= !releasing; // Enter
                            9'h0AA: begin // 键盘重新上电
                                p1_keys <= 0;
                                p2_keys <= 0;
                            end
                            default: begin end
                        endcase
                    end
                end
            end
        end else if (bit_count != 0 || extended || releasing) begin
            // 100 MHz 下 2 ms 没有后续时钟，丢弃残缺帧或前缀。
            if (timeout_count == 18'd199999) begin
                frame_error <= 1;
                bit_count <= 0;
                timeout_count <= 0;
                extended <= 0;
                releasing <= 0;
            end else
                timeout_count <= timeout_count + 1'b1;
        end
    end
endmodule

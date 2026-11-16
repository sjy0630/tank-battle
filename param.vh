// ============================================================
// params.vh —— 全局参数，在各模块内部 `include
// ============================================================

// ---------- VGA 时序（640×480@60Hz 标准，单位：像素时钟） ----------
localparam H_VISIBLE = 640;
localparam H_FP      = 16;     // 前沿
localparam H_SYNC    = 96;     // 同步脉冲
localparam H_BP      = 48;     // 后沿
localparam H_TOTAL   = H_VISIBLE + H_FP + H_SYNC + H_BP;   // 800

localparam V_VISIBLE = 480;
localparam V_FP      = 10;
localparam V_SYNC    = 2;
localparam V_BP      = 33;
localparam V_TOTAL   = V_VISIBLE + V_FP + V_SYNC + V_BP;   // 525

// ---------- 画面布局 ----------
localparam HUD_H     = 32;     // 顶部状态栏高度

// ---------- 迷宫 ----------
localparam CELL      = 48;     // 每格边长
localparam WALL      = 4;      // 墙厚
localparam MAX_COLS  = 12;     // 最大地图 12×9
localparam MAX_ROWS  = 9;

// ---------- 坦克 ----------
localparam SPRITE    = 16;     // ROM 中贴图边长
localparam TANK_SCALE= 2;      // 放大倍数
localparam TANK_SIZE = SPRITE * TANK_SCALE;   // 屏幕上 32×32
localparam N_DIR     = 32;     // 方向数，与 tank.mem 一致
localparam TANK_R    = 14;     // 碰撞半径，比贴图略小，手感更宽容
localparam ROT_SPEED = 3;      // 每隔一帧转单位为3的角度（转一圈约 1.4 秒）

// ---------- 定点数 ----------
// 坐标用定点数：低 FRAC_BITS 位是小数部分，这样速度可以是 1.5 像素/帧
localparam FRAC_BITS   = 6;    // 1 像素 = 64 个单位
localparam TANK_SPEED  = 96;   // 1.5 像素/帧
localparam BULLET_SPEED= 192;  // 3 像素/帧，比坦克快一倍

// ---------- 子弹 ----------
localparam BULLET_R    = 3;    // 半径，直径 6 像素
localparam MAX_BULLETS = 5;    // 每个玩家同时最多 5 发
localparam BULLET_LIFE = 480;  // 存活帧数，60 帧/秒 → 8 秒

// ---------- 游戏规则 ----------
localparam WIN_SCORE   = 5;    // 先得 5 分获胜
localparam ROUND_DELAY = 120;  // 一局结束后停顿 2 秒再开下一局

// ---------- 颜色（12 位：RGB 各 4 位） ----------
localparam COLOR_BG     = 12'hDDD;   // 地面浅灰
localparam COLOR_WALL   = 12'h555;   // 墙深灰
localparam COLOR_HUD    = 12'h223;   // 状态栏深蓝灰
localparam COLOR_P1     = 12'hE54;   // 玩家 1 红
localparam COLOR_P2     = 12'h48E;   // 玩家 2 蓝
localparam COLOR_BULLET = 12'h111;   // 子弹黑
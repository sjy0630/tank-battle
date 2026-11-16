# FPGA 坦克动荡

这是一个运行在 Basys3 上的单坦克迷宫小游戏，使用 Verilog 编写，并通过 VGA 输出 640×480 画面。当前版本支持三档地图、坦克移动与挡墙、发射子弹和子弹反弹。

## 一、模块结构

系统以 [`top_module`](top.v) 为顶层。**控制侧决定游戏状态，显示侧把状态转换成 VGA 像素。** 顶层负责板级输入输出和两侧的连线。

### 1. 模块实例层级

箭头表示模块实例化关系。`bullet_control` 用 `generate` 实例化 5 个 `bullet`。坦克和每颗子弹各有一套 `maze_collision`，每套内含两路 `maze_overlap`，分别检查 X 和 Y 的候选位置。

```mermaid
flowchart TB
    top["top_module"]
    top --> control["game_control｜游戏控制"]
    top --> show["game_show｜VGA 显示"]

    control --> config["maze_config"]
    control --> fixedMap["maze_fixed"]
    control --> tankControl["tank_control"]
    control --> bulletControl["bullet_control"]

    tankControl --> tankCollision["maze_collision｜坦克"]
    tankCollision --> tankCheck["maze_overlap × 2｜查 X 和 Y"]
    bulletControl -->|"实例化 5 份"| bullet["bullet｜单颗子弹"]
    bullet --> bulletCollision["maze_collision｜每颗一套"]
    bulletCollision --> bulletCheck["maze_overlap × 2｜查 X 和 Y"]

    show --> timing["vga_timing"]
    show --> mazeShow["maze_show"]
    show --> tankSprite["tank_sprite"]
    show --> bulletShow["bullet_show"]
```

### 2. 控制与显示之间的信号流

```mermaid
flowchart LR
    buttons["板上按键与 SW15"] -->|"操作与复位"| control["game_control"]
    control -->|"地图配置、墙位、坦克与子弹状态"| show["game_show"]
    show -.->|"frame_tick｜每帧一个更新脉冲"| control
    show -->|"RGB、Hsync、Vsync"| vga["VGA 显示器"]
```

1. **复位选图。** 控制侧锁存随机样本。`maze_config` 选地图档位，`maze_fixed` 用同一个档位输出对应的墙位。控制侧用墙位判断碰撞，显示侧用同一份墙位画墙。 [`game_control.v`](game_control.v) · [`maze_config.v`](maze_config.v) · [`maze_fixed.v`](maze_fixed.v)
2. **每帧更新状态。** `vga_timing` 产生 `frame_tick`。`tank_control` 根据两个轴的碰撞结果提交位置。`bullet_control` 检测开火按键，只给第一个空闲的 `bullet` 发出 `launch`。每颗子弹各自处理移动、反弹和寿命，显示侧用 `bullet_active` 筛选要画的槽。 [`tank_control.v`](tank_control.v) · [`bullet_control.v`](bullet_control.v) · [`bullet.v`](bullet.v)
3. **逐像素合成画面。** `vga_timing` 把扫描坐标送给墙、坦克和子弹绘制模块。`game_show` 在可见区按坦克、墙、子弹、地面的优先级选择颜色，消隐区输出黑色。 [`vga_timing.v`](vga_timing.v) · [`game_show.v`](game_show.v) · [`maze_show.v`](maze_show.v) · [`tank_sprite.v`](tank_sprite.v) · [`bullet_show.v`](bullet_show.v)

[`param.vh`](param.vh) 是公共参数头文件，[`tank.mem`](tank.mem) 是坦克贴图 ROM 数据。`maze_gen.v` 和 `seg7_hex.v` 分别预留给随机墙布局和数码管显示。

## 二、操作方式

| 输入 | 功能 |
| --- | --- |
| 上、下键 | 沿坦克当前朝向前进、后退 |
| 左、右键 | 旋转坦克 |
| 中心键 `BTN_C` | 点按发射一颗子弹。重新发射前需松开按键 |
| `SW15` | 拨上复位并抽取地图，拨下开始游戏 |

上电默认使用大地图。每次进入复位时锁存一次 LFSR 的伪随机样本，以此选择一套固定墙布局。地图配置在本局中保持稳定，连续两次复位可能选中同一档。

| 地图 | 格子数 | 格子边长 | 墙厚 | 坦克贴图 | 坦克速度 | 子弹半径 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 大 | 12×9 | 48 px | 4 px | 32×32 px | 1.5 px/帧 | 3 px |
| 中 | 8×6 | 72 px | 6 px | 48×48 px | 2.25 px/帧 | 5 px |
| 小 | 6×4 | 96 px | 8 px | 64×64 px | 3 px/帧 | 6 px |

每颗子弹从坦克中心沿当前朝向发射，初速是同档坦克的两倍。场上最多同时存在 5 颗子弹，每颗存活 480 帧，约 8 秒。当前已实现子弹与墙的交互。子弹命中坦克、双人对战和计分属于后续开发内容。

## 三、关键实现

- **墙位是渲染和碰撞的共同依据。** 每个格子有一位右墙和一位下墙。三档地图都用 `row * 12 + col` 编号。绘墙时判断像素是否落在墙带，碰撞时判断整个碰撞盒是否覆盖墙带。
- **组合逻辑完成分轴碰撞。** `maze_collision` 先用 `maze_overlap` 检查 `(next_x, y)`。如果 X 受阻，采用原坐标 `x`，再用第二路检查 `(accepted_x, next_y)`。组合逻辑输出 `hit_x`、`hit_y`，控制模块在 `frame_tick` 对应的时钟沿采样结果。坦克在受阻的轴上保留坐标，子弹还会反转该轴速度。 [`maze_collision.v`](maze_collision.v)
- **每颗子弹只有两个状态。** `IDLE` 收到 `launch` 时保存初始坐标和速度，清零计数并进入 `FLYING`。之后每帧更新位置、速度和计数，到第 480 帧回到 `IDLE`，槽位可再次分配。 [`bullet.v`](bullet.v)
- **用定点数保存亚像素位移。** `FRAC_BITS = 6`，位置寄存器中 64 个单位代表 1 像素。显示取整数像素坐标，状态更新继续保留小数部分。

## 四、验证记录

- **当前组合查墙版**（[`62b5da3`](https://github.com/sjy0630/tank-battle/commit/62b5da37007e677c17cbaa2f0c07b2ef097eb9d2)）已通过 Vivado 2019.1 的 Verilog 源码编译检查。该版的布局布线时序与资源占用以重新生成的 Vivado 报告为准。
- **早期流水线版**（[`d04f33a`](https://github.com/sjy0630/tank-battle/commit/d04f33a81efe85e57bc5cea18de243fd49f66acf)）对三档地图做过 1,272 次碰撞盒与逐像素参考判断的比对，并验证了贴墙滑动、横纵反弹、五发上限、到期回收和从中心键到 VGA 像素的链路。该版布线后满足 100 MHz 约束，最差建立时间余量为 +0.844 ns。

仓库保存原工程 `sources_1/new` 中的设计源码。用 Vivado 重建时，将 `top_module` 设为综合顶层，加入 `tank.mem`，并使用原工程的 Basys3 引脚约束。

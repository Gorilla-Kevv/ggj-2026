# PathGuide 寻路指引系统 — 设计文档

> 日期：2026-08-14
> 状态：已确认，待实现

## 目标

为玩家提供一条**半透明、动态流动的蓝色虚线**，沿设计师手画的路径（`Path2D`）从玩家当前位置指向关卡终点。终点节点可直接拖入（`@export destination`），无需脚本耦合。玩家移动时线头实时跟随，已走过的路段自动消失（面包屑式引导）。

## 非目标

- 不做实时避障（A*/NavigationServer2D）。路径由设计师用 `Path2D` 曲线手工保证不穿墙。
- 不做多终点/多路径。每个 `PathGuide` 实例对应一条路径一个终点。

## 架构

单一节点组件，复用现有 `dashed_line_2d.gd` 的手绘虚线思路（无 shader、无粒子依赖）。

```
PathGuide (Node2D, 挂 path_guide.gd)
└── Path (Path2D, 手画曲线)
```

- `src/systems/path_guide.gd` — 主脚本
- `src/scenes/path_guide.tscn` — 模板场景（Node2D + Path2D 子节点），拖入关卡后画曲线、指终点即可

## 组件接口（导出属性）

| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `destination` | `Node2D` | `null` | 终点节点（拖入 `ExitPortal` / `Marker2D`），取其 `global_position` |
| `path` | `Path2D` | `null` | 路径曲线；留空时在 `_ready` 自动取第一个 `Path2D` 子节点 |
| `line_color` | `Color` | `Color(0.4, 0.7, 1.0, 0.5)` | 半透明蓝 |
| `line_width` | `float` | `3.0` | 线宽 |
| `dash_length` | `float` | `12.0` | 虚线段长 |
| `gap_length` | `float` | `8.0` | 虚空间隙 |
| `flow_speed` | `float` | `30.0` | 流动速度（px/s，朝终点方向） |
| `arrive_distance` | `float` | `40.0` | 玩家离终点小于该值自动隐藏 |

## 数据流（每帧 `_process`）

1. 若未启用（`_enabled == false`）→ 清空点列，`queue_redraw()`，返回。
2. 取玩家（`get_tree().get_first_node_in_group("player")`）；无玩家或 `destination` 无效 → 清空。
3. 玩家距 `destination` ≤ `arrive_distance` → 清空（已到达，隐藏）。
4. 构建完整世界坐标点列：
   - `Path2D.curve.get_baked_points()` 逐点 `path.to_global()` 转世界坐标；
   - 末点若距 `destination` > 1px，追加 `destination.global_position`（保证精确落到终点）。
5. **面包屑裁剪**：在点列中找离玩家最近的点索引 `i`，渲染点列 = `[玩家位置] + world[i..]`。玩家走过的路段自动消失。
6. `queue_redraw()`。

## 渲染（`_draw`）

- 对裁剪后点列逐段画虚线；所有世界坐标用 `to_local()` 转本地后绘制，使节点不在原点时也正确。
- **流动**：维护 `_flow_phase`（`fmod(_flow_phase + flow_speed * delta, dash_length + gap_length)`），画虚线时把相位作为偏移，使虚线沿路径**从玩家向终点**流动（marching-ants）。

## 显示/切换

- 默认显示（`_enabled = true`）。
- 新增 input action `guide_toggle`（T 键）。`_unhandled_input` 监听，按下切换 `_enabled`。
- 到达 `arrive_distance` 内时即使 `_enabled` 为 true 也不画（到达即隐）。

## 文件改动

1. 新增 `src/systems/path_guide.gd`
2. 新增 `src/scenes/path_guide.tscn`（模板：`PathGuide` Node2D 根 + `Path` Path2D 子节点）
3. `project.godot` 的 `[input]` 段新增 `guide_toggle`（physical_keycode 84 = T）

## 边界与错误处理

- `destination` / `path` / 玩家任一处缺失 → 静默清空点列，不报错、不绘制。
- `path.curve` 为空或点数 < 2 → 退化为「玩家 → 终点」直线虚线。
- 玩家不在路径上（抄近路）→ 用最近投影点做连接段，不产生回钩。

## 测试

1. 在 `test_level.tscn` 拖入 `path_guide.tscn`，画一条绕过障碍的曲线，`destination` 指向 `ExitPortal`。
2. 运行：默认显示蓝色流动虚线；按 T 切换显隐。
3. 玩家沿路径前进，确认走过的线段消失、线头跟随玩家。
4. 玩家接近终点（< arrive_distance）确认自动隐藏。
5. 把 `destination` 换成任意 `Marker2D` 验证「终点直接导入节点」。

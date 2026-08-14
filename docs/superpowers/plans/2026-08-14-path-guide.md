# PathGuide 寻路指引系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用一条半透明、动态流动的蓝色虚线，沿设计师手画的 `Path2D` 曲线把玩家从当前位置引向可拖入节点的终点。

**Architecture:** 单个 `PathGuide`（Node2D）组件，复用现有 `dashed_line_2d.gd` 的手绘虚线思路（`_draw` 手绘 + 相位偏移做流动，无 shader / 粒子依赖）。每帧构建「玩家位置 → 最近路径点 → 剩余路径 → 终点」的面包屑点列并重绘。

**Tech Stack:** Godot 4.6, GDScript, `Path2D` / `Curve2D`, `Line2D`-less custom `_draw()`

---

## File Structure

```
src/
├── systems/
│   └── path_guide.gd          # PathGuide 组件脚本（核心）
└── scenes/
    └── path_guide.tscn        # 模板场景（Node2D + Path2D 子节点）
project.godot                  # [input] 段新增 guide_toggle（T 键）
```

- `src/systems/path_guide.gd`：寻路指引逻辑（导出属性、面包屑裁剪、流动虚线渲染、显隐切换）。
- `src/scenes/path_guide.tscn`：可复用模板，拖入关卡后画曲线 + 指终点即可。
- `project.godot`：新增 `guide_toggle` 输入动作。

---

### Task 1: 创建 PathGuide 脚本

**Files:**
- Create: `src/systems/path_guide.gd`

- [ ] **Step 1: 写入完整脚本**

`src/systems/path_guide.gd`：

```gdscript
# ============================================================
# PathGuide — 寻路指引线 (半透明流动蓝色虚线)
# 挂到 Node2D 上，配合一个 Path2D 子节点手画路径。
# 每帧从玩家当前位置沿路径画一条流动虚线指向终点。
#
# 编辑器用法：
#   1. 场景中新建 Node2D，挂载本脚本（或用 path_guide.tscn 模板）
#   2. 添加子节点 Path2D，在编辑器里手画路径曲线
#   3. 把终点节点（ExitPortal / Marker2D）拖到 Destination 插槽
#   4. 按 T 键切换显隐（默认显示）
# ============================================================
extends Node2D
class_name PathGuide

# ---------- 编辑器配置 ----------
# destination:      终点节点，取其 global_position 作为路径终点
# path:             手画路径曲线；留空自动取第一个 Path2D 子节点
# line_color:       虚线颜色（半透明蓝）
# line_width:       线宽 (px)
# dash_length:      虚线段长 (px)
# gap_length:       虚空间隙 (px)
# flow_speed:       虚线流动速度 (px/s，朝终点方向)
# arrive_distance:  玩家距终点小于该值时自动隐藏
@export var destination: Node2D = null
@export var path: Path2D = null
@export var line_color: Color = Color(0.4, 0.7, 1.0, 0.5)
@export var line_width: float = 3.0
@export var dash_length: float = 12.0
@export var gap_length: float = 8.0
@export var flow_speed: float = 30.0
@export var arrive_distance: float = 40.0

# ---------- 运行时状态 ----------
# _enabled:       T 键切换的显隐开关（默认显示）
# _flow_phase:    流动相位 (0 ~ dash+gap)，随帧累加
# _baked_world:   Path2D 曲线烘焙点（世界坐标，_ready 缓存）
# _render_points: 每帧待绘制的世界坐标点列（面包屑裁剪后）
var _enabled: bool = true
var _flow_phase: float = 0.0
var _baked_world: Array[Vector2] = []
var _render_points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	# path 未显式指定时，自动取第一个 Path2D 子节点
	if path == null:
		for child in get_children():
			if child is Path2D:
				path = child
				break
	_cache_path()

# 缓存 Path2D 曲线烘焙点（曲线是静态的，只在 _ready 烘焙一次）
func _cache_path() -> void:
	_baked_world.clear()
	if path != null and path.curve != null:
		for p in path.curve.get_baked_points():
			_baked_world.append(path.to_global(p))

# 输入：T 键切换显隐
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("guide_toggle"):
		_enabled = not _enabled
		queue_redraw()

func _process(delta: float) -> void:
	# 流动相位：随帧累加，模 dash+gap 周期
	var period := dash_length + gap_length
	_flow_phase = fmod(_flow_phase + flow_speed * delta, period)
	_rebuild_points()
	queue_redraw()

# 每帧重建渲染点列（面包屑：玩家走过的路段消失）
func _rebuild_points() -> void:
	_render_points.clear()
	if not _enabled:
		return
	if destination == null or not is_instance_valid(destination):
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	# 到达终点附近 → 隐藏
	if player.global_position.distance_to(destination.global_position) <= arrive_distance:
		return

	# 完整世界点列 = 路径烘焙点 + 终点（末点不重合才追加）
	var world: Array[Vector2] = _baked_world.duplicate()
	if world.is_empty() or world[world.size() - 1].distance_to(destination.global_position) > 1.0:
		world.append(destination.global_position)
	if world.is_empty():
		return

	# 面包屑裁剪：找离玩家最近的路径点，从该点起渲染
	var nearest := 0
	var best := INF
	for i in world.size():
		var d := player.global_position.distance_squared_to(world[i])
		if d < best:
			best = d
			nearest = i

	_render_points.append(player.global_position)
	for i in range(nearest, world.size()):
		_render_points.append(world[i])

func _draw() -> void:
	if _render_points.size() < 2:
		return
	for i in _render_points.size() - 1:
		_draw_dashed_segment(_render_points[i], _render_points[i + 1])

# 画一段流动虚线：相位偏移让虚线整体向 b（终点）移动，形成向终点流动
func _draw_dashed_segment(a: Vector2, b: Vector2) -> void:
	var la := to_local(a)
	var lb := to_local(b)
	var seg := lb - la
	var length := seg.length()
	if length <= 0.0:
		return
	var dir := seg / length
	var period := dash_length + gap_length
	var offset := fmod(_flow_phase, period)
	var cursor := offset - period
	while cursor < length:
		var start := maxf(cursor, 0.0)
		var end := minf(cursor + dash_length, length)
		if end > start:
			draw_line(la + dir * start, la + dir * end, line_color, line_width, true)
		cursor += period
```

- [ ] **Step 2: 在 Godot 中确认脚本无解析错误**

打开 Godot 编辑器，脚本应无红色报错（`class_name PathGuide` 会被注册）。

- [ ] **Step 3: Commit**

```bash
git add src/systems/path_guide.gd
git commit -m "feat: add PathGuide flowing dashed-line path indicator"
```

---

### Task 2: 新增 guide_toggle 输入动作（T 键）

**Files:**
- Modify: `project.godot`（`[input]` 段）

- [ ] **Step 1: 在 `[input]` 段末尾（`map={...}` 之后、`[layer_names]` 之前）插入**

`project.godot`，在 `map` 块结束后追加：

```
guide_toggle={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":84,"key_label":0,"unicode":116,"location":0,"echo":false,"script":null)
]
}
```

> `physical_keycode 84` = T 键，`unicode 116` = 't'。

- [ ] **Step 2: Commit**

```bash
git add project.godot
git commit -m "feat: add guide_toggle input action (T key)"
```

---

### Task 3: 创建模板场景 path_guide.tscn

**Files:**
- Create: `src/scenes/path_guide.tscn`

- [ ] **Step 1: 写入模板场景**

`src/scenes/path_guide.tscn`：

```
[gd_scene format=3]

[ext_resource type="Script" path="res://src/systems/path_guide.gd" id="1_pg"]

[node name="PathGuide" type="Node2D"]
script = ExtResource("1_pg")

[node name="Path" type="Path2D" parent="."]
```

> 说明：场景 uid 与脚本 uid 留空，Godot 首次打开会按 path 解析脚本并自动补全 uid。
> 若编辑器提示 uid 相关警告，在编辑器里打开本场景并 Ctrl+S 保存一次即可自动补全。

- [ ] **Step 2: Commit**

```bash
git add src/scenes/path_guide.tscn
git commit -m "feat: add PathGuide template scene"
```

---

### Task 4: 集成验证

**Files:**
- Modify: `src/scenes/test_level.tscn`（临时，仅用于验证，验证后可回退）

- [ ] **Step 1: 在 test_level 里实例化 path_guide**

在 Godot 编辑器打开 `src/scenes/test_level.tscn`：

1. 实例化 `res://src/scenes/path_guide.tscn` 为场景子节点（或新建 `Node2D` 挂 `path_guide.gd`）。
2. 选中 `Path` 子节点，在编辑器里画一条绕过障碍的曲线（至少 3 个控制点）。
3. 在 `PathGuide` 属性面板把 `Destination` 拖入场景中的某个终点节点（若无 `ExitPortal`，新建一个 `Marker2D` 放任意位置）。

- [ ] **Step 2: 运行并验证 5 项行为**

运行 `test_level.tscn`，逐项确认：

1. **显示**：进入关卡即可见一条蓝色、半透明的虚线（默认显示）。
2. **流动**：虚线沿路径从玩家向终点方向流动（marching-ants）。若方向反了，把 `_draw_dashed_segment` 里的 `offset` 取负即可（`var offset := -fmod(_flow_phase, period)`）。
3. **切换**：按 `T` 键隐藏，再按 `T` 显示。
4. **面包屑**：控制玩家沿路径移动，已走过的路段消失、线头跟随玩家。
5. **到达隐藏**：玩家靠近终点（< 40px）时虚线自动隐藏。

- [ ] **Step 3: 验证「终点直接导入节点」**

把 `Destination` 改拖成场景里任意其他 `Marker2D`，虚线应指向新节点位置，无需改代码。

- [ ] **Step 4: 回退 test_level 的临时改动（保留 path_guide 组件本身）**

确认无误后，从 `test_level.tscn` 移除临时实例化的 `PathGuide`（正式接入由关卡设计师在 stage 场景里进行），避免把测试占位提交进主关卡。

```bash
git status
# 若 test_level.tscn 有改动，回退：
git restore src/scenes/test_level.tscn
```

---

## Self-Review 记录

- **Spec 覆盖**：`destination`/`path` 导出（Task 1）、手画 Path2D（Task 1/3）、面包屑裁剪（Task 1 `_rebuild_points`）、流动虚线（Task 1 `_draw_dashed_segment`）、T 键切换（Task 2）、到达隐藏（Task 1 `arrive_distance`）、模板场景（Task 3）——均覆盖。
- **占位符扫描**：无 TBD/TODO；所有步骤含完整代码。
- **类型一致性**：`_baked_world: Array[Vector2]`、`_render_points: PackedVector2Array`、`destination: Node2D`、`path: Path2D` 在全文一致。

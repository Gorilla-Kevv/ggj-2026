# 可交互物体风迹粒子跟踪系统（系统 2）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 自动扫描 `interactable` 组的 `RigidBody2D` 物体，为每个挂载一个速度驱动、体积自适应的风迹拖尾粒子。

**Architecture:** 一个 Autoload `WindTrailSystem` 管理器 + 一个可复用拖尾粒子模板场景。管理器自动扫描/挂载，每帧按物体 `linear_velocity` 驱动拖尾，按碰撞形状面积等比缩放拖尾大小。背景风场（系统 1）暂缓实现。

**Tech Stack:** Godot 4.6, GDScript, `GPUParticles2D` + `ParticleProcessMaterial`（`trail_enabled`）

---

## File Structure

```
src/
├── autoload/
│   └── wind_trail_system.gd    # 管理器 Autoload（系统 2：扫描/挂载/驱动/体积）
└── scenes/
    └── wind_trail_object.tscn  # 物体拖尾粒子模板（resource_local_to_scene）
project.godot                   # [autoload] 注册 WindTrailSystem
```

---

### Task 1: 创建物体拖尾粒子模板场景

**Files:**
- Create: `src/scenes/wind_trail_object.tscn`

- [ ] **Step 1: 写入模板场景**

`src/scenes/wind_trail_object.tscn`（基于 `windline_particles_player.tscn` 的形态，蓝色风迹，`ParticleProcessMaterial` 标记 `resource_local_to_scene` 使每个实例独立）：

```
[gd_scene format=3]

[sub_resource type="Gradient" id="Gradient_trail"]
offsets = PackedFloat32Array(0, 0.5353805, 1)
colors = PackedColorArray(1, 1, 1, 0, 0.4, 0.7, 1, 1, 1, 1, 1, 0)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_trail"]
gradient = SubResource("Gradient_trail")
width = 4
height = 32
fill_to = Vector2(0, 1)

[sub_resource type="Gradient" id="Gradient_init"]
colors = PackedColorArray(1, 1, 1, 0, 1, 1, 1, 1)

[sub_resource type="GradientTexture1D" id="GradientTexture1D_init"]
gradient = SubResource("Gradient_init")

[sub_resource type="Gradient" id="Gradient_ramp"]
offsets = PackedFloat32Array(0, 0.53001463, 1)
colors = PackedColorArray(0.2, 0.6, 1, 1, 1, 1, 1, 1, 0.2, 0.6, 1, 0.22745098)

[sub_resource type="GradientTexture1D" id="GradientTexture1D_ramp"]
gradient = SubResource("Gradient_ramp")

[sub_resource type="ParticleProcessMaterial" id="ParticleProcessMaterial_trail" resource_local_to_scene=true]
particle_flag_disable_z = true
emission_shape = 3
emission_box_extents = Vector3(70, 70, 1)
gravity = Vector3(0, 98, 0)
scale_min = 0.5
scale_max = 1.0
color_ramp = SubResource("GradientTexture1D_ramp")
color_initial_ramp = SubResource("GradientTexture1D_init")

[node name="WindTrailObject" type="GPUParticles2D"]
amount = 18
texture = SubResource("GradientTexture2D_trail")
lifetime = 1.2
preprocess = 1.0
randomness = 0.44
trail_enabled = true
trail_lifetime = 0.62
process_material = SubResource("ParticleProcessMaterial_trail")
```

> `resource_local_to_scene=true` 保证每次 `instantiate()` 得到独立的 `ParticleProcessMaterial`，可分别调体积参数。若编辑器提示 uid 警告，打开场景 Ctrl+S 保存一次即可补全。

- [ ] **Step 2: Commit**

```bash
git add src/scenes/wind_trail_object.tscn
git commit -m "feat: add wind trail object particle template"
```

---

### Task 2: 创建 WindTrailSystem 管理器（系统 2）

**Files:**
- Create: `src/autoload/wind_trail_system.gd`

- [ ] **Step 1: 写入完整脚本**

`src/autoload/wind_trail_system.gd`：

```gdscript
# ============================================================
# WindTrailSystem — 可交互物体风迹粒子跟踪系统 (系统 2)
# Autoload 单例：自动扫描 "interactable" 组里的 RigidBody2D，
# 为每个挂载一个速度驱动、体积自适应的风迹拖尾粒子。
# 背景风场 (系统 1) 暂缓，后续在此文件内扩展。
# ============================================================
extends Node
class_name WindTrailSystem

const TRAIL_SCENE: PackedScene = preload("res://src/scenes/wind_trail_object.tscn")

# ---------- 可调参数 ----------
# trail_speed_threshold:   物体速度高于该值才发射拖尾 (px/s)
# reference_volume:        体积归一化基准 (px²)，等于基准物体的碰撞面积
# base_amount:             基准物体 (体积=reference_volume) 的粒子数量
# base_box_extents:        基准发射盒尺寸
# base_scale:              基准粒子缩放
# base_trail_lifetime:     基准拖尾时长
# scan_interval:           动态物体重扫间隔 (秒)，捕获运行中新增的可交互物体
@export var trail_speed_threshold: float = 30.0
@export var reference_volume: float = 10000.0
@export var base_amount: int = 18
@export var base_box_extents: Vector3 = Vector3(70, 70, 1)
@export var base_scale: float = 0.5
@export var base_trail_lifetime: float = 0.62
@export var scan_interval: float = 0.5

# ---------- 运行时状态 ----------
# _trails:     body -> 拖尾 GPUParticles2D
# _materials:  body -> 拖尾 ParticleProcessMaterial (独立实例)
var _trails: Dictionary = {}
var _materials: Dictionary = {}
var _scan_timer: float = 0.0
var _last_scene: Node = null

func _ready() -> void:
	_scan_and_mount()

func _process(delta: float) -> void:
	# 场景切换 → 清理重建
	var scene := get_tree().current_scene
	if scene != _last_scene:
		_last_scene = scene
		_clear_all()
		_scan_and_mount()

	# 周期性重扫，捕获运行中动态生成的可交互物体 (如 boss 战的投掷巨石)
	_scan_timer += delta
	if _scan_timer >= scan_interval:
		_scan_timer = 0.0
		_scan_and_mount()

	_update_trails()

# 扫描 interactable 组，为每个 RigidBody2D 挂载拖尾 (幂等)
func _scan_and_mount() -> void:
	for body in get_tree().get_nodes_in_group("interactable"):
		if body is RigidBody2D and not _trails.has(body):
			_mount_trail(body as RigidBody2D)

# 为单个物体挂载拖尾，并按体积等比缩放
func _mount_trail(body: RigidBody2D) -> void:
	var emitter: GPUParticles2D = TRAIL_SCENE.instantiate()
	body.add_child(emitter)
	emitter.position = Vector2.ZERO
	emitter.emitting = false

	var mat := emitter.process_material as ParticleProcessMaterial
	var k := _linear_scale(body)

	# 体积自适应：发射盒、粒子缩放、数量、拖尾长度等比缩放
	mat.emission_box_extents = base_box_extents * k
	mat.scale_min = base_scale * k
	mat.scale_max = base_scale * 1.5 * k
	emitter.amount = clampi(int(base_amount * k * k), 4, 64)
	emitter.trail_lifetime = clampf(base_trail_lifetime * k, 0.3, 1.5)

	_trails[body] = emitter
	_materials[body] = mat

# 线性尺寸缩放因子 = sqrt(面积 / 基准体积)
func _linear_scale(body: RigidBody2D) -> float:
	return sqrt(_compute_area(body) / reference_volume)

# 估算物体体积 (碰撞形状面积，含形状节点自身 scale)
func _compute_area(body: RigidBody2D) -> float:
	for child in body.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.shape == null:
				continue
			var s := cs.scale.abs()
			if cs.shape is CircleShape2D:
				var r: float = (cs.shape as CircleShape2D).radius * maxf(s.x, s.y)
				return PI * r * r
			elif cs.shape is RectangleShape2D:
				var sz: Vector2 = (cs.shape as RectangleShape2D).size
				return abs(sz.x * sz.y * s.x * s.y)
			elif cs.shape is CapsuleShape2D:
				var cap := cs.shape as CapsuleShape2D
				var r: float = cap.radius * maxf(s.x, s.y)
				return PI * r * r + 2.0 * r * cap.height * s.y
	return reference_volume

# 每帧按速度驱动拖尾；同时清理已释放的物体
func _update_trails() -> void:
	for body in _trails.keys():
		if not is_instance_valid(body):
			_trails.erase(body)
			_materials.erase(body)
			continue
		var emitter: GPUParticles2D = _trails[body]
		var mat: ParticleProcessMaterial = _materials[body]
		var speed: float = (body as RigidBody2D).linear_velocity.length()
		if speed < trail_speed_threshold:
			emitter.emitting = false
			continue
		emitter.emitting = true
		var dir: Vector2 = -(body as RigidBody2D).linear_velocity.normalized()
		mat.direction = Vector3(dir.x, dir.y, 0.0)
		mat.initial_velocity_min = speed * 0.35
		mat.initial_velocity_max = speed * 0.7

# 释放全部拖尾 (场景切换用)
func _clear_all() -> void:
	for emitter in _trails.values():
		if is_instance_valid(emitter):
			(emitter as GPUParticles2D).queue_free()
	_trails.clear()
	_materials.clear()
```

- [ ] **Step 2: 在 Godot 中确认脚本无解析错误**

打开 Godot 编辑器，脚本无红色报错（`class_name WindTrailSystem` 注册成功）。

- [ ] **Step 3: Commit**

```bash
git add src/autoload/wind_trail_system.gd
git commit -m "feat: add WindTrailSystem interactable trail tracking (system 2)"
```

---

### Task 3: 注册 Autoload

**Files:**
- Modify: `project.godot`（`[autoload]` 段）

- [ ] **Step 1: 在 `[autoload]` 段末尾追加**

在 `Settings="*res://src/autoload/settings.gd"` 之后加一行：

```
WindTrailSystem="*res://src/autoload/wind_trail_system.gd"
```

- [ ] **Step 2: Commit**

```bash
git add project.godot
git commit -m "feat: register WindTrailSystem autoload"
```

---

### Task 4: 集成验证

**Files:**
- Modify: `src/scenes/stage_1/stage_1.tscn`（临时，仅验证；验证后回退）

- [ ] **Step 1: 运行 stage_1 并验证**

在 Godot 中运行 `stage_1.tscn`（该关已有 `水箱`/`钢管`/`培养皿` 三个可交互 RigidBody2D）：

1. **自动挂载**：进入关卡后，选中物体（R 键切换），观察其下是否已自动出现 `WindTrailObject` 子节点（编辑器远程树或运行时可见）。
2. **速度驱动**：按住左键吹动选中的物体，物体移动时出现蓝色拖尾，方向与速度相反；物体停下（速度 < 30）拖尾停止。
3. **体积自适应**：分别吹动大水箱（`interact_mass=7`、矩形碰撞体较大）和小钢管（`interact_mass=3`），对比两者拖尾的粒子数量/大小明显不同。
4. **无残留报错**：切换关卡到 `stage_2`，确认旧物体拖尾被清理、新关物体自动挂载，Output 面板无 `is_instance_valid` 相关报错。

- [ ] **Step 2: 验证动态物体**

进入 boss 战（`stage_3`），投掷巨石（`ThrowableRock`，运行时动态生成并加入 `interactable` 组）出现后，应在 `scan_interval`（0.5s）内被自动挂上拖尾。

- [ ] **Step 3: 回退临时改动**

确认无误后，若 `stage_1.tscn` 有临时改动则回退：

```bash
git status
git restore src/scenes/stage_1/stage_1.tscn
```

> 正式接入由关卡设计师决定；本系统为 Autoload 自动生效，无需在关卡里手摆节点。

---

## Self-Review 记录

- **Spec 覆盖**（仅系统 2）：自动扫描 + 自动挂载（Task 2 `_scan_and_mount`/`_mount_trail`）、速度驱动拖尾（`_update_trails`）、体积自适应等比缩放（`_compute_area`/`_linear_scale`/`_mount_trail`）、复用现有粒子形态（Task 1 模板）——均覆盖。系统 1（背景风场）暂缓，不在本计划范围。
- **占位符扫描**：无 TBD/TODO；所有步骤含完整代码。
- **类型一致性**：`_trails: Dictionary`（body→GPUParticles2D）、`_materials: Dictionary`（body→ParticleProcessMaterial）、`_linear_scale`/`_compute_area`/`_mount_trail`/`_update_trails` 签名全文一致。

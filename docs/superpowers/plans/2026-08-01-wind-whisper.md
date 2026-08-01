# 风语者 (Wind Whisper) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 2D wind-control puzzle-platformer where a tumbleweed escapes a lab using mouse-driven wind mechanics across 5 levels.

**Architecture:** Godot 4.6 2D project. An autoload singleton `Global` holds game state (energy, selected target, checkpoint). Core loop: mouse position determines wind source, R key cycles targets, hold LMB to blow. Player is a CharacterBody2D with low gravity and constant float. Interactables are RigidBody2D or Area2D. Enemies are character bodies with AI states. Levels are `.tscn` files with TileMap terrain.

**Tech Stack:** Godot 4.6, GDScript, Godot built-in 2D physics

---

## File Structure

```
src/
├── autoload/
│   └── global.gd                 # Singleton: energy, target, checkpoint state
├── actors/
│   ├── player.gd                 # Player physics, input handling, death
│   └── enemies/
│       ├── base_enemy.gd         # Enemy base class (patrol/chase states)
│       ├── researcher.gd         # Patrol researcher with flashlight
│       ├── drone.gd              # Pursuit drone
│       ├── scorpion.gd           # Wall-ambush scorpion
│       ├── eagle.gd              # Dive-bomb eagle
│       ├── mothership.gd         # Heavy drone with spawner
│       └── boss_windcatcher.gd   # Final boss (3 wind phases)
├── interactables/
│   ├── base_interactable.gd     # Base: selectable + wind-receiving interface
│   ├── pushable_box.gd          # Box pushed by wind
│   ├── fan_switch.gd            # Fan that opens doors when blown
│   ├── wind_tunnel.gd           # Pipe that refracts wind direction
│   ├── rock_pillar.gd           # Collapsible rock pillar
│   ├── windmill_chain.gd        # Windmill chain-puzzle mechanism
│   └── dandelion.gd             # Dandelion that releases updraft
├── environment/
│   ├── updraft.gd               # Thermal updraft zone
│   ├── sandfall.gd              # Intermittent sandfall hazard
│   ├── wind_zone.gd             # Constant directional wind zone
│   ├── spike.gd                 # Instant-kill spike area
│   └── kill_floor.gd            # Ground/floor death trigger
├── level/
│   ├── level_manager.gd         # Scene management, checkpoint respawn
│   └── checkpoint.gd            # Checkpoint activation + save
├── ui/
│   ├── hud.gd                   # Energy bar, target name
│   ├── wind_line.gd             # Mouse-to-target direction line + particles
│   └── boss_health.gd           # Boss HP bar
├── scenes/
│   ├── main_menu.tscn
│   ├── level_01_lab.tscn
│   ├── level_02_vents.tscn
│   ├── level_03_canyon.tscn
│   ├── level_04_grassland.tscn
│   ├── level_05_stormeye.tscn
│   └── ui/
│       ├── hud.tscn
│       └── boss_health.tscn
└── player.tscn
```

---

### Task 1: Project scaffold and global singleton

**Files:**
- Create: `src/autoload/global.gd`
- Modify: `project.godot` (add autoload entry)

- [ ] **Step 1: Create global singleton script**

`src/autoload/global.gd`:
```gdscript
extends Node

var energy: float = 100.0
var energy_max: float = 100.0
var energy_drain: float = 20.0
var energy_regen: float = 15.0

var selected_target: Node2D = null

var current_checkpoint: Vector2 = Vector2.ZERO
var last_checkpoint_level: String = ""
```

- [ ] **Step 2: Register as autoload in project.godot**

Add to `[autoload]` section in `project.godot`:
```
Global="*res://src/autoload/global.gd"
```

Open `project.godot` and add after existing `MCPRuntimeProbe` line.

- [ ] **Step 3: Create project subdirectories**

Run:
```powershell
New-Item -ItemType Directory -Force -Path "src\autoload", "src\actors\enemies", "src\interactables", "src\environment", "src\level", "src\ui", "src\scenes\ui"
```

- [ ] **Step 4: Commit**

```bash
git add src/autoload/global.gd project.godot
git commit -m "feat: add global singleton and project scaffold"
```

---

### Task 2: Energy system

**Files:**
- Modify: `src/autoload/global.gd`

- [ ] **Step 1: Add energy management methods to Global**

Replace `src/autoload/global.gd` content:
```gdscript
extends Node

var energy: float = 100.0
const ENERGY_MAX: float = 100.0
const ENERGY_DRAIN: float = 20.0
const ENERGY_REGEN: float = 15.0

var selected_target: Node2D = null

var current_checkpoint: Vector2 = Vector2.ZERO
var last_checkpoint_level: String = ""

signal energy_changed(new_energy: float)
signal energy_depleted()
signal energy_full()

func _process(delta: float) -> void:
	regen_energy(delta)

func drain_energy(delta: float) -> void:
	energy = maxf(0.0, energy - ENERGY_DRAIN * delta)
	energy_changed.emit(energy)
	if energy <= 0.0:
		energy_depleted.emit()

func regen_energy(delta: float) -> void:
	if energy >= ENERGY_MAX:
		return
	energy = minf(ENERGY_MAX, energy + ENERGY_REGEN * delta)
	energy_changed.emit(energy)
	if energy >= ENERGY_MAX:
		energy_full.emit()

func refill_energy() -> void:
	energy = ENERGY_MAX
	energy_changed.emit(energy)
	energy_full.emit()

func has_energy() -> bool:
	return energy > 0.0
```

- [ ] **Step 2: Commit**

```bash
git add src/autoload/global.gd
git commit -m "feat: implement energy system with drain/regen"
```

---

### Task 3: Player scene and physics

**Files:**
- Create: `src/actors/player.gd`
- Create: `src/player.tscn`

- [ ] **Step 1: Create player script**

`src/actors/player.gd`:
```gdscript
extends CharacterBody2D

const GRAVITY_SCALE: float = 0.3
const MAX_SPEED: float = 600.0
const FRICTION: float = 0.95
const COLLISION_RADIUS: float = 20.0

signal player_died()

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	$CollisionShape2D.shape = shape

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * GRAVITY_SCALE * delta
	velocity *= FRICTION
	velocity = velocity.limit_length(MAX_SPEED)
	move_and_slide()

func apply_wind_force(force: Vector2) -> void:
	velocity += force
	velocity = velocity.limit_length(MAX_SPEED)

func die() -> void:
	player_died.emit()
```

- [ ] **Step 2: Create player.tscn in Godot editor**

Create a new scene with root `CharacterBody2D` named "Player":
1. Open Godot, create new scene
2. Root node: `CharacterBody2D`, rename to "Player"
3. Add child `CollisionShape2D`
4. Add child `Sprite2D` (placeholder: a circle for now)
5. Attach `src/actors/player.gd` to root
6. Save as `src/player.tscn`

- [ ] **Step 3: Commit**

```bash
git add src/actors/player.gd src/player.tscn
git commit -m "feat: create player with low-gravity float physics"
```

---

### Task 4: Wind system (core mechanic)

**Files:**
- Create: `src/systems/wind_system.gd`
- Modify: `src/autoload/global.gd`

- [ ] **Step 1: Create wind system script**

`src/systems/wind_system.gd`:
```gdscript
extends Node

const MAX_WIND_FORCE: float = 800.0
const RAMP_TIME: float = 3.0
const MICRO_WIND_FORCE: float = 200.0

var is_blowing: bool = false
var blow_hold_time: float = 0.0

signal wind_started(target: Node2D, direction: Vector2)
signal wind_updated(target: Node2D, direction: Vector2, strength: float)
signal wind_stopped()

func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_blowing:
			if not Global.has_energy():
				return
			is_blowing = true
			blow_hold_time = 0.0
			_start_wind()
		else:
			blow_hold_time += delta
			_update_wind(delta)
	else:
		if is_blowing:
			is_blowing = false
			blow_hold_time = 0.0
			wind_stopped.emit()

func _just_pressed() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not is_blowing

func _start_wind() -> void:
	if Global.selected_target == null:
		return
	wind_started.emit(Global.selected_target, _get_wind_direction())

func _update_wind(delta: float) -> void:
	if Global.selected_target == null:
		return
	Global.drain_energy(delta)
	if not Global.has_energy():
		wind_stopped.emit()
		is_blowing = false
		return
	var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
	wind_updated.emit(Global.selected_target, _get_wind_direction(), strength)

func _get_wind_direction() -> Vector2:
	var mouse_pos := get_viewport().get_mouse_position()
	if Global.selected_target == null:
		return Vector2.ZERO
	var target_pos := Global.selected_target.global_position
	return (target_pos - mouse_pos).normalized()

func get_wind_force() -> Vector2:
	var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
	return _get_wind_direction() * MAX_WIND_FORCE * strength

func get_micro_wind_force() -> Vector2:
	return _get_wind_direction() * MICRO_WIND_FORCE
```

- [ ] **Step 2: Wire wind system to player**

Modify `src/actors/player.gd` — add wind system reference:
```gdscript
var wind_system: Node

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	$CollisionShape2D.shape = shape
	wind_system = get_node("/root/Game/WindSystem")

func _on_wind_updated(_target: Node2D, _direction: Vector2, _strength: float) -> void:
	if _target == self:
		apply_wind_force(_direction * 800.0 * _strength * 0.02)
```

Actually, let me rethink — the wind system should be scene-local (part of each level), not a global autoload. Let me restructure. The `wind_system.gd` will be attached to a node in each level scene. The Global autoload just holds state.

Let me fix Task 4.

- [ ] **Step 1: Create wind system script (as a node, not autoload)**

`src/systems/wind_system.gd`:
```gdscript
extends Node2D

const MAX_WIND_FORCE: float = 800.0
const RAMP_TIME: float = 3.0

var is_blowing: bool = false
var blow_hold_time: float = 0.0

signal wind_updated(target: Node2D, direction: Vector2, strength: float)

func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if Global.selected_target == null:
			return
		if not Global.has_energy() and not is_blowing:
			return
		if not is_blowing:
			is_blowing = true
			blow_hold_time = 0.0
		blow_hold_time += delta
		Global.drain_energy(delta)
		var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
		wind_updated.emit(Global.selected_target, _get_wind_direction(), strength)
		if not Global.has_energy():
			is_blowing = false
	else:
		if is_blowing:
			is_blowing = false

func get_wind_force() -> Vector2:
	var strength := clampf(blow_hold_time / RAMP_TIME, 0.0, 1.0)
	return _get_wind_direction() * MAX_WIND_FORCE * strength

func _get_wind_direction() -> Vector2:
	var mouse_pos := get_viewport().get_mouse_position()
	if Global.selected_target == null:
		return Vector2.ZERO
	return (Global.selected_target.global_position - mouse_pos).normalized()
```

- [ ] **Step 2: Commit**

```bash
git add src/systems/wind_system.gd
git commit -m "feat: implement wind system with mouse-driven direction and strength"
```

---

### Task 5: Target selector (R key)

**Files:**
- Create: `src/systems/target_selector.gd`

- [ ] **Step 1: Create target selector**

`src/systems/target_selector.gd`:
```gdscript
extends Node2D

var targets: Array[Node2D] = []
var current_index: int = 0

signal target_changed(new_target: Node2D)

func _ready() -> void:
	_find_targets()
	if targets.size() > 0:
		select_target(current_index)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_target"):
		_cycle_target()

func _find_targets() -> void:
	targets.clear()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		targets.append(player)
	for node in get_tree().get_nodes_in_group("interactable"):
		targets.append(node)

func _cycle_target() -> void:
	if targets.size() == 0:
		return
	current_index = (current_index + 1) % targets.size()
	select_target(current_index)

func select_target(index: int) -> void:
	current_index = clampi(index, 0, targets.size() - 1)
	Global.selected_target = targets[current_index]
	target_changed.emit(Global.selected_target)

func get_current_target() -> Node2D:
	if targets.size() == 0:
		return null
	return targets[current_index]

func register_target(node: Node2D) -> void:
	if node not in targets:
		targets.append(node)
```

- [ ] **Step 2: Add input map action**

Open Godot Project Settings > Input Map, add action `switch_target` bound to key `R`.

- [ ] **Step 3: Commit**

```bash
git add src/systems/target_selector.gd project.godot
git commit -m "feat: implement R-key target selector with cycling"
```

---

### Task 6: Wind line visual (mouse-to-target direction indicator)

**Files:**
- Create: `src/ui/wind_line.gd`

- [ ] **Step 1: Create wind line renderer**

`src/ui/wind_line.gd`:
```gdscript
extends Node2D

@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var line_width: float = 2.0
@export var particle_count: int = 8

var particles: Array[Sprite2D] = []

func _ready() -> void:
	for i in range(particle_count):
		var p := Sprite2D.new()
		p.scale = Vector2(0.5, 0.5)
		p.modulate = Color(0.6, 0.8, 1.0, 0.6)
		add_child(p)
		particles.append(p)

func _process(_delta: float) -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var target := Global.selected_target
	if target == null:
		hide()
		return
	show()
	_update_particles(mouse_pos, target.global_position)
	queue_redraw()

func _update_particles(mouse_pos: Vector2, target_pos: Vector2) -> void:
	var dir := (target_pos - mouse_pos)
	var dist := dir.length()
	var norm := dir.normalized()
	for i in range(particle_count):
		var t := float(i) / float(particle_count - 1)
		var pos := mouse_pos + norm * dist * t
		particles[i].position = pos
		particles[i].visible = true

func _draw() -> void:
	var mouse_pos := get_viewport().get_mouse_position()
	var target := Global.selected_target
	if target == null:
		return
	draw_dashed_line(mouse_pos, target.global_position, line_color, line_width, 8.0)
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/wind_line.gd
git commit -m "feat: add wind direction line and particle indicator"
```

---

### Task 7: HUD (energy bar + target display)

**Files:**
- Create: `src/ui/hud.gd`
- Create: `src/scenes/ui/hud.tscn`

- [ ] **Step 1: Create HUD script**

`src/ui/hud.gd`:
```gdscript
extends CanvasLayer

@onready var energy_bar: ProgressBar = $EnergyBar
@onready var target_label: Label = $TargetLabel

func _ready() -> void:
	Global.energy_changed.connect(_on_energy_changed)
	energy_bar.max_value = Global.ENERGY_MAX
	energy_bar.value = Global.energy

func _on_energy_changed(new_energy: float) -> void:
	energy_bar.value = new_energy
	if new_energy <= 0.0:
		energy_bar.modulate = Color.RED
	else:
		energy_bar.modulate = Color.WHITE

func _process(_delta: float) -> void:
	var target := Global.selected_target
	if target:
		target_label.text = target.get_meta("display_name", target.name)
	else:
		target_label.text = "无目标"
```

- [ ] **Step 2: Create HUD scene**

In Godot editor, create `src/scenes/ui/hud.tscn`:
1. Root: `CanvasLayer`
2. Child `ProgressBar` named "EnergyBar" — positioned top-left, arc-style, min=0 max=100
3. Child `Label` named "TargetLabel" — below energy bar
4. Attach `src/ui/hud.gd` to root

- [ ] **Step 3: Commit**

```bash
git add src/ui/hud.gd src/scenes/ui/hud.tscn
git commit -m "feat: add HUD with energy bar and target display"
```

---

### Task 8: Death zone and respawn system

**Files:**
- Create: `src/environment/kill_floor.gd`
- Create: `src/environment/spike.gd`
- Create: `src/level/checkpoint.gd`
- Modify: `src/autoload/global.gd`

- [ ] **Step 1: Kill floor script**

`src/environment/kill_floor.gd`:
```gdscript
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.die()
```

- [ ] **Step 2: Spike hazard script**

`src/environment/spike.gd`:
```gdscript
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.die()
```

- [ ] **Step 3: Checkpoint script**

`src/level/checkpoint.gd`:
```gdscript
extends Area2D

@export var is_active: bool = false

signal checkpoint_activated(checkpoint: Node2D)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not is_active:
		modulate = Color(0.3, 0.3, 0.3, 0.5)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_active:
		activate()

func activate() -> void:
	is_active = true
	modulate = Color(0.2, 1.0, 0.4, 0.8)
	Global.current_checkpoint = global_position
	Global.last_checkpoint_level = get_tree().current_scene.scene_file_path
	checkpoint_activated.emit(self)
```

- [ ] **Step 4: Add respawn logic to player**

Add to `src/actors/player.gd`:
```gdscript
func _ready() -> void:
	add_to_group("player")
	# ... existing setup

func die() -> void:
	player_died.emit()
	call_deferred("_respawn")

func _respawn() -> void:
	if Global.last_checkpoint_level != "":
		get_tree().change_scene_to_file(Global.last_checkpoint_level)
	else:
		get_tree().reload_current_scene()
	await get_tree().process_frame
	global_position = Global.current_checkpoint
	Global.refill_energy()
```

- [ ] **Step 5: Commit**

```bash
git add src/environment/kill_floor.gd src/environment/spike.gd src/level/checkpoint.gd src/actors/player.gd
git commit -m "feat: add death zones, spike hazards, checkpoints, and respawn"
```

---

### Task 9: Base interactable and pushable box

**Files:**
- Create: `src/interactables/base_interactable.gd`
- Create: `src/interactables/pushable_box.gd`

- [ ] **Step 1: Base interactable**

`src/interactables/base_interactable.gd`:
```gdscript
extends RigidBody2D
class_name BaseInteractable

func _ready() -> void:
	add_to_group("interactable")
	set_meta("display_name", "物体")

func apply_wind_force(force: Vector2) -> void:
	apply_central_force(force)

func on_selected() -> void:
	modulate = Color.GOLD

func on_deselected() -> void:
	modulate = Color.WHITE
```

- [ ] **Step 2: Pushable box**

`src/interactables/pushable_box.gd`:
```gdscript
extends BaseInteractable

func _ready() -> void:
	super._ready()
	set_meta("display_name", "箱子")
	mass = 5.0
```

- [ ] **Step 3: Wire wind system to interactables**

Modify `src/actors/player.gd` — add wind handler that dispatches to selected:
```gdscript
func _on_wind_updated(target: Node2D, direction: Vector2, strength: float) -> void:
	var force := direction * 800.0 * strength * 0.02
	if target == self:
		apply_wind_force(force)
	elif target is BaseInteractable:
		target.apply_wind_force(direction * 800.0 * strength * 0.05)
```

- [ ] **Step 4: Commit**

```bash
git add src/interactables/base_interactable.gd src/interactables/pushable_box.gd src/actors/player.gd
git commit -m "feat: add base interactable class and pushable box"
```

---

### Task 10: Level manager

**Files:**
- Create: `src/level/level_manager.gd`

- [ ] **Step 1: Create level manager**

`src/level/level_manager.gd`:
```gdscript
extends Node2D

@export var level_name: String = "未命名"
@export var next_level_path: String = ""

func _ready() -> void:
	Global.current_checkpoint = Vector2.ZERO
	Global.last_checkpoint_level = get_tree().current_scene.scene_file_path
	_spawn_player()

func _spawn_player() -> void:
	var spawn := get_node_or_null("SpawnPoint")
	var player_scene := load("res://src/player.tscn")
	var player := player_scene.instantiate()
	if spawn:
		player.global_position = spawn.global_position
	else:
		player.global_position = Vector2(200, 400)
	add_child(player)

func load_next_level() -> void:
	if next_level_path != "":
		get_tree().change_scene_to_file(next_level_path)
```

- [ ] **Step 2: Commit**

```bash
git add src/level/level_manager.gd
git commit -m "feat: add level manager with player spawn and level transitions"
```

---

### Task 11: Level 1 — Tutorial (Lab)

**Files:**
- Create: `src/scenes/level_01_lab.tscn`

- [ ] **Step 1: Build Level 1 scene in Godot editor**

Create `src/scenes/level_01_lab.tscn`:
1. Root: `Node2D`, attach `src/level/level_manager.gd`
   - Set `level_name = "觉醒·玻璃罩"`
   - Set `next_level_path = "res://src/scenes/level_02_vents.tscn"`
2. Add child `Node2D` named "WindSystem", attach `src/systems/wind_system.gd`
3. Add child `Node2D` named "TargetSelector", attach `src/systems/target_selector.gd`
4. Add child `Node2D` named "WindLine", attach `src/ui/wind_line.gd`
5. Add child `Marker2D` named "SpawnPoint" at position (200, 400)
6. Instance `src/scenes/ui/hud.tscn` as child

**Terrain (TileMap):**
- Floor tiles at y=600 across the width
- A glass enclosure around spawn (tiles forming walls + ceiling)
- Narrow gaps to practice micro-blowing through
- A small box (pushable_box instance) blocking a passageway

**Level design details:**
- Room 1: Spawn inside glass box (4 walls of tiles). Player must blow self upward through gap in ceiling.
- Passage: Narrow corridor, teach micro-adjustment blowing.
- Room 2: Pushable box blocks path. Player must press R to target box, blow it aside.
- Room 3: A gap with no floor — player must use inertia (drift after stopping blow) to cross.
- End: Vent entrance sprite/area → triggers `load_next_level()` on overlap.

- [ ] **Step 2: Add level completion trigger**

Add an Area2D named "ExitPortal" at the vent entrance that calls `level_manager.load_next_level()` on `body_entered` if body is player.

- [ ] **Step 3: Set as main scene**

In `project.godot`, add:
```
[application]
run/main_scene="res://src/scenes/level_01_lab.tscn"
```

- [ ] **Step 4: Commit**

```bash
git add src/scenes/level_01_lab.tscn project.godot
git commit -m "feat: build Level 1 tutorial (lab enclosure)"
```

---

### Task 12: Wind tunnel (pipe refraction)

**Files:**
- Create: `src/interactables/wind_tunnel.gd`

- [ ] **Step 1: Wind tunnel script**

`src/interactables/wind_tunnel.gd`:
```gdscript
extends Node2D

@export var entry_direction: Vector2 = Vector2.LEFT
@export var exit_direction: Vector2 = Vector2.UP
@export var tunnel_length: float = 200.0

var is_active: bool = false
var active_strength: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	set_meta("display_name", "风道")

func apply_wind_force(force: Vector2) -> void:
	var dot_product := force.normalized().dot(entry_direction.normalized())
	if dot_product > 0.7:
		is_active = true
		active_strength = force.length()
	else:
		is_active = false

func get_exit_force() -> Vector2:
	if not is_active:
		return Vector2.ZERO
	return exit_direction.normalized() * active_strength * 0.8
```

- [ ] **Step 2: Commit**

```bash
git add src/interactables/wind_tunnel.gd
git commit -m "feat: add wind tunnel pipe with direction refraction"
```

---

### Task 13: Researcher enemy

**Files:**
- Create: `src/actors/enemies/base_enemy.gd`
- Create: `src/actors/enemies/researcher.gd`

- [ ] **Step 1: Base enemy class**

`src/actors/enemies/base_enemy.gd`:
```gdscript
extends CharacterBody2D
class_name BaseEnemy

enum State { IDLE, PATROL, CHASE, STUNNED }

var current_state: State = State.IDLE

signal enemy_touched_player()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		enemy_touched_player.emit()
		body.die()

func stun(duration: float = 2.0) -> void:
	current_state = State.STUNNED
	await get_tree().create_timer(duration).timeout
	current_state = State.PATROL
```

- [ ] **Step 2: Researcher enemy**

`src/actors/enemies/researcher.gd`:
```gdscript
extends BaseEnemy

@export var patrol_speed: float = 80.0
@export var chase_speed: float = 150.0
@export var detection_range: float = 300.0
@export var patrol_points: Array[Vector2] = []

var patrol_index: int = 0
var player_ref: Node2D = null

func _ready() -> void:
	current_state = State.PATROL
	$DetectionArea.body_entered.connect(_on_detection_body_entered)
	$DetectionArea.body_exited.connect(_on_detection_body_exited)

func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.STUNNED:
			velocity = Vector2.ZERO
	move_and_slide()

func _patrol(delta: float) -> void:
	if patrol_points.size() == 0:
		return
	var target := patrol_points[patrol_index]
	var dir := (target - global_position).normalized()
	velocity = dir * patrol_speed
	if global_position.distance_to(target) < 10.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()

func _chase(delta: float) -> void:
	if player_ref == null:
		return
	var dir := (player_ref.global_position - global_position).normalized()
	velocity = dir * chase_speed

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		current_state = State.CHASE

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = null
		current_state = State.PATROL
```

Scene setup for researcher.tscn: CharacterBody2D root with CollisionShape2D (rectangle), Sprite2D, child Area2D "DetectionArea" with larger circle shape.

- [ ] **Step 3: Commit**

```bash
git add src/actors/enemies/base_enemy.gd src/actors/enemies/researcher.gd
git commit -m "feat: add base enemy and patrol/chase researcher"
```

---

### Task 14: Level 2 — Ventilation Ducts

**Files:**
- Create: `src/scenes/level_02_vents.tscn`

- [ ] **Step 1: Build Level 2 scene**

Create `src/scenes/level_02_vents.tscn` using Level 1 as template (copy level_manager, WindSystem, TargetSelector, WindLine, HUD).

Set `level_name = "逃亡·通风管道"`, `next_level_path = "res://src/scenes/level_03_canyon.tscn"`.

**Terrain:** Narrow pipe corridors (tile width ~100px), branching paths, vertical shafts.

**Elements:**
- Wind tunnel instances at pipe bends — player blows wind in, it refracts along pipe
- Researcher #1: patrols a horizontal corridor below, flashlight Area2D rotates
- Researcher #2: patrols near exit
- Loose panel above researcher — pushable box that falls when blown, stuns researcher
- Iron grate at exit — wind tunnel that needs specific direction to blow open
- Exit portal at pipe opening to outside

- [ ] **Step 2: Commit**

```bash
git add src/scenes/level_02_vents.tscn
git commit -m "feat: build Level 2 ventilation ducts with pipe puzzles and researcher chase"
```

---

### Task 15: Thermal updraft + sandfall + rock pillar

**Files:**
- Create: `src/environment/updraft.gd`
- Create: `src/environment/sandfall.gd`
- Create: `src/interactables/rock_pillar.gd`

- [ ] **Step 1: Thermal updraft**

`src/environment/updraft.gd`:
```gdscript
extends Area2D

@export var lift_force: float = 400.0

func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.velocity.y -= lift_force * delta
```

- [ ] **Step 2: Sandfall hazard**

`src/environment/sandfall.gd`:
```gdscript
extends Area2D

@export var push_force: float = 300.0
@export var interval_on: float = 3.0
@export var interval_off: float = 2.0

var is_active: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_cycle()

func _start_cycle() -> void:
	while true:
		is_active = true
		show()
		await get_tree().create_timer(interval_on).timeout
		is_active = false
		hide()
		await get_tree().create_timer(interval_off).timeout

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and is_active:
		body.velocity.y += push_force * 0.1

func can_be_blown_away(force: Vector2) -> bool:
	return force.length() > 500.0 and is_active
```

- [ ] **Step 3: Rock pillar**

`src/interactables/rock_pillar.gd`:
```gdscript
extends BaseInteractable

var is_fallen: bool = false
@export var fall_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	super._ready()
	set_meta("display_name", "风化岩柱")

func apply_wind_force(force: Vector2) -> void:
	if is_fallen:
		return
	if force.length() > 600.0:
		_fall()

func _fall() -> void:
	is_fallen = true
	freeze = false
	apply_central_impulse(fall_direction * 500.0)
```

- [ ] **Step 4: Commit**

```bash
git add src/environment/updraft.gd src/environment/sandfall.gd src/interactables/rock_pillar.gd
git commit -m "feat: add thermal updraft, intermittent sandfall, and collapsible rock pillar"
```

---

### Task 16: Drone and scorpion enemies

**Files:**
- Create: `src/actors/enemies/drone.gd`
- Create: `src/actors/enemies/scorpion.gd`

- [ ] **Step 1: Pursuit drone**

`src/actors/enemies/drone.gd`:
```gdscript
extends BaseEnemy

@export var patrol_radius: float = 250.0
@export var chase_speed: float = 200.0
@export var detection_range: float = 400.0

var origin: Vector2
var patrol_angle: float = 0.0
var player_ref: Node2D = null

func _ready() -> void:
	origin = global_position
	current_state = State.PATROL
	$DetectionArea.body_entered.connect(func(b): if b.is_in_group("player"): player_ref = b; current_state = State.CHASE)
	$DetectionArea.body_exited.connect(func(b): if b.is_in_group("player"): player_ref = null; current_state = State.PATROL)

func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			patrol_angle += delta * 1.5
			global_position = origin + Vector2(cos(patrol_angle), sin(patrol_angle)) * patrol_radius
		State.CHASE:
			if player_ref:
				global_position = global_position.move_toward(player_ref.global_position, chase_speed * delta)
		State.STUNNED:
			pass
```

- [ ] **Step 2: Wall scorpion**

`src/actors/enemies/scorpion.gd`:
```gdscript
extends BaseEnemy

@export var lunge_speed: float = 400.0
@export var trigger_range: float = 150.0

var is_lunging: bool = false
var home_position: Vector2

func _ready() -> void:
	home_position = global_position
	current_state = State.IDLE
	$TriggerArea.body_entered.connect(_on_trigger)

func _on_trigger(body: Node2D) -> void:
	if body.is_in_group("player") and not is_lunging:
		_lunge(body.global_position)

func _lunge(target: Vector2) -> void:
	is_lunging = true
	var dir := (target - global_position).normalized()
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_position + dir * 200.0, 0.3)
	tween.tween_property(self, "global_position", home_position, 0.8)
	tween.finished.connect(func(): is_lunging = false)

func _physics_process(delta: float) -> void:
	if is_lunging:
		for body in $HitArea.get_overlapping_bodies():
			if body.is_in_group("player"):
				body.die()
```

- [ ] **Step 3: Commit**

```bash
git add src/actors/enemies/drone.gd src/actors/enemies/scorpion.gd
git commit -m "feat: add pursuit drone and wall-ambush scorpion enemies"
```

---

### Task 17: Level 3 — Canyon

**Files:**
- Create: `src/scenes/level_03_canyon.tscn`

- [ ] **Step 1: Build Level 3 scene**

Create `src/scenes/level_03_canyon.tscn`. Set `level_name = "荒原·炽风峡谷"`, `next_level_path = "res://src/scenes/level_04_grassland.tscn"`.

**Terrain:** Wide open vertical space. Canyon walls (tiles) on left and right. Rocky platforms at various heights. Orange/red color palette.

**Elements:**
- 3 thermal updraft zones at key vertical traversal points
- 2 sandfall hazards blocking paths — player must time passage
- 2 rock pillars: one to blow down as bridge, one to crush drone
- 2 drones patrolling in circular patterns
- 3 scorpions on walls at choke points
- Spawn at canyon bottom where player lands from pipe exit
- Exit portal at canyon top (grassland transition)

- [ ] **Step 2: Commit**

```bash
git add src/scenes/level_03_canyon.tscn
git commit -m "feat: build Level 3 canyon with updrafts, sandfalls, drones, and scorpions"
```

---

### Task 18: Wind zone, windmill, dandelion

**Files:**
- Create: `src/environment/wind_zone.gd`
- Create: `src/interactables/windmill_chain.gd`
- Create: `src/interactables/dandelion.gd`

- [ ] **Step 1: Directional wind zone**

`src/environment/wind_zone.gd`:
```gdscript
extends Area2D

@export var wind_direction: Vector2 = Vector2.RIGHT
@export var wind_strength: float = 200.0

func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.velocity += wind_direction.normalized() * wind_strength * delta
```

- [ ] **Step 2: Windmill chain mechanism**

`src/interactables/windmill_chain.gd`:
```gdscript
extends Node2D

@export var required_fan_count: int = 2
@export var target_door: Node2D = null

var activated_fans: int = 0

func _ready() -> void:
	for child in get_children():
		if child is BaseInteractable:
			child.set_meta("display_name", "风扇")

func register_fan_activation() -> void:
	activated_fans += 1
	if activated_fans >= required_fan_count:
		_open_door()

func _open_door() -> void:
	if target_door:
		var tween := create_tween()
		tween.tween_property(target_door, "position", target_door.position + Vector2(0, -200), 1.0)
```

- [ ] **Step 3: Dandelion updraft**

`src/interactables/dandelion.gd`:
```gdscript
extends Area2D

var is_active: bool = false
@export var updraft_force: float = 500.0
@export var duration: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_active:
		activate()

func activate() -> void:
	is_active = true
	$Particles.emitting = true
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func(): is_active = false; $Particles.emitting = false)

func _physics_process(delta: float) -> void:
	if not is_active:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.velocity.y -= updraft_force * delta
```

- [ ] **Step 4: Commit**

```bash
git add src/environment/wind_zone.gd src/interactables/windmill_chain.gd src/interactables/dandelion.gd
git commit -m "feat: add wind zone, windmill chain puzzle, and dandelion updraft"
```

---

### Task 19: Eagle and mothership enemies

**Files:**
- Create: `src/actors/enemies/eagle.gd`
- Create: `src/actors/enemies/mothership.gd`

- [ ] **Step 1: Dive-bomb eagle**

`src/actors/enemies/eagle.gd`:
```gdscript
extends BaseEnemy

@export var dive_speed: float = 350.0
@export var patrol_height: float = 300.0
@export var dive_cooldown: float = 3.0

var can_dive: bool = true
var player_ref: Node2D = null

func _ready() -> void:
	current_state = State.PATROL
	$DetectionArea.body_entered.connect(func(b): if b.is_in_group("player"): player_ref = b)
	$DetectionArea.body_exited.connect(func(b): if b.is_in_group("player"): player_ref = null)

func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			global_position.x += cos(Time.get_ticks_msec() * 0.001) * 2.0
		State.CHASE:
			if player_ref and can_dive:
				_dive()

func _dive() -> void:
	can_dive = false
	var target := player_ref.global_position
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.5)
	tween.tween_property(self, "global_position", Vector2(target.x, target.y - patrol_height), 1.0)
	tween.finished.connect(func():
		can_dive = true
		if player_ref == null:
			current_state = State.PATROL
	)

func _on_hit_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.die()
```

- [ ] **Step 2: Mothership drone**

`src/actors/enemies/mothership.gd`:
```gdscript
extends BaseEnemy

@export var patrol_path: Array[Vector2] = []
@export var spawn_interval: float = 4.0

var path_index: int = 0
var small_drone_scene: PackedScene = preload("res://src/actors/enemies/drone.tscn")

func _ready() -> void:
	current_state = State.PATROL
	_spawn_loop()

func _physics_process(delta: float) -> void:
	if patrol_path.size() == 0:
		return
	var target := patrol_path[path_index]
	global_position = global_position.move_toward(target, 80.0 * delta)
	if global_position.distance_to(target) < 10.0:
		path_index = (path_index + 1) % patrol_path.size()

func _spawn_loop() -> void:
	while true:
		await get_tree().create_timer(spawn_interval).timeout
		var drone := small_drone_scene.instantiate()
		drone.global_position = global_position
		get_parent().add_child(drone)
```

- [ ] **Step 3: Commit**

```bash
git add src/actors/enemies/eagle.gd src/actors/enemies/mothership.gd
git commit -m "feat: add dive-bomb eagle and mothership enemy spawner"
```

---

### Task 20: Level 4 — Grassland

**Files:**
- Create: `src/scenes/level_04_grassland.tscn`

- [ ] **Step 1: Build Level 4 scene**

Create `src/scenes/level_04_grassland.tscn`. Set `level_name = "上升·风之草原"`, `next_level_path = "res://src/scenes/level_05_stormeye.tscn"`.

**Terrain:** Wide horizontal scrolling space. Golden grass tiles. Ancient stone platforms. Windmill structures. Storm tower visible at far right.

**Elements:**
- 4 directional wind zones (left-to-right, right-to-left) creating navigation challenge
- 3 dandelion clusters at vertical gaps
- Twin windmill puzzle: 2 windmill fans must both be activated to lower a drawbridge
- 2 eagles circling above patrol zones
- 1 mothership at grassland center, patrolling a rectangular path, spawning small drones
- Exit portal at base of storm tower

- [ ] **Step 2: Commit**

```bash
git add src/scenes/level_04_grassland.tscn
git commit -m "feat: build Level 4 grassland with wind zones, windmill puzzle, eagles, and mothership"
```

---

### Task 21: Boss — Windcatcher

**Files:**
- Create: `src/actors/enemies/boss_windcatcher.gd`
- Create: `src/ui/boss_health.gd`

- [ ] **Step 1: Boss health bar**

`src/ui/boss_health.gd`:
```gdscript
extends CanvasLayer

@onready var health_bar: ProgressBar = $BossHealthBar
@onready var label: Label = $BossNameLabel
@onready var phase_label: Label = $PhaseLabel

func _ready() -> void:
	hide()

func show_boss(name_str: String, max_hp: float) -> void:
	show()
	label.text = name_str
	health_bar.max_value = max_hp
	health_bar.value = max_hp

func update_health(current_hp: float) -> void:
	health_bar.value = current_hp

func update_phase(phase: int) -> void:
	phase_label.text = "阶段 " + str(phase)

func hide_boss() -> void:
	hide()
```

- [ ] **Step 2: Boss Windcatcher**

`src/actors/enemies/boss_windcatcher.gd`:
```gdscript
extends Node2D

enum WindState { INHALE, STORM, CALM }
enum BossPhase { P1, P2, P3 }

@export var max_health: float = 100.0
var current_health: float = 100.0
var current_wind_state: WindState = WindState.CALM
var current_phase: BossPhase = BossPhase.P1
var state_timer: float = 0.0

@export var calm_duration: float = 7.0
@export var inhale_duration: float = 6.0
@export var storm_duration: float = 5.0

@export var inhale_force: float = 300.0
@export var storm_push_force: float = 500.0

@onready var core: Area2D = $Core
@onready var arm_container: Node2D = $Arms

var boss_health_ui: CanvasLayer

signal boss_defeated()

func _ready() -> void:
	boss_health_ui = get_node("/root/BossHealth")
	boss_health_ui.show_boss("捕风者", max_health)
	current_wind_state = WindState.CALM
	_calibrate_durations()

func _calibrate_durations() -> void:
	match current_phase:
		BossPhase.P1:
			calm_duration = 7.0
			inhale_duration = 6.0
			storm_duration = 5.0
		BossPhase.P2:
			calm_duration = 5.0
			inhale_duration = 5.0
			storm_duration = 4.0
		BossPhase.P3:
			calm_duration = 3.0
			inhale_duration = 4.0
			storm_duration = 3.0

func _process(delta: float) -> void:
	state_timer += delta
	match current_wind_state:
		WindState.CALM:
			if state_timer >= calm_duration:
				_transition_to(WindState.INHALE)
		WindState.INHALE:
			_apply_inhale(delta)
			if state_timer >= inhale_duration:
				core.monitoring = true
				_transition_to(WindState.STORM)
		WindState.STORM:
			_apply_storm(delta)
			if state_timer >= storm_duration:
				core.monitoring = false
				_transition_to(WindState.CALM)

func _apply_inhale(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var dir := (global_position - player.global_position).normalized()
		player.velocity += dir * inhale_force * delta

	for body in get_tree().get_nodes_in_group("interactable"):
		if body is RigidBody2D:
			var dir := (global_position - body.global_position).normalized()
			body.apply_central_force(dir * inhale_force * 0.5)

func _apply_storm(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.velocity += Vector2.RIGHT * storm_push_force * delta

func take_damage(amount: float) -> void:
	current_health -= amount
	boss_health_ui.update_health(current_health)
	if current_health <= 66.0 and current_phase == BossPhase.P1:
		current_phase = BossPhase.P2
		_calibrate_durations()
		boss_health_ui.update_phase(2)
	elif current_health <= 33.0 and current_phase == BossPhase.P2:
		current_phase = BossPhase.P3
		_calibrate_durations()
		boss_health_ui.update_phase(3)
	if current_health <= 0.0:
		_die()

func _on_core_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and current_wind_state == WindState.STORM:
		take_damage(15.0)

func _transition_to(new_state: WindState) -> void:
	current_wind_state = new_state
	state_timer = 0.0

func _die() -> void:
	boss_defeated.emit()
	boss_health_ui.hide_boss()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.3)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	tween.tween_callback(queue_free)
```

- [ ] **Step 3: Commit**

```bash
git add src/actors/enemies/boss_windcatcher.gd src/ui/boss_health.gd
git commit -m "feat: implement Windcatcher boss with 3-phase wind cycle"
```

---

### Task 22: Level 5 — Storm Eye (Boss fight)

**Files:**
- Create: `src/scenes/level_05_stormeye.tscn`

- [ ] **Step 1: Build Level 5 scene**

Create `src/scenes/level_05_stormeye.tscn`. Set `level_name = "归宿·飓风之眼"`, `next_level_path = ""` (end of game).

**Terrain:** Vertical tower shaft interior. Dark gray stone. Spikes on left and right walls. Floating debris platforms. No kill floor (open bottom = death by spikes/walls).

**Elements:**
- Boss Windcatcher instance at tower center
- Instantiate boss health UI (`src/scenes/ui/boss_health.tscn`)
- Scattered rocks (pushable boxes) that can be blown into boss core
- Spikes lining walls
- Wind zone at base pushing upward (environmental storytelling)
- On `boss_defeated` signal: play victory sequence (fade to white, credits/end screen)

- [ ] **Step 2: Add victory trigger**

Create a simple end screen node that shows on boss defeat. For now, a `ColorRect` that fades in white with text "自由" centered.

- [ ] **Step 3: Commit**

```bash
git add src/scenes/level_05_stormeye.tscn
git commit -m "feat: build Level 5 boss arena with Windcatcher and victory sequence"
```

---

### Task 23: Audio integration

**Files:**
- Create: `src/autoload/audio_manager.gd`

- [ ] **Step 1: Audio manager singleton**

`src/autoload/audio_manager.gd`:
```gdscript
extends Node

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var level_music := {
	"level_01": preload("res://assets/audio/music_lab.ogg"),
	"level_02": preload("res://assets/audio/music_vents.ogg"),
	"level_03": preload("res://assets/audio/music_canyon.ogg"),
	"level_04": preload("res://assets/audio/music_grassland.ogg"),
	"level_05": preload("res://assets/audio/music_boss.ogg"),
}

var sfx_library := {
	"wind_blow": preload("res://assets/audio/sfx_wind.ogg"),
	"target_switch": preload("res://assets/audio/sfx_switch.ogg"),
	"energy_depleted": preload("res://assets/audio/sfx_energy_low.ogg"),
	"death": preload("res://assets/audio/sfx_death.ogg"),
	"checkpoint": preload("res://assets/audio/sfx_checkpoint.ogg"),
	"boss_hit": preload("res://assets/audio/sfx_boss_hit.ogg"),
}

func play_level_music(level_id: String) -> void:
	if level_music.has(level_id):
		music_player.stream = level_music[level_id]
		music_player.play()

func play_sfx(sfx_id: String) -> void:
	if sfx_library.has(sfx_id):
		sfx_player.stream = sfx_library[sfx_id]
		sfx_player.play()

func stop_music() -> void:
	music_player.stop()
```

Register as autoload `AudioManager` in `project.godot`.

- [ ] **Step 2: Wire audio to game events**

Modify `src/systems/wind_system.gd` — play `wind_blow` on blow start:
```gdscript
func _start_wind() -> void:
	AudioManager.play_sfx("wind_blow")
```

Modify `src/systems/target_selector.gd` — play `target_switch` on cycle:
```gdscript
func _cycle_target() -> void:
	AudioManager.play_sfx("target_switch")
```

Modify `src/actors/player.gd` — play `death` on death:
```gdscript
func die() -> void:
	AudioManager.play_sfx("death")
```

- [ ] **Step 3: Create placeholder audio directories**

```powershell
New-Item -ItemType Directory -Force -Path "assets\audio"
```

Add placeholder `.ogg` files or `.gitkeep`. Audio assets can be generated via AI tools and replaced later.

- [ ] **Step 4: Commit**

```bash
git add src/autoload/audio_manager.gd project.godot
git commit -m "feat: add audio manager with level music and SFX hooks"
```

---

### Task 24: VFX polish and final integration

**Files:**
- Modify: `src/actors/player.gd` (particle effects)
- Modify: `src/ui/wind_line.gd` (wind strength visualization)

- [ ] **Step 1: Add player trail particles**

Modify `src/actors/player.gd` — add leaf particle trail:
```gdscript
@onready var trail: GPUParticles2D = $Trail

func _ready() -> void:
	trail = GPUParticles2D.new()
	trail.one_shot = false
	trail.lifetime = 0.5
	trail.process_material = ParticleProcessMaterial.new()
	trail.process_material.gravity = Vector2(0, 50)
	trail.process_material.initial_velocity_min = 20.0
	trail.process_material.initial_velocity_max = 40.0
	trail.process_material.spread = 45.0
	add_child(trail)
```

- [ ] **Step 2: Enhance wind line with strength feedback**

Modify `src/ui/wind_line.gd` — line thickness scales with blow strength:
```gdscript
var current_strength: float = 0.0

func set_strength(s: float) -> void:
	current_strength = s

func _draw() -> void:
	var width := line_width * (1.0 + current_strength * 2.0)
	draw_dashed_line(mouse_pos, target.global_position, line_color, width, 8.0)
```

- [ ] **Step 3: Add screen shake on death**

Modify `src/actors/player.gd`:
```gdscript
func die() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera:
		var tween := create_tween()
		tween.tween_property(camera, "offset", Vector2(5, 0), 0.05)
		tween.tween_property(camera, "offset", Vector2(-5, 0), 0.05)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)
	AudioManager.play_sfx("death")
	# ... rest of die logic
```

- [ ] **Step 4: Full integration test**

Run the game and verify:
1. Level 1 tutorial flow works end-to-end
2. Level 2 pipe refraction and researcher chase
3. Level 3 updrafts/sandfalls/drones/scorpions
4. Level 4 wind zones/windmill/eagles/mothership
5. Level 5 boss 3-phase cycle and victory

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "feat: add VFX polish, screen shake, wind line strength, and integration fixes"
```

---

## Development Order Summary

| Day | Tasks | What's Playable |
|-----|-------|-----------------|
| 1-2 | 1-8: Scaffold, energy, player, wind, target, HUD, death | Wind mechanic prototype |
| 3-4 | 9-11: Interactables, level manager, Level 1 | Full tutorial level |
| 5-6 | 12-14: Wind tunnel, researcher, Level 2 | 2 levels playable |
| 7-8 | 15-17: Updraft/sandfall/rock, drone/scorpion, Level 3 | 3 levels playable |
| 9-10 | 18-20: Wind zone/windmill/dandelion, eagle/mothership, Level 4 | 4 levels playable |
| 11-12 | 21-22: Boss + boss UI, Level 5 | Full game playable |
| 13-14 | 23-24: Audio, VFX polish, testing | Release candidate |

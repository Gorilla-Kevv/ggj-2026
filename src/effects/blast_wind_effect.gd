# ============================================================
# WindStreakEffect — Boss 战全屏风流线特效
# 挂载在 stage_5 场景根节点上
# SUCTION: 线条向右飞（吸向Boss），吹风时显示
# BLAST:   线条向左飞（吹离Boss），吹风时显示
# ============================================================
extends Node2D

@export var line_count: int = 25
@export var line_speed_min: float = 800.0
@export var line_speed_max: float = 1600.0
@export var line_width_min: float = 4.0
@export var line_width_max: float = 10.0
@export var line_alpha: float = 0.7

enum Direction { RIGHT, LEFT }
var _direction: int = Direction.RIGHT
var _active: bool = false
var _pulse_active: bool = true
var _lines: Array = []

var _suction_color: Color = Color(0.5, 0.9, 1.0)
var _blast_color: Color = Color(1.0, 0.7, 0.5)

func _ready() -> void:
	visible = false
	z_index = 100
	for i in range(line_count):
		var l := Line2D.new()
		l.z_index = 100
		l.z_as_relative = false
		l.begin_cap_mode = Line2D.LINE_CAP_NONE
		l.end_cap_mode = Line2D.LINE_CAP_NONE
		add_child(l)
		_lines.append({
			"line": l,
			"x": randf_range(-400, 2800),
			"y": randf_range(-200, 2400),
			"length": randf_range(200, 600),
			"speed": randf_range(line_speed_min, line_speed_max),
			"width": randf_range(line_width_min, line_width_max)
		})

func set_direction(dir: int) -> void:
	_direction = dir

# 开/关（绑定到阶段）
func set_active(on: bool) -> void:
	_active = on

# 脉冲开/关（Boss 的 blast_pulse_on/off 驱动）
func set_pulse(on: bool) -> void:
	_pulse_active = on

func _process(delta: float) -> void:
	var blowing := _active and _pulse_active
	visible = blowing
	if not blowing: return

	# BLAST 阶段脉冲期间屏幕震动
	if _direction == Direction.LEFT:
		_screen_shake(6.0, 0.05)

	var camera: Camera2D = null
	for cam in get_tree().get_nodes_in_group("camera"):
		if cam is Camera2D:
			camera = cam
			break
	if camera == null: return

	var cam_pos := camera.global_position
	var view_w := get_viewport().get_visible_rect().size.x / camera.zoom.x
	var view_h := get_viewport().get_visible_rect().size.y / camera.zoom.y

	var left := cam_pos.x - view_w * 0.5 - 200
	var right := cam_pos.x + view_w * 0.5 + 200
	var top := cam_pos.y - view_h * 0.5
	var bot := cam_pos.y + view_h * 0.5

	var base_color := _suction_color if _direction == Direction.RIGHT else _blast_color
	var c := Color(base_color.r, base_color.g, base_color.b, line_alpha)

	for data in _lines:
		if _direction == Direction.RIGHT:
			data["x"] += data["speed"] * delta
			if data["x"] > right + 200:
				data["x"] = left - data["length"] - randf_range(0, 300)
				data["y"] = randf_range(top, bot)
				data["length"] = randf_range(200, 600)
				data["speed"] = randf_range(line_speed_min, line_speed_max)
				data["width"] = randf_range(line_width_min, line_width_max)
		else:
			data["x"] -= data["speed"] * delta
			if data["x"] + data["length"] < left - 200:
				data["x"] = right + randf_range(0, 300)
				data["y"] = randf_range(top, bot)
				data["length"] = randf_range(200, 600)
				data["speed"] = randf_range(line_speed_min, line_speed_max)
				data["width"] = randf_range(line_width_min, line_width_max)

		var line: Line2D = data["line"]
		line.global_position = Vector2(data["x"], data["y"])
		line.width = data["width"]
		line.default_color = c
		line.gradient = _make_gradient(c)
		line.points = PackedVector2Array([Vector2.ZERO, Vector2(data["length"], 0)])

func _make_gradient(c: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 1.0])
	g.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0),
		Color(c.r, c.g, c.b, c.a),
		Color(c.r, c.g, c.b, c.a * 0.2)
	])
	return g

func _screen_shake(strength: float, duration: float) -> void:
	for node in get_tree().get_nodes_in_group("screen_shaker"):
		if node.has_method("screen_shake"):
			node.screen_shake(strength, duration)
			return

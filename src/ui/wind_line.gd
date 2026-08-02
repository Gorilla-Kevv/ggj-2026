extends Node2D

@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var line_width: float = 2.0
@export var particle_count: int = 8

var current_strength: float = 0.0
var particles: Array[Sprite2D] = []

func _ready() -> void:
	for i in range(particle_count):
		var p := Sprite2D.new()
		p.scale = Vector2(0.3, 0.3)
		p.modulate = Color(0.6, 0.8, 1.0, 0.6)
		p.visible = false
		add_child(p)
		particles.append(p)

func _process(_delta: float) -> void:
	var global := get_node("/root/Global")
	var target := global.selected_target
	if target == null or not is_instance_valid(target):
		_hide_all()
		return

	var mouse_pos := get_viewport().get_mouse_position()
	_update_particles(mouse_pos, target.global_position)
	queue_redraw()

func set_strength(s: float) -> void:
	current_strength = s

func _update_particles(mouse_pos: Vector2, target_pos: Vector2) -> void:
	var diff := target_pos - mouse_pos
	var dist := diff.length()
	if dist < 1.0:
		_hide_all()
		return

	var norm := diff.normalized()
	for i in range(particle_count):
		var t := float(i) / float(maxf(particle_count - 1, 1))
		var pos := mouse_pos + norm * dist * t
		particles[i].position = pos
		particles[i].visible = true

func _hide_all() -> void:
	for p in particles:
		p.visible = false

func _draw() -> void:
	var global := get_node("/root/Global")
	var target := global.selected_target
	if target == null or not is_instance_valid(target):
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var width := line_width * (1.0 + current_strength * 3.0)
	draw_dashed_line(mouse_pos, target.global_position, line_color, width, 8.0, true)

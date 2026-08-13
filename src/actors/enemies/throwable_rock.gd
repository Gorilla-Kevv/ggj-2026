# ============================================================
# ThrowableRock — 可投掷石头 (Boss 战第三阶段)
# 继承 BaseInteractable (RigidBody2D)，自动加入 "interactable" 组
# 玩家 R 键选中后用风控系统吹向 Boss
# 碰到 Boss → 造成伤害并销毁
# ============================================================
extends BaseInteractable
class_name ThrowableRock

@export var hit_damage: float = 50.0
@export var lifetime: float = 20.0
@export var blink_before: float = 3.0

var _is_destroyed: bool = false

func _ready() -> void:
	super._ready()
	body_entered.connect(_on_body_entered)
	# 闪烁提醒 → 超时销毁
	get_tree().create_timer(lifetime - blink_before).timeout.connect(_start_blink)
	get_tree().create_timer(lifetime).timeout.connect(_on_timeout)

func _start_blink() -> void:
	if _is_destroyed: return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate:a", 0.2, 0.3)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	# 闪烁持续到销毁

func _on_body_entered(body: Node) -> void:
	if body is BossWindcatcher:
		body.hit_by_rock(hit_damage)
		_destroy()

# 超时自动销毁也用同样逻辑
func _on_timeout() -> void:
	_destroy()

func _destroy() -> void:
	if _is_destroyed: return
	_is_destroyed = true
	modulate = Color.WHITE
	# 先从 interactable 组移除，防止 _refresh_targets 重新加入
	remove_from_group("interactable")
	# 如果当前选中的是这块石头，清理引用防止 camera_controller 报错
	var global := get_node("/root/Global")
	if global.selected_target == self:
		global.selected_target = null
	get_tree().call_group("target_selector", "_refresh_targets")
	queue_free()

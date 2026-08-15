# ============================================================
# HintTrigger — 教程提示触发器 (Area2D)
# 玩家进入区域时弹出提示弹窗 (HintPopup)，播放提示音效
# 每次进入都会触发；弹窗定时自动关闭或玩家按 Enter/E 手动关闭
#
# 场景中放置:
#   HintTrigger (Area2D)          ← 挂本脚本
#   └── CollisionShape2D          ← 触发范围 (检测 player 层)
#
# Inspector 可配置:
#   title:     提示标题 (留空则只显示正文)
#   message:   提示正文 (支持 \n 换行)
#   auto_hide_time: 自动消失秒数
#   popup_scene:   弹窗场景路径 (默认 hint_popup.tscn)
# ============================================================
extends Area2D

# 提示标题 (留空则不显示标题行)
@export var title: String = ""
# 提示正文
@export_multiline var message: String = "提示文字"
# 定时自动消失秒数
@export var auto_hide_time: float = 3.0
# 是否只显示一次 (true=仅第一次进入触发，false=每次进入都弹)
@export var show_once: bool = true
# 弹窗场景 (默认使用项目内 hint_popup.tscn)
@export var popup_scene: PackedScene = preload("res://src/scenes/ui/hint_popup.tscn")

# 是否已显示过 (show_once 模式下阻止重复触发)
var _has_shown: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = false
	# 检测玩家所在层 (layer 1 = player)
	collision_mask = 1
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

# 碰撞回调：玩家进入 → 显示弹窗 + 播放音效
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	# 只显示一次：已显示过则跳过
	if show_once and _has_shown:
		return
	_has_shown = true

	# 查找场景中已存在的弹窗 (复用)，没有则实例化一个
	var popup := get_tree().get_first_node_in_group("hint_popup")
	if popup == null:
		popup = popup_scene.instantiate()
		get_tree().current_scene.add_child(popup)

	if popup and popup.has_method("show_hint"):
		popup.show_hint(title, message, auto_hide_time)

	# 播放提示音效 (复用现有 UI 选择音效)
	var audio := get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("sfx_select"):
		audio.sfx_select()

# 碰撞回调：玩家离开 → 关闭弹窗
func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var popup := get_tree().get_first_node_in_group("hint_popup")
	if popup and popup.has_method("hide_now"):
		popup.hide_now()

# ============================================================
# HintPopup — 教程/提示弹窗 (CanvasLayer)
# 由 HintTrigger (Area2D) 调用 show_hint() 显示提示文字
# 定时自动淡出，或玩家按 ui_confirm (Enter/E) 手动关闭
# 注册到 "hint_popup" 组，供触发器查找复用
# ============================================================
extends CanvasLayer

# 弹窗面板子节点引用 (场景中手动放置)
# Panel:     PanelContainer，弹窗背景框
# Title:     Label，标题文字
# Message:   Label，正文文字 (多行)
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/Title
@onready var message_label: Label = $Panel/VBox/Message

var _tween: Tween = null
var _is_visible: bool = false

func _ready() -> void:
	# 注册到组，供 HintTrigger 查找
	add_to_group("hint_popup")
	panel.modulate.a = 0.0
	panel.visible = false

# 显示提示 (供 HintTrigger 调用)
# title:    标题文字
# message:  正文文字 (支持 \n 换行)
# auto_hide_time: 定时自动消失秒数
func show_hint(title: String, message: String, auto_hide_time: float = 3.0) -> void:
	title_label.text = title
	message_label.text = message
	# 标题为空则隐藏标题行
	title_label.visible = title != ""

	# 打断上一个淡出动画，立即展示新内容
	if _tween and _tween.is_valid():
		_tween.kill()

	panel.visible = true
	panel.modulate.a = 0.0
	_is_visible = true

	# 淡入 → 停留 → 淡出 → 隐藏
	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(auto_hide_time)
	_tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	_tween.tween_callback(_hide)

# 手动关闭 (按 ui_confirm 键)
func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if event.is_action_pressed("ui_confirm"):
		_hide()

# 隐藏弹窗并清理动画
func _hide() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_is_visible = false
	panel.visible = false
	panel.modulate.a = 0.0

# 立即关闭弹窗 (供 HintTrigger 离开区域时调用)
func hide_now() -> void:
	_hide()

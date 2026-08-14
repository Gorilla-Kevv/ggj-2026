# ============================================================
# MainMenu — 主菜单
# 挂载于主菜单场景根节点 (Control)
# 四个按钮：新游戏 / 继续 / 设置 / 退出
# 各按钮通过 @export 场景路径跳转，退出按钮直接退出
# ============================================================
extends Control

# ---------- 跳转场景路径 (Inspector 配置) ----------
@export var new_game_scene: String = "res://src/scenes/hub_world.tscn"
@export var continue_scene: String = "res://src/scenes/hub_world.tscn"
@export var settings_scene: String = "res://src/scenes/ui/settings_menu.tscn"

# ---------- 子节点引用 ----------
@onready var new_game_button: Button = $MenuBox/NewGameButton
@onready var continue_button: Button = $MenuBox/ContinueButton
@onready var settings_button: Button = $MenuBox/SettingsButton
@onready var quit_button: Button = $MenuBox/QuitButton

func _ready() -> void:
	# 连接按钮信号
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# 无存档时禁用"继续"，设置场景未配置时禁用"设置"
	var global := get_node("/root/Global")
	continue_button.disabled = not global.has_save()
	if settings_scene.is_empty():
		settings_button.disabled = true

# ---------- 按钮回调 ----------

func _on_new_game_pressed() -> void:
	var global := get_node("/root/Global")
	global.delete_save()   # 清除旧存档，从头开始
	get_tree().change_scene_to_file(new_game_scene)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file(continue_scene)

func _on_settings_pressed() -> void:
	if not settings_scene.is_empty():
		get_tree().change_scene_to_file(settings_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()

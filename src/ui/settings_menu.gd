# ============================================================
# SettingsMenu — 设置菜单
# 挂载于设置场景根节点 (Control)
# 三个模块：玩家物理 / 风力 / 音乐音效，每个参数带滑块 + 手动输入框
# 动态生成 UI，参数改动即时写入 Settings 并保存
# ============================================================
extends Control

# 参数定义: [key, 显示名, 最小值, 最大值, 步进]
const PLAYER_PARAMS: Array = [
	["gravity_scale", "重力缩放", 0.0, 1.0, 0.01],
	["max_speed", "最大速度", 100.0, 2000.0, 10.0],
	["ground_friction", "地面摩擦", 0.0, 1.0, 0.01],
	["ground_bounce", "地面弹跳", 0.0, 1.0, 0.05],
	["wall_bounce", "墙壁反弹", 0.0, 2.0, 0.1],
	["key_move_force", "移动力", 50.0, 500.0, 10.0],
]

const WIND_PARAMS: Array = [
	["max_wind_force", "最大风力", 100.0, 2000.0, 50.0],
	["wind_ramp_time", "蓄力时间", 0.1, 5.0, 0.1],
	["energy_drain", "能量消耗", 1.0, 20.0, 0.5],
	["energy_regen", "能量回复", 0.5, 20.0, 0.5],
]

const AUDIO_PARAMS: Array = [
	["music_volume_db", "音乐音量", -60.0, 0.0, 1.0],
	["sfx_volume_db", "音效音量", -60.0, 0.0, 1.0],
]

var _settings: Node = null

func _ready() -> void:
	_settings = get_node("/root/Settings")
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.offset_left = 200.0
	root.offset_top = 80.0
	root.offset_right = -200.0
	root.offset_bottom = -80.0
	add_child(root)

	# 标题
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# 三个模块
	_build_section(root, "玩家物理", PLAYER_PARAMS)
	_build_section(root, "风力", WIND_PARAMS)
	_build_section(root, "音乐音效", AUDIO_PARAMS)

	# 返回按钮
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(0, 50)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(_on_back_pressed)
	root.add_child(back)

func _build_section(parent: VBoxContainer, title_text: String, params: Array) -> void:
	var header := Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	parent.add_child(header)

	for p in params:
		_build_param_row(parent, p[0], p[1], p[2], p[3], p[4])

# 一行参数: [Label | HSlider | SpinBox]
func _build_param_row(parent: VBoxContainer, key: String, label: String, min_v: float, max_v: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(140, 0)
	name_label.add_theme_font_size_override("font_size", 20)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = _settings.get(key)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = _settings.get(key)
	spin.custom_minimum_size = Vector2(100, 0)
	row.add_child(spin)

	# 双向同步 + 写入设置
	slider.value_changed.connect(func(v: float): spin.set_value_no_signal(v))
	spin.value_changed.connect(func(v: float):
		slider.set_value_no_signal(v)
		_apply(key, v)
	)

func _apply(key: String, value: float) -> void:
	_settings.set_param(key, value)
	_settings.save_settings()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/ui/main_menu.tscn")

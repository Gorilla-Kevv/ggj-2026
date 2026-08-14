# ============================================================
# SettingsMenu — 设置菜单
# 挂载于设置场景根节点 (Control)
# 三个模块横向排列，模块内竖向，每个参数带滑块 + 手动输入框
# 参数改动即时写入 Settings 并保存；提供恢复默认按钮
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
	["master_volume_db", "总音量", -60.0, 0.0, 1.0],
	["music_volume_db", "音乐音量", -60.0, 0.0, 1.0],
	["sfx_volume_db", "音效音量", -60.0, 0.0, 1.0],
]

var _settings: Node = null
# 保存每个 key 的控件引用，恢复默认时刷新
var _sliders: Dictionary = {}
var _spins: Dictionary = {}

func _ready() -> void:
	_settings = get_node("/root/Settings")
	_build_ui()

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	root.offset_left = 80.0
	root.offset_top = 40.0
	root.offset_right = -80.0
	root.offset_bottom = -40.0
	add_child(root)

	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# 三列横向排列
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	_build_section(columns, "玩家物理", PLAYER_PARAMS)
	_build_section(columns, "风力", WIND_PARAMS)
	_build_section(columns, "音乐音效", AUDIO_PARAMS)

	# 按钮行
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(buttons)

	var reset_btn := Button.new()
	reset_btn.text = "恢复默认"
	reset_btn.custom_minimum_size = Vector2(160, 50)
	reset_btn.add_theme_font_size_override("font_size", 22)
	reset_btn.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_btn)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(160, 50)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_on_back_pressed)
	buttons.add_child(back_btn)

func _build_section(parent: HBoxContainer, title_text: String, params: Array) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)

	var header := Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	column.add_child(header)

	for p in params:
		_build_param(column, p[0], p[1], p[2], p[3], p[4])

# 一个参数: 名称+输入框在上行，滑块独占下行 (全宽，保证可拖动)
func _build_param(parent: VBoxContainer, key: String, label: String, min_v: float, max_v: float, step: float) -> void:
	# 上行: 参数名 + 手动输入框
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	parent.add_child(top)

	var name_label := Label.new()
	name_label.text = label
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = _settings.get(key)
	spin.custom_minimum_size = Vector2(80, 0)
	top.add_child(spin)

	# 下行: 滑块独占全宽
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = _settings.get(key)
	slider.custom_minimum_size = Vector2(150, 30)
	parent.add_child(slider)

	_sliders[key] = slider
	_spins[key] = spin

	slider.value_changed.connect(func(v: float): spin.set_value_no_signal(v))
	spin.value_changed.connect(func(v: float):
		slider.set_value_no_signal(v)
		_apply(key, v)
	)

func _apply(key: String, value: float) -> void:
	_settings.set_param(key, value)
	_settings.save_settings()

func _on_reset_pressed() -> void:
	_settings.reset_all()
	# 刷新所有控件显示
	for key in _sliders.keys():
		var v: float = _settings.get(key)
		(_sliders[key] as HSlider).set_value_no_signal(v)
		(_spins[key] as SpinBox).set_value_no_signal(v)
	_settings.save_settings()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/scenes/ui/main_menu.tscn")

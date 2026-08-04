# ============================================================
# LevelDoor — 关卡入口门 (大厅组件)
# 拖入大厅场景，放在章节区域内。玩家触碰 EnterArea 进入对应关卡。
# 依赖 Global 已扩展 (levels_clear / hub_return / current_checkpoint 等)。
#
# 使用：
#   1. 配置 level_id / display_name / chapter_id / target_scene
#   2. level_id 必须与 Global.CHAPTER_LEVELS 中的关卡ID一致 (区分大小写)
#   3. 玩家进入 HintArea 范围显示关卡名；通关后显示 "✓已通关" 并变绿
#   4. 视觉为 _draw() 占位门框，可自行替换为贴图/精灵
#
# 防死循环机制：
#   从关卡返回时玩家出生在门上 (hub_return = 门位置)，若不处理会立刻再次进关。
#   门采用"上膛"机制：场景加载后检查玩家是否已站在接触区内。
#   若已在内（刚返回）→ 保持未上膛，玩家必须离开 EnterArea 后才重新允许进入。
# ============================================================
extends Node2D

# ---------- 导出变量 (编辑器配置) ----------
@export var level_id: String = ""                 # 关卡ID (与注册表一致)
@export var display_name: String = "关卡"          # 显示名
@export var chapter_id: String = ""               # 所属章节ID
@export var target_scene: String = ""             # 目标关卡场景路径
@export var door_color: Color = Color(0.4, 0.7, 1.0)  # 门框颜色 (可按章节配色)

# ---------- 子节点引用 ----------
@onready var enter_area: Area2D = $EnterArea
@onready var hint_area: Area2D = $HintArea
@onready var name_label: Label = $NameLabel

const CLEARED_COLOR: Color = Color(0.3, 1.0, 0.5)

# 进入冷却：场景加载后的一段时间内忽略触碰，防止"从关卡返回出生在门上 → 立即再次进关"。
const ENTRY_COOLDOWN: float = 1.0

# 门是否"上膛"（允许进入）。冷却期内始终未上膛；玩家离开接触区后立即上膛。
var _armed: bool = false
var _cooldown_left: float = ENTRY_COOLDOWN


func _ready() -> void:
	enter_area.body_entered.connect(_on_enter_area_body_entered)
	enter_area.body_exited.connect(_on_enter_area_body_exited)
	hint_area.body_entered.connect(_on_hint_area_body_entered)
	hint_area.body_exited.connect(_on_hint_area_body_exited)
	name_label.hide()

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	# 冷却倒计时：期间忽略所有进关触发（含出生重叠）
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		if _cooldown_left <= 0.0:
			# 冷却结束：若玩家已在区内（刚返回仍站在门上），保持未上膛直到其离开
			if player == null or not enter_area.overlaps_body(player):
				_armed = true
	# 玩家停留在提示范围内时，每帧刷新标签 (通关状态变化时立即更新)
	if not name_label.visible:
		return
	if player and hint_area.overlaps_body(player):
		_update_label()

# ---------- 进入关卡 ----------

# 玩家触碰门 → 记录返回点与关卡信息 → 切换场景
# 仅在冷却结束且上膛状态下响应；否则视为出生重叠，等待玩家离开接触区后再上膛。
func _on_enter_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _cooldown_left > 0.0:
		return
	if not _armed:
		return
	if target_scene.is_empty():
		return
	_armed = false
	var global := get_node("/root/Global")
	global.current_level = level_id
	global.current_chapter = chapter_id
	global.hub_return = global_position
	# 清空检查点，防止上一个关卡的检查点坐标串到新关卡 (新关卡从出生点开始)
	global.current_checkpoint = Vector2.ZERO
	get_tree().call_deferred("change_scene_to_file", target_scene)

# 玩家离开接触区 → 立即重新上膛（即使仍在冷却中），之后再次触碰才会进关
func _on_enter_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_armed = true

# ---------- 提示标签 ----------

func _on_hint_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_update_label()

func _on_hint_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		name_label.hide()

# 更新提示标签内容与颜色
func _update_label() -> void:
	var global := get_node("/root/Global")
	var text := display_name
	if not level_id.is_empty() and global.is_level_clear(level_id):
		text += "  ✓已通关"
		name_label.modulate = CLEARED_COLOR
	else:
		name_label.modulate = Color.WHITE
	name_label.text = text
	name_label.show()

# ---------- 占位视觉 (可替换) ----------

func _draw() -> void:
	var cleared := false
	if not level_id.is_empty():
		var global := get_node("/root/Global")
		cleared = global.is_level_clear(level_id)
	var col := CLEARED_COLOR if cleared else door_color
	var rect := Rect2(-40.0, -70.0, 80.0, 120.0)
	# 光晕 (外圈到内圈)
	for i in range(3):
		var glow_rect := Rect2(
			rect.position - Vector2.ONE * (i + 1) * 6.0,
			rect.size + Vector2.ONE * (i + 1) * 12.0
		)
		draw_rect(glow_rect, Color(col, 0.22 - i * 0.06), false, 4.0 - i)
	# 门框
	draw_rect(rect, Color(col, 0.15), true)
	draw_rect(rect, col, false, 5.0)
	# 顶部指示灯
	draw_circle(Vector2(0, -55), 6.0, col)

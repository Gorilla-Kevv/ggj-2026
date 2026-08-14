# ============================================================
# LevelDoor — 关卡入口门 (大厅组件)
# 拖入大厅场景，放在章节区域内。玩家触碰 EnterArea 进入对应关卡。
# 依赖 Global 已扩展 (levels_clear / hub_return / current_checkpoint 等)。
#
# 使用：
#   1. 配置 level_id / display_name / chapter_id / target_scene
#   2. level_id 必须与 Global.CHAPTER_LEVELS 中的关卡ID一致 (区分大小写)
#   3. 两种视觉状态，在 Inspector 中把图片拖入插孔：
#      - inactive_texture  未通关时显示的图片
#      - cleared_texture   已通关后显示的图片
#   4. 通关后的门：显示 cleared_texture，且不允许再次进入
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
@export var inactive_texture: Texture2D = null    # 未通关图片
@export var cleared_texture: Texture2D = null     # 已通关图片

# ---------- 子节点引用 ----------
@onready var enter_area: Area2D = $EnterArea
@onready var hint_area: Area2D = $HintArea
@onready var name_label: Label = $NameLabel
@onready var door_sprite: Sprite2D = $Sprite2D

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
	# 依据存档设置初始外貌
	_apply_texture()

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
# 仅在冷却结束、上膛、且未通关的状态下响应；否则视为出生重叠或已通关。
func _on_enter_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _cooldown_left > 0.0:
		return
	if not _armed:
		return
	if target_scene.is_empty():
		return
	var global := get_node("/root/Global")
	# 已通关的关卡不允许再次进入
	if not level_id.is_empty() and global.is_level_clear(level_id):
		return
	_armed = false
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

# 依据通关状态切换贴图：已通关显示 cleared_texture，否则显示 inactive_texture
func _apply_texture() -> void:
	var global := get_node("/root/Global")
	var cleared: bool = not level_id.is_empty() and global.is_level_clear(level_id)
	door_sprite.texture = cleared_texture if cleared else inactive_texture

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
	var text := display_name + " " + level_id
	if not level_id.is_empty() and global.is_level_clear(level_id):
		text += "  ✓已通关"
		name_label.modulate = CLEARED_COLOR
	else:
		name_label.modulate = Color.WHITE
	name_label.text = text
	name_label.show()

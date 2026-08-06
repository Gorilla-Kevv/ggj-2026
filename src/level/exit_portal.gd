# ============================================================
# ExitPortal — 关卡出口 (大厅组件)
# 拖入每个小关卡的终点。玩家触碰 → 标记通关 → 存档 → 返回大厅。
# 返回后玩家会落在进门时的关卡门位置 (Global.hub_return)。
#
# 使用：
#   1. level_id 留空时自动使用 Global.current_level (由关卡门进入时写入)
#   2. hub_scene 留空时使用 Global.HUB_SCENE
#   3. 两种视觉状态，在 Inspector 中把图片拖入插孔：
#      - inactive_texture  未通关时显示的图片
#      - cleared_texture   已通关后显示的图片
#   触碰出口通关后自动切换到 cleared_texture。
# ============================================================
extends Area2D

# ---------- 导出变量 (编辑器配置) ----------
@export var level_id: String = ""                        # 留空=自动读当前关卡
@export var hub_scene: String = ""                       # 留空=Global.HUB_SCENE
@export var inactive_texture: Texture2D = null           # 未通关图片
@export var cleared_texture: Texture2D = null            # 已通关图片

# level_completed: 玩家触发出口时触发 (通关的关卡ID)，可挂音效/VFX/演出
signal level_completed(completed_level_id: String)

@onready var portal_sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	# 初始状态：依据存档判断是否已通关
	var global := get_node("/root/Global")
	var id: String = level_id if not level_id.is_empty() else global.current_level
	_set_state(not id.is_empty() and global.is_level_clear(id))

# 玩家触碰 → 标记通关 → 切到已通关状态 → 回大厅
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var global := get_node("/root/Global")
	var id: String = level_id if not level_id.is_empty() else global.current_level
	if not id.is_empty():
		global.mark_level_clear(id, global.current_chapter)
		_set_state(true)
		level_completed.emit(id)
	# 关卡已结束，清除检查点，避免残留的关卡内坐标污染大厅出生点 (回大厅应落在门边)
	global.current_checkpoint = Vector2.ZERO
	global.last_checkpoint_level = ""
	var scene: String = hub_scene if not hub_scene.is_empty() else global.HUB_SCENE
	if not scene.is_empty():
		get_tree().call_deferred("change_scene_to_file", scene)

# 切换状态贴图：cleared=true 显示已通关图，否则显示未通关图
func _set_state(cleared: bool) -> void:
	portal_sprite.texture = cleared_texture if cleared else inactive_texture

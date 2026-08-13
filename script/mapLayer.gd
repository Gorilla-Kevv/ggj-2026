extends TileMapLayer
@export var default := false

# 非激活层颜色 #2f2c2e (深灰)，激活层恢复白色
const INACTIVE_COLOR := Color(0.18431373, 0.17254902, 0.18039216, 1.0)

func _ready() -> void:
	set_active(default)

func set_active(active: bool) -> void:
	# 只关闭物理碰撞，保留可见性 (非激活层变深灰)
	collision_enabled = active
	# 用 self_modulate 叠加，避免覆盖场景里已设的 modulate 颜色
	self_modulate = Color.WHITE if active else INACTIVE_COLOR
	# 递归处理子 TileMapLayer
	for child in get_children():
		var tile_layer := child as TileMapLayer
		if tile_layer != null:
			tile_layer.collision_enabled = active
			tile_layer.self_modulate = Color.WHITE if active else INACTIVE_COLOR

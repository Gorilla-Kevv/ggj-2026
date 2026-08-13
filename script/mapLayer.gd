extends TileMapLayer
@export var default := false

func _ready() -> void:
	set_active(default)

func set_active(boolean: bool) -> void:
	enabled = boolean
	# 不要在for头部强制写 child: TileMapLayer
	for child in get_children():
		# 安全类型转换，只处理TileMapLayer类型子节点
		var tile_layer := child as TileMapLayer
		if tile_layer != null:
			tile_layer.enabled = boolean

# 挂到 Sprite2D 上，把 SubViewport 的渲染结果当贴图显示
extends Sprite2D

@export var viewport_path: NodePath

func _ready() -> void:
	var vp := get_node_or_null(viewport_path) as SubViewport
	if vp:
		texture = vp.get_texture()

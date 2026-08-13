# 挂到 Sprite2D 上，把 SubViewport 的渲染结果当贴图显示
# 支持占位贴图：编辑状态下 SubViewport 未渲染时显示 placeholder_texture
extends Sprite2D

@export var viewport_path: NodePath
@export var placeholder_texture: Texture2D = null

func _ready() -> void:
	var vp := get_node_or_null(viewport_path) as SubViewport
	if vp:
		texture = vp.get_texture()
	elif placeholder_texture:
		texture = placeholder_texture

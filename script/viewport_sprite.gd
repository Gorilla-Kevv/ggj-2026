# 挂到 Sprite2D 上，把 SubViewport 的渲染结果当贴图显示
# @tool 让脚本在编辑器内也运行，编辑状态显示占位图
@tool
extends Sprite2D

@export var viewport_path: NodePath
@export var placeholder_texture: Texture2D = null

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	# 编辑器下实时响应占位图切换
	if Engine.is_editor_hint():
		_refresh()

func _refresh() -> void:
	if Engine.is_editor_hint():
		# 编辑状态：只显示占位图
		if placeholder_texture:
			texture = placeholder_texture
		return

	# 运行状态：显示 SubViewport 渲染结果
	var vp := get_node_or_null(viewport_path) as SubViewport
	if vp:
		texture = vp.get_texture()
	elif placeholder_texture:
		texture = placeholder_texture

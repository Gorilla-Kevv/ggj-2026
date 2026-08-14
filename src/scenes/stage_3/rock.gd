# ============================================================
# Rock — 可操纵石头 (第3关: 炽风峡谷)
# 受重力/物理影响的可吹动石头 (interactable 组, R 键可切换)。
#   - 飞行时尖锐部分 (精灵朝下的一端) 指向飞行方向；静止/慢速时保持朝下
#   - 平时播放 "default"；被岩柱机关触发后播放一次 "broken" 然后销毁
# ============================================================
extends BaseInteractable
class_name Rock

# ---------- 子节点引用 ----------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# ---------- 物理参数 (与玩家接近的飞行机制) ----------
# ROCK_MAX_SPEED: 石头可达到的最高速度 (px/s)，与玩家手动吹风顶速相当，防止被风吹得过快
const ROCK_MAX_SPEED: float = 350.0

# ---------- 运行时状态 ----------
var _broken: bool = false

func _ready() -> void:
	super._ready()
	# 圆形碰撞体本身稳定：锁体旋转防止物理自旋，尖锐朝向由子精灵旋转实现
	lock_rotation = true

func _physics_process(delta: float) -> void:
	_cap_speed()
	_align_sprite_with_velocity(delta)

# 限速：与玩家一样有最高速度，吹风不会无限加速
func _cap_speed() -> void:
	if linear_velocity.length() > ROCK_MAX_SPEED:
		linear_velocity = linear_velocity.limit_length(ROCK_MAX_SPEED)

# 精灵朝下的一端即"尖锐部分"：把它旋转对齐到运动方向 (静止→朝下)
func _align_sprite_with_velocity(delta: float) -> void:
	if animated_sprite == null or _broken:
		return
	var vel := linear_velocity
	var speed := vel.length()
	var target: float
	if speed < 30.0:
		target = 0.0   # 静止/慢速: 尖锐部分朝下
	else:
		target = atan2(vel.x, vel.y)  # 本地朝下 (0,1) 旋转 r 后为 (sin r, cos r)，令其等于速度方向
	animated_sprite.rotation = lerp_angle(animated_sprite.rotation, target, minf(1.0, delta * 10.0))

# 被岩柱机关触发: 播放一次 broken 动画后销毁
func break_rock() -> void:
	if _broken:
		return
	_broken = true
	# 立即从 interactable 组移除，防止 _refresh_targets 重新加入
	remove_from_group("interactable")
	# 若当前选中的是本石头，清空引用，让目标选择器刷新后自动切回玩家
	var global := get_node_or_null("/root/Global")
	if global and global.selected_target == self:
		global.selected_target = null
	get_tree().call_group("target_selector", "_refresh_targets")
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("broken"):
		animated_sprite.animation = "broken"
		animated_sprite.frame = 0
		animated_sprite.speed_scale = 1.0
		animated_sprite.play()
		if not animated_sprite.animation_finished.is_connected(_on_broken_finished):
			animated_sprite.animation_finished.connect(_on_broken_finished)
		return
	queue_free()

func _on_broken_finished() -> void:
	queue_free()

# ============================================================
# FireTongue — 火舌喷射器 (第3关: 炽风峡谷)
# 周期性向"前方"喷射火舌，碰到即死。
#   周期: 每 interval 秒喷一次，每次持续 active_duration
#   判定: 前方一个长条矩形区域 (HitArea)，只检测玩家
#   朝向: 默认朝右 (+X)，整个节点旋转可改变喷射方向
# 动画: 只在喷射有效期内播放/显示火舌，非有效期间隐藏 (AnimatedSprite2D 占位，可替换)
# ============================================================
extends Node2D
class_name FireTongue

# ---------- 导出变量 (编辑器可调) ----------
@export var interval: float = 2.4        # 两次喷射的间隔 (秒)
@export var active_duration: float = 5.0 # 单次喷射持续时长 (秒)
@export var never_extinguish: bool = false  # 永不熄灭 (一进场景就持续喷火，直到被删除)

# ---------- 子节点引用 ----------
@onready var hit_area: Area2D = $HitArea
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# ---------- 运行时状态 ----------
var _fire_timer: float = 0.0
var _active_timer: float = 0.0
var _is_firing: bool = false

func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	animated_sprite.visible = false
	if never_extinguish:
		# 永不熄灭: 初始即开启判定区 + 显示并播放火舌
		hit_area.monitoring = true
		animated_sprite.visible = true
		_play_fire_anim()
	else:
		hit_area.monitoring = false

# 周期循环: 待机倒计时 → 喷射 → 待机
func _physics_process(delta: float) -> void:
	if never_extinguish:
		_check_overlap()   # 永不熄灭: 只做重叠兜底判死
		return
	if _is_firing:
		_active_timer -= delta
		if _active_timer <= 0.0:
			_end_fire()
		else:
			_check_overlap()   # 已站在火焰中也要判死
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_start_fire()

# 开始喷射: 开启判定区 + 显示并播放火舌动画 (fire 优先，default 兜底)
func _start_fire() -> void:
	_is_firing = true
	_active_timer = active_duration
	hit_area.monitoring = true
	animated_sprite.visible = true
	_play_fire_anim()

# 结束喷射: 关闭判定区 + 隐藏火舌
func _end_fire() -> void:
	_is_firing = false
	_fire_timer = interval
	hit_area.monitoring = false
	animated_sprite.visible = false
	animated_sprite.stop()

# 覆盖进入判定区的玩家 (喷射期间每帧兜底重叠检测)
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.die()

func _check_overlap() -> void:
	for body in hit_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			body.die()
			return

# ---------- 动画 ----------
# 播放火舌动画: fire 优先，其次 default (兼容用户自定义的默认动画名)
func _play_fire_anim() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = animated_sprite.sprite_frames
	var anim: String = "fire" if frames.has_animation("fire") else ("default" if frames.has_animation("default") else "")
	if anim.is_empty():
		return
	animated_sprite.play(anim)

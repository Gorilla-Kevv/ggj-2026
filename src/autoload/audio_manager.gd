# ============================================================
# AudioManager — 全局音乐/音效播放器 (Autoload)
# 通过 /root/AudioManager 访问，所有场景通用
# 场景切换时音乐持续播放，音效即时触发
#
# 用法:
#   AudioManager.play_music("res://assets/music/level1.ogg")
#   AudioManager.play_sfx("res://assets/temp/sounds/hurt.wav")
#   AudioManager.stop_music()
# ============================================================
extends Node

# ---------- 导出参数 ----------
@export var music_volume_db: float = -10.0    # 音乐音量 (分贝)
@export var sfx_volume_db: float = -6.0       # 音效音量 (分贝)
@export var default_fade_time: float = 1.0    # 默认淡入淡出时长 (秒)

# ---------- 节点引用 ----------
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var _current_music_path: String = ""
var _loop_start: float = 0.0      # 循环起点（秒），0=从头循环
var _loop_end: float = -1.0       # 循环结束点（秒），-1=播到结尾
var _loop_active: bool = false    # 是否启用自定义循环点

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 场景切换时不被暂停

	# 音乐播放器
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = music_volume_db
	add_child(music_player)

	# 音效播放器池 (预创建 8 个，支持重叠播放)
	for i in range(8):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.volume_db = sfx_volume_db
		add_child(p)
		sfx_players.append(p)

	# 监听场景切换，自动播放对应关卡 BGM (不依赖 stage 场景挂脚本)
	get_tree().scene_changed.connect(_on_scene_changed)
	# 当前已加载的场景也触发一次
	call_deferred("_on_scene_changed", get_tree().current_scene)

# 场景切换时根据场景路径自动播放 BGM
func _on_scene_changed(scene: Node) -> void:
	if scene == null:
		return
	refresh_current_stage_music()

# 根据当前场景刷新 BGM (玩家重生/场景重载后调用)
func refresh_current_stage_music() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path := scene.scene_file_path
	if path.contains("stage_1"):
		play_stage_music(1)
	elif path.contains("stage_2"):
		play_stage_music(2)
	elif path.contains("stage_3"):
		play_stage_music(3)
	# stage_5 (Boss 关) 由 BossIntro 触发音乐，这里不处理

func _process(_delta: float) -> void:
	# 自定义循环点：播放到 loop_end 时跳回 loop_start
	if _loop_active and music_player != null and music_player.playing and music_player.stream != null:
		var end := _loop_end if _loop_end >= 0.0 else music_player.stream.get_length()
		var pos := music_player.get_playback_position()
		if end > 0.0 and pos >= end - 0.05:
			music_player.seek(_loop_start)

# ---------- 预设 BGM 便捷方法 ----------
# 各关卡和 Boss 战的音乐路径 (可在此统一维护)

const BGM_STAGE_1 := "res://assets/music/stage_1.mp3"
const BGM_STAGE_2 := "res://assets/music/stage_2.mp3"
const BGM_STAGE_3 := "res://assets/music/stage_3.mp3"
const BGM_BOSS_FIGHT := "res://assets/music/Boss Fight.mp3"
const BGM_BOSS_DEAD := "res://assets/music/Boss Dead.mp3"

# ---------- 音效路径常量 ----------
const SFX_SELECT := "res://assets/fx/select.wav"
const SFX_ENERGY_OUT := "res://assets/fx/run out of energy.wav"
const SFX_FLY := "res://assets/fx/fly.wav"
const SFX_FIND_PLAYER := "res://assets/fx/find the player.wav"
const SFX_DEAD := "res://assets/fx/dead.wav"
const SFX_DEAD_2 := "res://assets/fx/dead_2.wav"
const SFX_CHECKPOINT := "res://assets/fx/checkpoint.wav"

func play_stage_music(stage: int) -> void:
	match stage:
		1: play_music_looped(BGM_STAGE_1, 0.54, 18.0)
		2: play_music_looped(BGM_STAGE_2, 0.54, 105.27)
		3: play_music_looped(BGM_STAGE_3, 0.5, 120.5)
		_: play_music("")

func play_boss_fight_music() -> void:
	play_music_looped(BGM_BOSS_FIGHT, 3.2, 60.8)   # 从 60.8 秒循环回 3.2 秒

func play_boss_dead_music() -> void:
	play_music(BGM_BOSS_DEAD, 0.5)   # Boss 死亡音乐快速淡入

# ---------- 音乐控制 ----------

# 播放音乐 (path 为空则停止)
func play_music(path: String, fade_time: float = -1.0) -> void:
	_loop_active = false
	_loop_start = 0.0
	_loop_end = -1.0
	_play_music_internal(path, fade_time)

# 播放音乐并设置循环区间 (播放到 loop_end 秒跳回 loop_start 秒)
func play_music_looped(path: String, loop_start: float, loop_end: float = -1.0, fade_time: float = -1.0) -> void:
	_loop_active = true
	_loop_start = loop_start
	_loop_end = loop_end
	_play_music_internal(path, fade_time)

# 强制重播当前关卡 BGM (玩家重生用，绕过"同路径跳过"检查)
func replay_current_music() -> void:
	if _current_music_path == "":
		refresh_current_stage_music()
		return
	_play_music_internal(_current_music_path, 0.3, true)

func _play_music_internal(path: String, fade_time: float, force: bool = false) -> void:
	if path == _current_music_path and not force:
		return
	_current_music_path = path
	var t := default_fade_time if fade_time < 0.0 else fade_time

	if path == "":
		_stop_music_fade(t)
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: 无法加载音乐 " + path)
		return
	_crossfade_to(stream, t)

# 停止音乐 (带淡出)
func stop_music(fade_time: float = -1.0) -> void:
	var t := default_fade_time if fade_time < 0.0 else fade_time
	_stop_music_fade(t)

# 暂停/恢复音乐
func pause_music() -> void:
	music_player.stream_paused = true

func resume_music() -> void:
	music_player.stream_paused = false

# ---------- 音效控制 ----------

# 播放音效 (可指定音量和音调)
func play_sfx(path: String, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	var player := _get_free_sfx_player()
	if player == null:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: 无法加载音效 " + path)
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

# ---------- 预设音效便捷方法 ----------

func sfx_select() -> void:
	play_sfx(SFX_SELECT, -8.0)

func sfx_energy_out() -> void:
	play_sfx(SFX_ENERGY_OUT, -4.0)

func sfx_fly() -> void:
	play_sfx(SFX_FLY, -6.0)

func sfx_find_player() -> void:
	play_sfx(SFX_FIND_PLAYER, -4.0)

func sfx_player_dead() -> void:
	play_sfx(SFX_DEAD, -2.0)

func sfx_boss_dead() -> void:
	play_sfx(SFX_DEAD_2, -2.0)

func sfx_checkpoint() -> void:
	play_sfx(SFX_CHECKPOINT, -4.0)

# ---------- 内部实现 ----------

func _crossfade_to(stream: AudioStream, fade_time: float) -> void:
	if fade_time <= 0.0:
		music_player.stop()
		music_player.stream = stream
		music_player.play()
		return
	# 淡出当前 → 切换 → 淡入
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -60.0, fade_time)
	tween.tween_callback(func():
		music_player.stop()
		music_player.stream = stream
		music_player.play()
		music_player.volume_db = -60.0
	)
	tween.tween_property(music_player, "volume_db", music_volume_db, fade_time)

func _stop_music_fade(fade_time: float) -> void:
	if fade_time <= 0.0:
		music_player.stop()
		_current_music_path = ""
		return
	var tween := create_tween()
	tween.tween_property(music_player, "volume_db", -60.0, fade_time)
	tween.tween_callback(func():
		music_player.stop()
		_current_music_path = ""
	)

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	return sfx_players[0]   # 全部占用时复用第一个

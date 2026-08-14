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
var _tracked_scene: Node = null         # 已跟踪的场景实例 (用于检测切换/重载)
var _loop_start: float = 0.0      # 循环起点（秒），0=从头循环
var _loop_end: float = -1.0       # 循环结束点（秒），-1=播到结尾
var _loop_active: bool = false    # 是否启用自定义循环点

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 场景切换时不被暂停

	_load_settings()

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

# 从 Settings 读取音量，并监听变化即时生效
func _load_settings() -> void:
	var s := get_node("/root/Settings")
	music_volume_db = s.music_volume_db
	sfx_volume_db = s.sfx_volume_db
	if not s.setting_changed.is_connected(_on_setting_changed):
		s.setting_changed.connect(_on_setting_changed)

func _on_setting_changed(key: String, value: float) -> void:
	match key:
		"music_volume_db":
			music_volume_db = value
			if music_player:
				music_player.volume_db = value
		"sfx_volume_db":
			sfx_volume_db = value
			for p in sfx_players:
				p.volume_db = value

# 每帧轮询场景实例变化 (scene_changed 信号在部分切换路径下不可靠，故不依赖它)
func _poll_scene_change() -> void:
	var scene := get_tree().current_scene
	if scene == _tracked_scene:
		return
	# 场景实例变化了：切换新关卡 或 死亡重载
	var previous_path := ""
	if _tracked_scene != null:
		previous_path = _tracked_scene.scene_file_path
	_tracked_scene = scene
	if scene == null:
		return
	var is_reload := (scene.scene_file_path == previous_path)
	refresh_current_stage_music(is_reload)
	print("[AudioManager] 场景变化: ", scene.scene_file_path, " 重载=", is_reload)

# 根据当前场景刷新 BGM (玩家重生/场景重载后调用)
# force: 强制重播当前音乐 (用于死亡重载，绕过"同路径跳过"检查)
func refresh_current_stage_music(force: bool = false) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		print("[AudioManager] refresh: current_scene 为 null")
		return
	var path := scene.scene_file_path
	print("[AudioManager] refresh: 场景路径=", path, " force=", force)
	if path.contains("stage_1"):
		play_stage_music(1, force)
	elif path.contains("stage_2"):
		play_stage_music(2, force)
	elif path.contains("stage_3"):
		play_stage_music(3, force)
	else:
		# 非关卡场景 (hub 等)：停止当前关卡音乐
		if _current_music_path != "":
			print("[AudioManager] 非关卡场景，停止音乐")
			play_music("")
	# stage_5 (Boss 关) 由 BossIntro 触发音乐，这里不处理

func _process(_delta: float) -> void:
	_poll_scene_change()

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

func play_stage_music(stage: int, force: bool = false) -> void:
	match stage:
		1: play_music_looped(BGM_STAGE_1, 0.54, 18.0, -1.0, force)
		2: play_music_looped(BGM_STAGE_2, 0.54, 105.27, -1.0, force)
		3: play_music_looped(BGM_STAGE_3, 0.5, 120.5, -1.0, force)
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
func play_music_looped(path: String, loop_start: float, loop_end: float = -1.0, fade_time: float = -1.0, force: bool = false) -> void:
	_loop_active = true
	_loop_start = loop_start
	_loop_end = loop_end
	_play_music_internal(path, fade_time, force)

# 强制重播当前关卡 BGM (玩家重生用，绕过"同路径跳过"检查)
func replay_current_music() -> void:
	if _current_music_path == "":
		refresh_current_stage_music()
		return
	_play_music_internal(_current_music_path, 0.3, true)

func _play_music_internal(path: String, fade_time: float, force: bool = false) -> void:
	print("[AudioManager] _play_music_internal path=", path, " 当前=", _current_music_path, " force=", force)
	if path == _current_music_path and not force:
		print("[AudioManager] 同曲跳过")
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
	print("[AudioManager] 开始播放 ", path, " fade=", t)
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
	# 5% 概率触发飞行音效，避免频繁吹风时音效过于嘈杂
	if randf() > 0.01:
		return
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
	# 首次播放 (当前无曲目) 直接开始，避免多余的淡出静音
	if fade_time <= 0.0 or music_player.stream == null:
		music_player.stop()
		music_player.stream = stream
		music_player.volume_db = music_volume_db
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

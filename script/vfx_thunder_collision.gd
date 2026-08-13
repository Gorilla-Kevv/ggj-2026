extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var kill_zone_2: Area2D = $"../KillZone2"
@onready var kill_zone: Area2D = $KillZone

func _ready() -> void:
	if not kill_zone_2.body_entered.is_connected(_on_body_entered):
		kill_zone_2.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("interactable"):
		return

	# 关闭 KillZone（玩家死亡区）的监测
	kill_zone.set_deferred("monitoring", false)
	animation_player.play("temp/end_animation_custom")

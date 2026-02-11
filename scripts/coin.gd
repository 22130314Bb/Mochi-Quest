extends Area2D

var coins := 1
@onready var coin_sfx: AudioStreamPlayer = $coin_sfx as AudioStreamPlayer

func _on_body_entered(_body: Node2D) -> void:
	$anim.play("collect")
	coin_sfx.play()
	await  $collision.call_deferred("queue_free")
	Globals.coins += coins

func _on_anim_animation_finished() -> void:
	queue_free()

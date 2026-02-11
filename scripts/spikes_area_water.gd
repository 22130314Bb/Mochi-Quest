extends Area2D

@onready var collision = $collision as CollisionShape2D
@onready var spikes = $spikes as Sprite2D

func _ready() -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	if body.name == "player" && body.has_method("take_damage"):
		body.take_damage(Vector2(0, -250))

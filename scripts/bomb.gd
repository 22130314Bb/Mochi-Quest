extends RigidBody2D

const EXPLOSION = preload("res://prefabs/explosion.tscn")

func _on_body_entered(_body):

	var explosion_instance = EXPLOSION.instantiate()
	get_parent().add_child(explosion_instance)
	explosion_instance.global_position = global_position
	

	explosion_instance.play("default") 
	

	queue_free()

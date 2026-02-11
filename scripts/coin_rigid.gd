extends RigidBody2D

func _on_coin_tree_exiting() -> void:
	queue_free()

extends AnimatableBody2D

const SPEED := 100.0
const EXPLOSION = preload("res://prefabs/explosion.tscn")

@onready var sprite: Sprite2D = $sprite
var direction := -1

func _ready():
	set_direction(direction)


func _physics_process(delta):

	var velocity_vector = Vector2(SPEED * direction * delta, 0)

	var collision = move_and_collide(velocity_vector)
	

	if collision:
		explode()

func set_direction(dir):
	direction = dir
	
	sprite.flip_h = (direction == 1)

func explode():

	var explosion_instance = EXPLOSION.instantiate()
	get_parent().add_child(explosion_instance)
	explosion_instance.global_position = global_position
	
	
	explosion_instance.play("default")
	
	
	queue_free()

func _on_collision_detection_body_entered(_body):
	explode()

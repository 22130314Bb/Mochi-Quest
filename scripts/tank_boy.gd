extends CharacterBody2D

const SPEED = 5000.0
var direction = -1
@onready var wall_detector = $wall_detector
@onready var sprite = $sprite


func _physics_process(delta):
	
	if wall_detector.is_colliding():
		direction *= -1
		wall_detector.scale.x *= -1
	
	
	if direction == 1:
		velocity.x =  SPEED * delta
		sprite.flip_h = true
	else:
		velocity.x = -SPEED * delta
		sprite.flip_h = false
		
	move_and_slide()

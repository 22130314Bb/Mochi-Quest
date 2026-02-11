extends CharacterBody2D

# --- CONFIGURAÇÕES ---
const SPEED = 150.0
const AIR_FRICTION := 0.8
const COIN_SCENE := preload("res://prefabs/coin_rigid.tscn")

var is_jumping := false
var can_jump := true
var is_hurted := false
var is_invincible := false
var knockback_vector := Vector2.ZERO
var knockback_power := 400.0
var direction := 0.0

# --- PULO E GRAVIDADE ---
@export var jump_height := 50
@export var max_time_to_peak := 0.5
var jump_velocity : float
var gravity : float
var fall_gravity : float

# --- NATAÇÃO ---
var is_swimming := false 
@export var water_gravity_multiplier := 0.4  
@export var water_jump_power := -130.0       
@export var water_speed_multiplier := 0.7    
@export var terminal_velocity_water := 80.0  

# --- NÓS ---
@onready var animation := $anim as AnimatedSprite2D
@onready var remote_transform := $remote as RemoteTransform2D
@onready var coyote_timer := $coyote_timer as Timer
@onready var jump_sfx := $jump_sfx as AudioStreamPlayer
@onready var destroy_sfx = preload("res://sounds/destroy_sfx.tscn")

signal player_has_died()

func _ready() -> void:
	add_to_group("player")
	
	# 1. Reset inicial: assume que está no chão por segurança
	is_swimming = false 
	is_hurted = false
	is_invincible = false
	velocity = Vector2.ZERO
	
	jump_velocity = (jump_height * 2) / max_time_to_peak
	gravity = (jump_height * 2) / pow(max_time_to_peak, 2)
	fall_gravity = gravity * 2

	# 2. O PULO DO GATO: Checagem instantânea de nado no nascimento
	# Esperamos um frame pequeno para a física detectar áreas sobrepostas
	await get_tree().process_frame
	_check_initial_water_overlap()

func _check_initial_water_overlap() -> void:
	# Criamos uma checagem manual para ver se o player "nasceu" dentro de uma Area2D de água
	# Para isso funcionar, sua Água deve estar numa Collision Layer que o Player detecte.
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = global_position
	query.collision_mask = 16 # COLOQUE AQUI A LAYER DA SUA ÁGUA (Ex: se a água for layer 5, use 16)
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	if results.size() > 0:
		is_swimming = true
		animation.play("swing")

func _physics_process(delta: float) -> void:
	# 1. GRAVIDADE
	if not is_on_floor():
		if is_swimming:
			velocity.y += (gravity * water_gravity_multiplier) * delta
			velocity.y = min(velocity.y, terminal_velocity_water)
		elif velocity.y > 0 or not Input.is_action_pressed("Jump"):
			velocity.y += fall_gravity * delta
		else:
			velocity.y += gravity * delta
	else:
		if is_jumping: 
			_apply_squash_and_stretch(1.7, 0.5)
			is_jumping = false
		can_jump = true
	
	# 2. PULO E NATAÇÃO
	if Input.is_action_just_pressed("Jump"):
		if is_swimming:
			velocity.y = water_jump_power
		elif can_jump:
			velocity.y = -jump_velocity
			is_jumping = true
			_apply_squash_and_stretch(0.4, 1.8)
			jump_sfx.play()
	
	if not is_on_floor() and can_jump and coyote_timer.is_stopped():
		coyote_timer.start()

	# 3. MOVIMENTAÇÃO HORIZONTAL
	direction = Input.get_axis("Left", "Right")
	
	if is_hurted:
		velocity.x = knockback_vector.x
	else:
		var current_max_speed = SPEED
		if is_swimming:
			current_max_speed = SPEED * water_speed_multiplier
			
		if direction != 0:
			velocity.x = lerp(velocity.x, direction * current_max_speed, AIR_FRICTION)
			animation.scale.x = direction 
		else:
			velocity.x = move_toward(velocity.x, 0, current_max_speed)

	move_and_slide()
	_set_state()
	_update_camera_dynamic()
	
	animation.scale.x = lerp(animation.scale.x, sign(animation.scale.x) * 1.0, 0.15)
	animation.scale.y = lerp(animation.scale.y, 1.0, 0.15)
	_check_platform_collisions()

# --- SINAIS DA ÁGUA (Mantenha-os conectados na Area2D da Água) ---
func _on_water_area_body_entered(body):
	if body == self:
		is_swimming = true

func _on_water_area_body_exited(body):
	if body == self:
		is_swimming = false
		if Input.is_action_pressed("Jump") or velocity.y < 0:
			velocity.y = -jump_velocity * 0.6

# --- SISTEMA DE DANO ---
func _on_hurtbox_body_entered(body: Node2D) -> void:
	if is_invincible or is_hurted: return
	var knock_dir = 1 if global_position.x < body.global_position.x else -1
	take_damage(Vector2(-knock_dir * knockback_power, -200))

func take_damage(knockback_force := Vector2.ZERO, duration := 0.25):
	if is_hurted or is_invincible: return
	if Globals.player_life > 0:
		Globals.player_life -= 1
		_start_hurt_sequence(knockback_force, duration)
	else:
		_die()

func _start_hurt_sequence(knockback_force, duration):
	is_hurted = true
	is_invincible = true
	if knockback_force != Vector2.ZERO:
		knockback_vector = knockback_force
		var tween = get_tree().create_tween()
		tween.parallel().tween_property(self, "knockback_vector", Vector2.ZERO, duration)
		var flicker = get_tree().create_tween().set_loops(10)
		flicker.tween_property(animation, "modulate:a", 0.0, 0.1)
		flicker.tween_property(animation, "modulate:a", 1.0, 0.1)
	
	lose_coins()
	await get_tree().create_timer(duration).timeout
	is_hurted = false
	await get_tree().create_timer(1.0).timeout
	is_invincible = false

# --- ESTADOS ---
func _set_state():
	var state = "idle"
	if is_swimming:
		state = "swing" 
	elif not is_on_floor():
		state = "jump"
	elif direction != 0:
		state = "run"
	if is_hurted: state = "hurt"
	if animation.animation != state: animation.play(state)

func _die():
	set_physics_process(false) 
	emit_signal("player_has_died")
	Globals.respawn_player() 
	queue_free()

func follow_camera(camera):
	if remote_transform and camera:
		remote_transform.remote_path = camera.get_path()

func _update_camera_dynamic():
	var camera = get_viewport().get_camera_2d()
	if camera:
		if velocity.y < -50:
			camera.drag_vertical_offset = lerp(camera.drag_vertical_offset, -0.4, 0.1)
		else:
			camera.drag_vertical_offset = lerp(camera.drag_vertical_offset, 0.0, 0.1)

func _apply_squash_and_stretch(x_factor: float, y_factor: float):
	var current_dir = sign(animation.scale.x)
	if current_dir == 0: current_dir = 1
	animation.scale = Vector2(x_factor * current_dir, y_factor)

func lose_coins():
	var lost_coins: int = min(Globals.coins, 5)
	Globals.coins -= lost_coins
	for i in lost_coins:
		var coin = COIN_SCENE.instantiate()
		get_parent().call_deferred("add_child", coin)
		coin.global_position = global_position
		coin.apply_impulse(Vector2(randi_range(-150, 150), -300))

func _check_platform_collisions():
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider().has_method("has_collided_with"):
			col.get_collider().has_collided_with(col, self)

func _on_head_collider_body_entered(body: Node2D) -> void:
	if body.has_method("break_sprite"):
		body.hitpoints -= 1
		if body.hitpoints < 0:
			body.break_sprite()
			var sfx = destroy_sfx.instantiate()
			get_parent().add_child(sfx)
		else:
			body.animation_player.play("hit_flash")
			body.create_coin()

func _on_coyote_timer_timeout():
	can_jump = false

func handle_death_zone():
	_die()



	   

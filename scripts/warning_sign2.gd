extends Node2D

@export var custom_font: FontFile 
@export var font_size: int = 32 

@onready var texture: Sprite2D = $texture
@onready var area_sign: Area2D = $area_sign
@onready var type_sfx: AudioStreamPlayer = $type_sfx if has_node("type_sfx") else null

const lines: Array[String] = [
	"Viajante... [wait] espere um pouco.",
	"Sente este ar? [wait] Está frio... e [color=#aaaaaa]insosso[/color].",
	"O Mochi World já foi macio e doce, mas agora...",
	"O tirano [shake rate=30 level=10][color=#ff3333]Mr. Ednaldo[/color][/shake] roubou nossa essência.",
	"Sem a [color=#00ff00]Essência de Nori[/color], tudo vai ressecar.",
	"Por favor... [wait] nos ajude!"
]

var is_playing_cutscene: bool = false
var skip_requested: bool = false 

func _process(_delta: float) -> void:
	if is_playing_cutscene: return

	if area_sign.get_overlapping_bodies().size() > 0:
		texture.show()
		if Input.is_action_just_pressed("interact"):
			start_cinematic_story()
	else:
		texture.hide()

func _input(event: InputEvent) -> void:

	if is_playing_cutscene and not skip_requested:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			skip_requested = true

func start_cinematic_story() -> void:
	is_playing_cutscene = true
	skip_requested = false 
	texture.hide()
	
	var player = get_tree().get_first_node_in_group("player")
	var camera = get_viewport().get_camera_2d()
	var screen_size = get_viewport_rect().size
	
	if player: 
		player.set_physics_process(false)
		if player.has_node("anim"): player.get_node("anim").play("idle")
	
	if camera:
		var cam_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(camera, "zoom", Vector2(3.2, 3.2), 1.0)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	get_tree().root.add_child(canvas)

	# 1. Cria o Fundo Preto
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	
	var center_cont = CenterContainer.new()
	center_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center_cont)

	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(screen_size.x * 0.7, 0)
	
	if custom_font:
		label.add_theme_font_override("normal_font", custom_font)
		label.add_theme_font_override("bold_font", custom_font)
		label.add_theme_font_override("italics_font", custom_font)
	
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("bold_font_size", font_size)
	label.add_theme_font_size_override("italics_font_size", font_size)
	
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_color_override("default_color", Color.WHITE)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 0)
	
	center_cont.add_child(label)


	var skip_label = Label.new()
	skip_label.text = "Pressione ENTER ou CLIQUE para pular"
	skip_label.modulate = Color(1, 1, 1, 0.9) 
	
	if custom_font: 
		skip_label.add_theme_font_override("font", custom_font)
		skip_label.add_theme_font_size_override("font_size", 16) 
	

	skip_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	skip_label.position = Vector2(40, screen_size.y - 60) 
	canvas.add_child(skip_label)


	for line in lines:
	
		if skip_requested: break 
		
		var clean_line = line.replace("[wait]", "")
		label.text = "[center]" + clean_line + "[/center]"
		label.visible_ratio = 0.0
		label.modulate.a = 1.0
		
		if "Mr. Ednaldo" in line:
			if camera: _shake_camera(camera)
			var flash = create_tween()
			flash.tween_property(bg, "color", Color(0.5, 0, 0, 0.7), 0.1)
			flash.tween_property(bg, "color", Color(0, 0, 0, 0.7), 0.5)

		var parts = line.split("[wait]")
		var total_char_count = float(clean_line.length())
		var current_char_count = 0.0
		
		for i in range(parts.size()):
			if skip_requested: break 
			
			var part = parts[i]
			current_char_count += part.length()
			
			var target_ratio = current_char_count / total_char_count
			if i == parts.size() - 1: target_ratio = 1.0
			
			var duration = part.length() * 0.05 
			
			var t = create_tween()
			t.tween_property(label, "visible_ratio", target_ratio, duration)
			
			_play_sfx(duration)
			
			
			await _wait_or_skip(t, duration) 
			
			if skip_requested: 
				t.kill()
				break

			if i < parts.size() - 1:
				await _wait_or_skip(null, 0.8) 
		
		if not skip_requested:
			await _wait_or_skip(null, 1.5) 
			var fade_out = create_tween()
			fade_out.tween_property(label, "modulate:a", 0.0, 0.3)
			await fade_out.finished

	
	if camera:
		var cam_tween_out = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		cam_tween_out.tween_property(camera, "zoom", Vector2(1.6, 1.6), 0.8)

	canvas.queue_free()
	is_playing_cutscene = false
	if player: player.set_physics_process(true)



func _wait_or_skip(tween_ref: Tween, time: float) -> void:
	var timer = 0.0
	while timer < time:
		if skip_requested:
			if tween_ref and tween_ref.is_valid():
				tween_ref.kill()
			return
		
		await get_tree().process_frame
		timer += get_process_delta_time()

func _play_sfx(dur: float):
	if not type_sfx: return
	var elapsed = 0.0
	while elapsed < dur:
		if skip_requested: return 
		
		type_sfx.pitch_scale = randf_range(0.9, 1.1)
		type_sfx.play()
		var wait_time = randf_range(0.08, 0.1)
		await get_tree().create_timer(wait_time).timeout
		elapsed += wait_time

func _shake_camera(camera: Camera2D):
	var shake = create_tween()
	for i in 10:
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		shake.tween_property(camera, "offset", offset, 0.05)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.1)

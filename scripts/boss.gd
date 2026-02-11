extends Node2D

@onready var type_sfx: AudioStreamPlayer = $type_sfx if has_node("type_sfx") else null

@export var custom_font: FontFile 
@export var font_size: int = 32 

const BAR_HEIGHT_PERCENT = 0.15 
const ZOOM_TALK = Vector2(4.6, 4.6)
const ZOOM_OUT = Vector2(3.0, 3.0) 

const lines: Array[String] = [
	"Você caiu fundo demais, pequeno [color=#00ffff]Pingu[/color]...",
	"Ouça o som do metal rangendo nas sombras.",
	"Este é o domínio do [b][color=#ff3333][wave amp=80 freq=5][outline_size=0]TANKBOY[/outline_size][/wave][/color][/b]!",
	"Ele foi corrompido para [shake rate=80 level=20]ESMAGAR[/shake] você.",
	"Prepare-se... [wait] o aço vai colidir!",
	"Cuidado..."
]

var is_playing_cutscene: bool = false
var skip_requested: bool = false 

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not is_playing_cutscene and body.is_in_group("player"):
		start_boss_cinematic(body)

func _input(event: InputEvent) -> void:

	if is_playing_cutscene and not skip_requested:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			skip_requested = true

func start_boss_cinematic(player: CharacterBody2D) -> void:
	is_playing_cutscene = true
	skip_requested = false 
	
	var camera = get_viewport().get_camera_2d()
	var screen_size = get_viewport_rect().size
	
	if player: 
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		if player.has_node("anim"): player.get_node("anim").play("idle")

	var canvas = CanvasLayer.new()
	canvas.layer = 128
	get_tree().root.add_child(canvas)
	

	
	var vignette = TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.texture = _create_fancy_vignette()
	vignette.modulate.a = 0
	canvas.add_child(vignette)

	var bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_top.custom_minimum_size.y = 0
	canvas.add_child(bar_top)

	var bar_bottom = ColorRect.new()
	bar_bottom.color = Color.BLACK
	bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar_bottom.custom_minimum_size.y = 0
	canvas.add_child(bar_bottom)

	var margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 80)
	margin_container.add_theme_constant_override("margin_right", 80)
	canvas.add_child(margin_container)

	var center_container = CenterContainer.new()
	margin_container.add_child(center_container)

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
	
	center_container.add_child(label)


	var skip_label = Label.new()
	skip_label.text = "Pressione ENTER ou CLIQUE para pular"
	skip_label.modulate = Color(1, 1, 1, 0.6)
	if custom_font: 
		skip_label.add_theme_font_override("font", custom_font)
		skip_label.add_theme_font_size_override("font_size", 16)
	
	skip_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	skip_label.position = Vector2(40, screen_size.y - 60)
	canvas.add_child(skip_label)
	
	var intro_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var target_bar_h = screen_size.y * BAR_HEIGHT_PERCENT
	
	intro_tween.tween_property(bar_top, "custom_minimum_size:y", target_bar_h, 1.5)
	intro_tween.tween_property(bar_bottom, "custom_minimum_size:y", target_bar_h, 1.5)
	intro_tween.tween_property(vignette, "modulate:a", 1.0, 2.0)
	
	if camera:
		intro_tween.tween_property(camera, "zoom", ZOOM_TALK, 2.0)


	await _wait_or_skip(intro_tween, 1.5)

	
	for line in lines:
		if skip_requested: break
		
		var clean_line = line.replace("[wait]", "")
		label.text = "[center]" + clean_line + "[/center]"
		label.visible_ratio = 0.0
		label.modulate.a = 1.0
		
		if "TANKBOY" in line:
			_apply_impact(camera, vignette)

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
			await _wait_or_skip(null, 1.8)
			var fade_text = create_tween()
			fade_text.tween_property(label, "modulate:a", 0.0, 0.4)
			await _wait_or_skip(fade_text, 0.4)


	var final_zoom_dur = 2.0 if not skip_requested else 0.5
	var bars_out_dur = 0.8 if not skip_requested else 0.2

	var zoom_tween: Tween
	if camera:
		zoom_tween = create_tween().set_trans(Tween.TRANS_SINE)
		
		zoom_tween.tween_property(camera, "zoom", ZOOM_OUT, final_zoom_dur)
	
	var outro = create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	outro.tween_property(bar_top, "custom_minimum_size:y", 0, bars_out_dur)
	outro.tween_property(bar_bottom, "custom_minimum_size:y", 0, bars_out_dur)
	outro.tween_property(vignette, "modulate:a", 0.0, bars_out_dur)
	
	await outro.finished
	canvas.queue_free()
	
	if zoom_tween and zoom_tween.is_valid() and zoom_tween.is_running():
		await zoom_tween.finished

	if player: player.set_physics_process(true)
	is_playing_cutscene = false
	queue_free()


func _wait_or_skip(tween_ref: Tween, time: float) -> void:
	var timer = 0.0
	while timer < time:
		if skip_requested:
			if tween_ref and tween_ref.is_valid():
				tween_ref.kill()
			return
		
		await get_tree().process_frame
		timer += get_process_delta_time()

func _create_fancy_vignette() -> GradientTexture2D:
	var g = Gradient.new()
	g.offsets = [0.1, 0.6, 1.0]
	g.colors = [Color(0,0,0,0), Color(0,0,0,0.4), Color(0,0,0,0.9)]
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	return tex

func _apply_impact(cam, overlay):
	if skip_requested: return 
	
	var shake_tween = create_tween()
	for i in 20:
		var intensity = 15 - (i * 0.5)
		var rand_pos = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(cam, "offset", rand_pos, 0.04)
	shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.1)
	
	var flash = create_tween()
	flash.tween_property(overlay, "modulate", Color(4, 0.5, 0.5, 1), 0.1)
	flash.tween_property(overlay, "modulate", Color(1, 1, 1, 1), 0.5)

func _play_sfx(dur):
	var elapsed = 0.0
	while elapsed < dur:
		if skip_requested: return 
		
		if type_sfx:
			type_sfx.pitch_scale = randf_range(0.8, 1.2)
			type_sfx.play()
		var wait = randf_range(0.08, 0.12)
		await get_tree().create_timer(wait).timeout
		elapsed += wait

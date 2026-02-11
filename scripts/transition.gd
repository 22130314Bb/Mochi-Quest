extends CanvasLayer

@onready var color_rect: ColorRect = $color_rect

func _ready() -> void:

	if color_rect.material:
		color_rect.material = color_rect.material.duplicate()
	
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	

	
	show_new_scene()

func change_scene(path: String, delay: float = 0.5):
	var scene_transition = create_tween()
	
	scene_transition.tween_property(color_rect.material, "shader_parameter/threshold", 1.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	

	if delay > 0:
		scene_transition.tween_interval(delay)
	
	await scene_transition.finished
	
	# Muda a cena
	var error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Falha ao carregar a cena: " + path)
	else:
		
		show_new_scene()

func show_new_scene():
	var show_transition = create_tween()
	

	color_rect.material.set_shader_parameter("threshold", 1.0)
	

	show_transition.tween_property(color_rect.material, "shader_parameter/threshold", 0.0, 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await show_transition.finished

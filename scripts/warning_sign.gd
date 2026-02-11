extends Node2D

@onready var texture: Sprite2D = $texture
@onready var area_sign: Area2D = $area_sign

const lines: Array[String] = [
	"Ta sentindo esse cheiro???",
	"Cheiro de lugares secretos...",
	"Deve ser so impressão minha",
]

func _process(_delta: float) -> void:
	var bodies = area_sign.get_overlapping_bodies()
	if bodies.size() > 0:
		texture.show()
		if Input.is_action_just_pressed("interact") and !DialogManager.is_message_active:
			texture.hide()
			DialogManager.start_message(global_position, lines)
	else:
		texture.hide()

# Esta função será chamada automaticamente quando você sair da área
func _on_area_sign_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player": # Ajuste conforme o nome do seu Player
		_close_dialog()

func _close_dialog() -> void:
	# Verifica se o DialogManager tem uma caixa ativa e a remove
	if DialogManager.is_message_active:
		if DialogManager.dialog_box != null:
			DialogManager.dialog_box.queue_free()
		DialogManager.is_message_active = false

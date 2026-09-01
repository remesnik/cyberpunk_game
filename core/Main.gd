extends Node


func _ready() -> void:
	Game.start_session()
	Debug.log_message("Cyberspace bootstrap ready")

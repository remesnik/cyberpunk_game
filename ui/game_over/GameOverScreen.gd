class_name GameOverScreen
extends CanvasLayer

@onready var continue_button: Button = %Continue
@onready var status_label: Label = %Status

func _ready() -> void:
	hide()
	EventBus.game_over_started.connect(_on_game_over_started)
	EventBus.game_over_recovered.connect(_on_game_over_recovered)
	continue_button.pressed.connect(_continue)

func _on_game_over_started(message: String, can_continue: bool) -> void:
	status_label.text = "%s\n\n%s" % [message, "LAST MEAT-SPACE AUTOSAVE AVAILABLE" if can_continue else "NO VALID MEAT-SPACE AUTOSAVE\nCONTINUE WILL RETURN TO THE START OF THIS MODE"]
	continue_button.text = "CONTINUE" if can_continue else "CONTINUE // RESTART MODE"
	show()
	continue_button.call_deferred("grab_focus")

func _continue() -> void:
	continue_button.disabled = true
	var result := Game.continue_from_game_over()
	if not result.success:
		status_label.text = result.reason
		continue_button.disabled = false

func _on_game_over_recovered(_from_autosave: bool, _message: String) -> void:
	continue_button.disabled = false
	hide()

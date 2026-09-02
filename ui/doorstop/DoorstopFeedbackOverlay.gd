class_name DoorstopFeedbackOverlay
extends CanvasLayer

@onready var panel: PanelContainer = %FeedbackPanel
@onready var title_label: Label = %FeedbackTitle
@onready var message_label: Label = %FeedbackMessage
@onready var timer: Timer = %FeedbackTimer
@onready var help_dialog: AcceptDialog = %HelpDialog
var _queued_feedback: Array[Dictionary] = []


func _ready() -> void:
	panel.visible = false
	EventBus.doorstop_feedback.connect(_show_feedback)
	timer.timeout.connect(_advance_queue)


func _show_feedback(event: Dictionary) -> void:
	if panel.visible:
		_queued_feedback.append(event.duplicate(true))
		return
	_display(event)


func _display(event: Dictionary) -> void:
	title_label.text = String(event.get("title", "DOORSTOP")).to_upper()
	message_label.text = String(event.get("message", ""))
	panel.visible = true
	timer.start(4.5)
	var help_text := String(event.get("help_text", ""))
	if not help_text.is_empty():
		help_dialog.title = "DOORSTOP // DISPOSABLE BACKDOOR UTILITY"
		help_dialog.dialog_text = help_text
		help_dialog.popup_centered(Vector2i(560, 260))


func _advance_queue() -> void:
	panel.visible = false
	if not _queued_feedback.is_empty():
		_display(_queued_feedback.pop_front())

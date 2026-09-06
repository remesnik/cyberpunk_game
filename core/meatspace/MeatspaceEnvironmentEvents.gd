class_name MeatspaceEnvironmentEvents
extends Node
## Entry-relative events. Leaving cancels everything; entering restarts the schedule.
signal event_started(id: StringName)
signal event_progress(id: StringName, progress: float)
signal event_finished(id: StringName)
var definitions: Array = []
var elapsed := 0.0
var active := false
var running: Dictionary = {}
var completed: Dictionary = {}

func enter() -> void:
	leave()
	elapsed = 0.0
	completed.clear()
	active = true

func leave() -> void:
	active = false
	for id: StringName in running: event_finished.emit(id)
	running.clear()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active: return
	elapsed += maxf(delta, 0.0)
	for event: Dictionary in definitions:
		var id := StringName(event.id)
		if completed.has(id) or elapsed < float(event.delay): continue
		if not running.has(id):
			running[id] = true
			event_started.emit(id)
		var progress := clampf((elapsed - float(event.delay)) / maxf(0.01, float(event.duration)), 0.0, 1.0)
		event_progress.emit(id, progress)
		if progress >= 1.0:
			running.erase(id)
			completed[id] = true
			event_finished.emit(id)

func _exit_tree() -> void:
	leave()

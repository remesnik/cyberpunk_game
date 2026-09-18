extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	_expect(level != null and level.hud_guidance.get("profile_id", &"") == &"FIRST_CONTACT_GRADUAL_HUD", "FIRST_CONTACT authors a reusable gradual HUD profile")
	HudState.reset_defaults()
	HudState.configure_content_profile(level.hud_guidance)
	_expect(not HudState.is_visible(HudState.Widget.SPHERE_MINIMAP), "Sphere Minimap is hidden at tutorial entry")
	_expect(not HudState.is_visible(HudState.Widget.PROGRAM_QUICKBAR), "Program Quickbar is hidden before its lesson")
	_expect(HudState.is_visible(HudState.Widget.TRACE) and HudState.is_visible(HudState.Widget.OBJECTIVE), "basic trace and objective remain visible at entry")
	_expect(not HudState.handle_bound_action(&"TOGGLE_MINIMAP") and not HudState.is_collapsed(HudState.Widget.SPHERE_MINIMAP), "early minimap command cannot pre-collapse the unrevealed tutorial widget")
	_expect(not HudState.handle_bound_action(&"OPEN_PROGRAM_LOADOUT"), "early loadout command does not open an empty hidden surface")

	var lessons: Array[Dictionary] = []
	var emphases: Array[Dictionary] = []
	HudState.diegetic_lesson_requested.connect(func(actor_id: StringName, lesson_id: StringName, lines: Array) -> void: lessons.append({"actor": actor_id, "id": lesson_id, "lines": lines}))
	HudState.widget_emphasis_requested.connect(func(widget_id: int, duration: float) -> void: emphases.append({"widget": widget_id, "duration": duration}))
	HudState.trigger_content_event(&"PLAYER_MOVED")
	_expect(not HudState.is_visible(HudState.Widget.SPHERE_MINIMAP), "first traversal keeps attention on the local graph")
	HudState.trigger_content_event(&"PLAYER_MOVED")
	_expect(HudState.is_visible(HudState.Widget.SPHERE_MINIMAP), "second traversal reveals the Sphere Minimap")
	_expect(lessons.size() == 1 and String((lessons[0].lines as Array)[0]).contains("room"), "Latch contrasts the current node with the Sphere")
	_expect(HudState.handle_bound_action(&"TOGGLE_MINIMAP"), "optional focus objective accepts the normal bound minimap action")
	_expect(lessons.size() == 2 and String((lessons[1].lines as Array)[0]).contains("security neighborhood"), "Latch concisely explains historical Sleeve membership after focus")

	HudState.set_context_active(HudState.Widget.MONITOR, true)
	_expect(HudState.is_visible(HudState.Widget.MONITOR) and lessons.any(func(item: Dictionary) -> bool: return item.id == &"FC_HUD_MONITOR"), "first active external feed opens and explains the shared Monitor")
	HudState.trigger_content_event(&"PROGRAM_BOUND")
	_expect(HudState.is_visible(HudState.Widget.PROGRAM_QUICKBAR), "binding a program reveals the quickbar")
	_expect(emphases.any(func(item: Dictionary) -> bool: return item.widget == HudState.Widget.PROGRAM_QUICKBAR and item.duration > 0.0), "new quickbar receives restrained temporary emphasis")

	_expect(not HudState.is_visible(HudState.Widget.TEAM_STATUS), "Team Status stays absent before a relevant contact")
	HudState.set_context_active(HudState.Widget.TEAM_STATUS, true)
	_expect(HudState.is_visible(HudState.Widget.TEAM_STATUS) and HudState.is_collapsed(HudState.Widget.TEAM_STATUS), "relevant team contact reveals only compact Team Status")

	HudState.reset_defaults()
	print("%s: %d FIRST_CONTACT HUD progression assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)

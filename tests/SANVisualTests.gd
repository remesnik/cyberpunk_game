extends Node

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")

func _ready() -> void:
	game.start_session()
	await _test_hosted_local_visual()
	_test_visual_states_and_enemy_redaction()
	game.end_session()
	print("%s: %d SAN visual assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_hosted_local_visual() -> void:
	var display := (load("res://cyberspace/display/NetworkDisplay.tscn") as PackedScene).instantiate() as NetworkDisplay
	add_child(display); await get_tree().process_frame
	var san: SystemAccessNode = game.player_system_access_node
	_expect(display.san_visuals.has(san.id), "local SAN receives a dedicated cyberspace glyph")
	var visual: Control = display.san_visuals[san.id] as Control
	_expect(visual.get_parent() == display.node_visuals[san.host_node_id] and not display.node_visuals.has(san.id), "SAN visual is contained by its host and is not a graph destination")
	_expect(visual.is_local and visual.defense_count >= 2 and visual.owner_label == "LOCAL", "glyph communicates local ownership and installed defenses")
	display._select_target(san.id)
	var text := display.target_details.text
	_expect("SYSTEM ACCESS NODE" in text and "OWNER: LOCAL" in text and "LINK: ACTIVE" in text and "INTEGRITY: 100%" in text, "own SAN inspection presents connection and integrity clearly")
	_expect("ICE WALL" in text and "WATCHDOG" in text and "DECK LINK\nCONNECTED" in text, "own SAN inspection lists defenses and connected deck link")
	display.queue_free()

func _test_visual_states_and_enemy_redaction() -> void:
	var san := SystemAccessNode.new(&"ENEMY_SAN", &"ENEMY", &"RUN", &"ENEMY_DECK", &"HOST")
	_expect(san.visual_state() == SystemAccessNode.VisualState.NORMAL, "unmodified SAN has normal state")
	var controller := SANDefenseController.new(); controller.install(san, SANDefenseCatalog.create_defaults()[0])
	_expect(san.visual_state() == SystemAccessNode.VisualState.DEFENDED, "installed defenses produce defended state")
	san.apply_damage(10); _expect(san.visual_state() == SystemAccessNode.VisualState.DAMAGED, "integrity loss produces damaged state")
	san.mark_breached(&"PLAYER"); _expect(san.visual_state() == SystemAccessNode.VisualState.BREACHED, "successful compromise produces breached state")
	san.mark_under_attack(); _expect(san.visual_state() == SystemAccessNode.VisualState.UNDER_ATTACK, "active hostile pressure produces under-attack state")
	san.destroy(); _expect(san.visual_state() == SystemAccessNode.VisualState.DISCONNECTED, "destroyed deck link produces disconnected state")
	var hidden := controller.display_view(san, &"PLAYER", SANAccessSession.AccessLevel.NONE)
	var observed := controller.display_view(san, &"PLAYER", SANAccessSession.AccessLevel.OBSERVED)
	var breached := controller.display_view(san, &"PLAYER", SANAccessSession.AccessLevel.BREACHED)
	var accessed := controller.display_view(san, &"PLAYER", SANAccessSession.AccessLevel.DECK_ACCESS)
	_expect(hidden.is_empty() and not observed.has("integrity") and not observed.has("owner_actor_id"), "undiscovered enemy SANs are absent and observed SAN details remain redacted")
	_expect(breached.has("integrity") and breached.owner_actor_id == &"ENEMY" and not breached.has("defenses"), "breach reveals connection state without leaking defenses")
	_expect(accessed.has("defenses") and accessed.defenses.size() == 1, "sufficient enemy SAN access reveals installed defenses")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)

class_name AuthoredHackerFactory
extends RefCounted


static func configure_manager(manager: HackerNPCManager, document: CyberspaceContentDocument) -> void:
	if manager != null and document != null: manager.configure_tutorial_guidance(document.tutorial_guidance_rules)


static func create_actor(actor_data: Dictionary, reactions: Array[Dictionary]) -> HackerNPC:
	if StringName(actor_data.get("id", &"")).is_empty(): return null
	var definition := HackerNPCDefinition.new(actor_data.get("definition_id", actor_data.id), actor_data.get("display_name", "Remote Hacker"), actor_data.get("callsign", "REMOTE"))
	definition.faction = actor_data.get("faction", &"INDEPENDENT")
	definition.description = actor_data.get("description", "")
	definition.comms_channel_id = actor_data.get("comms_channel_id", &"")
	definition.visual_signature = actor_data.get("visual_signature", &"REMOTE_PROCESS")
	definition.player_relationship = actor_data.get("relationship", &"NEUTRAL")
	definition.local_visibility_hops = int(actor_data.get("local_visibility_hops", 1))
	definition.story_tags.assign(actor_data.get("story_tags", []))
	for reaction: Dictionary in reactions:
		if reaction.get("actor_id", &"") == actor_data.id: definition.scripted_reactions.append(reaction.duplicate(true))
	var actor := HackerNPC.new(actor_data.id, definition, actor_data.get("initial_node_id", &""))
	actor.state = HackerNPC.State.HIDDEN if actor_data.get("initial_state", &"HIDDEN") == &"HIDDEN" else HackerNPC.State.OFFLINE
	return actor

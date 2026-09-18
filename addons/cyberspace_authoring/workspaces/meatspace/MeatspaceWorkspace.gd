@tool
class_name MeatspaceAuthoringWorkspace
extends AuthoringContentWorkspace


func _ready() -> void:
	super()
	set_collections([&"meatspace_locations", &"room_bindings", &"meatspace_interactions", &"realtime_endpoints", &"physical_devices", &"comms_channels", &"comms_sessions", &"comms_participants", &"video_feeds", &"alarms", &"physical_teams", &"team_operations", &"equipment", &"vendors", &"equipment_orders", &"realtime_events", &"rewards"] as Array[StringName])

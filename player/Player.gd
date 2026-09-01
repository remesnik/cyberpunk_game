extends Node

## Input adapter placeholder. Authoritative location is held by
## Game.player_network_position, never by a scene transform.

func request_move_to(node_id: StringName) -> ActionResult:
	return Game.request_traversal(node_id)

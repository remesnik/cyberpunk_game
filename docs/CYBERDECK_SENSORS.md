# Cyberdeck Sensors

`DECK_SENSORS` is the canonical hardware key in `PersistentGameState.player_state.hardware` and `MeatspaceManagement.hardware_levels`. Old saves that contain `DECK_DETECTION` migrate that value into `DECK_SENSORS` when a session starts. The player-facing label is **Sensors**.

`SensorTopologyController` performs a bounded breadth-first traversal from the player's current node. Its centralized rating map is:

| Sensors | Extra layers | Maximum depth from current node |
| --- | ---: | ---: |
| 0 | 0 | 1 |
| 1 | 1 | 2 |
| 2 | 1 | 2 |
| 3+ | 2 | 3 |

Depth-one nodes and their links become identified because they are immediate traversal choices. Farther nodes are stored in `PlayerKnowledge` at `DETECTED` with `DECK_SENSORS` provenance. Their records contain existence and provenance, without identity, type, security, ownership, services, contents, or other objective-world fields. Detected topology persists as player memory after leaving range, while `SensorTopologyController.current_view()` always contracts and expands around the current position.

The controller exposes only a BFS tree for the current sensor view, preventing unrelated distant edges from leaking. `NetworkDisplay` renders those distant nodes through the existing `NodeVisual` scene as dim `UNKNOWN NODE` markers. It does not add them to interaction, scan, program, or movement target maps. The debug-only `NetworkDisplay.debug_sensor_topology` export prints rating, lookahead, maximum depth, per-node state, and BFS depth.

First Contact starts with Sensors 1. From `ENTRY`, `ACCESS_RELAY` is the normal adjacent choice and `ROUTER_A` appears at depth two as unknown sensor topology. Latch explains the distinction in the opening authored dialogue.

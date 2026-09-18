# Gameplay Action Bindings

`GameplayActionBindings` is the single InputMap-to-gameplay translation boundary. Gameplay code consumes `GameplayBindingRequest` values rather than checking physical keys. The default `GameplayBindingProfile` separates three namespaces:

- Global game actions: program loadout, Sphere Minimap, Jack Out, Monitor, Team Status, and Node Inspector.
- Cyberspace commands: scan, inspect, confirm/move, attack, evade, target cycling, cancel, monitor, and intercept.
- Program bindings: eight configurable actions that resolve either a current loadout slot or an explicitly bound unique `ProgramInstance` ID.

Program bindings never depend on names such as ICEBREAKER, SPOOF, or DOORSTOP. If an explicitly bound instance is no longer installed, resolution fails safely. Doorstop behavior is selected from the resolved instance's definition and still uses its normal confirmation and consumption flow.

`rebind(input_action, events)` replaces keyboard, mouse, or controller events through Godot's `InputMap`. `save_configuration()` and `load_configuration()` persist these user choices independently of saved games. The default configuration is loaded automatically on startup. A future Settings screen can call these APIs without modifying cyberspace UI scripts. Gameplay labels use `get_binding_label()` so rebinding does not leave fixed key names in the program bar or scan control.

The binding service has Disabled, Cyberspace, and Meatspace contexts. Global actions remain available in gameplay contexts; cyberspace commands and program bindings emit only in cyberspace. `NetworkDisplay` owns the current presentation response, while other monitor/inventory controllers can subscribe to the same semantic requests later.

HUD commands use semantic IDs rather than fixed key checks: `TOGGLE_MINIMAP`, `TOGGLE_MONITOR`, `TOGGLE_TEAM_STATUS`, `OPEN_NODE_INSPECTOR`, and `OPEN_PROGRAM_LOADOUT`. Their default InputMap actions are M, C, Y, N, and I respectively, but all may be rebound to keyboard, mouse, or controller inputs. `HudVisibilityManager` is the single dispatcher for these commands. It rejects contextual surfaces without valid content and emits concise feedback instead of creating empty panels.

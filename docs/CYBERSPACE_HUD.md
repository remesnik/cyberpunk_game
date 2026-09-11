# Cyberspace HUD hierarchy

The main HUD treats the local network graph as the primary workspace. Its safe interaction rectangle excludes the right contextual rail, top status strip, and bottom quick-access strips, so larger hex nodes do not sit beneath controls. Current-node details start collapsed; the node itself and graph remain the primary default presentation.

- **Primary:** local graph, contextual target/threat actions, and Sphere minimap.
- **Secondary:** the compact trace/tick/objective strip and one-row program bindings.
- **Contextual:** target details, event history, realtime comms/video/alarm monitors, and team status.

The top strip holds trace/alert, tick, objective, and concise risk. The right rail keeps the Sphere minimap permanently discoverable and hosts transient target or Monitor presentations. The bottom program strip preserves visible bindings; the thin row above it hosts Team Status only when relevant. Target details remain hidden until a node, link, service, capability, hacker, or ICE contact is selected. The event log is collapsed independently. Team Status is a thin knowledge-safe roster of relevant physical teams and allied remote hackers; selecting it reveals operational detail. External feeds use the unified contextual Monitor and leave no empty panel when inactive.

The target inspector and expanded Monitor share the contextual rail rather than overlapping the graph or each other. An expanded Monitor temporarily yields that rail to the live feed; collapsing it with the configured Monitor key restores any requested target inspector immediately.

Responsive layout has explicit checks at 1280×720 and 1920×1080. It changes reserved panel widths rather than applying per-resolution node positions; graph placement continues to use the visualization configuration and computed safe rectangle.

The live scene is `Main.tscn` -> `NetworkDisplay.tscn`, including the bedroom -> Clean-Room -> Netspace story path. Entering Netspace restores the active program strip even when First Contact guidance hid it in the Clean-Room. The strip renders capacity, including empty positions: base and More Storage have two slots; More Slots has three. Every slot widget is created and connected by `_update_program_bar()`.

The selector sits above the monitor and control hints. It shows up to five labeled command buttons with light SVG strokes and a gold selected command. D-pad Left/Right rotates their ordering and selection through the gameplay bindings. Slot and command buttons do not capture directional focus. Neighborhood rebuilds retain valid target/command selection. Unscanned NODE, ICE, SERVICE, FILE, and DEVICE_OBJECT targets default to Scan; known targets with a live scan descriptor can also be scanned again.

The runtime investigation found a parse error in a temporary debug overlay (`Control.PRESET_BOTTOM_CENTER`) that prevented the entire NetworkDisplay script from loading, duplicate initialization, disconnected static slot placeholders, a quickbar policy restored only at session start, and dark `currentColor` strokes. The production HUD replaces those obsolete debug/static implementations. The starting working tree had no tracked diff and only an empty, preserved `copilot-netspace-wip.patch`.

`StoryPrologueIntegrationTests` covers the real handoff, empty capacities, slot clicks, injected joypad Left/Right events, selected styling, refresh persistence, and viewport bounds. Its 69 assertions pass headlessly and with rendering at 1600x900. Pass `-- --capture` to save `.godot/bedroom-fix-netspace-hud.png` and `.godot/bedroom-fix-netspace-dpad-right.png`. Starter deck, active slot, command, and focus suites pass 5, 8, 16, and 7 assertions respectively. The isolated focus test still reports resource leaks at shutdown.

# Cyberspace: Breach Window

A polished Godot 4.x vertical slice for a tactical cyberspace dungeon crawl. Networks are logical graphs: hosts are discrete locations, connections are routes, and every meaningful action advances simulation time. There is no free movement or physical platforming.

## Vertical slice

**BREACH WINDOW:** support Team Alpha as it moves in realtime from the street toward a corporate server room. Simultaneously traverse the discrete cyberspace graph, discover a guard call and camera feeds, loop the loading-dock camera, unlock Door 12, and bypass the server alarm.

The network begins only partially known. Scan nodes and contacts, inspect services, exploit vulnerabilities, acquire capabilities, open locked or hidden routes, and decide when to advance or retreat. ICE moves on the same graph whenever actions spend time. Trace reaching its failure threshold forcibly disconnects the player and leaves volatile data in a single Crash Cache at the failure node.

Team Alpha reaches the loading dock in roughly 45 realtime seconds. Cyber actions still consume only discrete simulation ticks. The outcome depends on player actions and actual decision time; it is not scripted to succeed.

## Run

1. Open Godot 4.x and import `project.godot` from this directory.
2. Press **F6** to run the current scene or **F5** to run the project.

Choosing **New Game → Story Mode** now begins in the authored meat-space bedroom prologue. Select a play-style clan and starter deck, optionally adjust the deck with the toolbox, Jack In, connect to the local BBS, and ask for practical guidance. That request launches FIRST_CONTACT and creates the first real intrusion and SAN. The current prose is intentionally temporary; the interaction flow is data-driven for later story replacement.

## Controls

- **Left click:** select a node, link, service, signal, or known ICE process.
- **Execute** or **Enter/E:** confirm movement or the selected contextual action.
- **Right click** or **R:** scan the selected target; with no target, scan the current node.
- **Q/Tab:** cycle known targets.
- **Backspace:** clear the current target.
- **1–4:** select a loaded program slot.
- Tactical buttons: wait, exploit, extract, retreat, disrupt, spoof, hide, attack, redirect, break locks, or scramble trace.
- **Escape:** hard pause. **F3:** toggle the debug overlay, including side-by-side cyber and meatspace timelines.

There are no WASD movement controls. Visual transition duration never controls simulation time.

## Gameplay loop

1. Inspect the current host and incomplete local topology.
2. Select and scan a node, route, service, or signal.
3. Choose whether to move, wait, exploit, retreat, confront ICE, or lower trace.
4. Spend the action's tick cost and observe ICE, trace, and network events.
5. Keep monitoring the physical consequences while opening the route to SERVER_ROOM.

See `docs/FACILITY_OPERATION_SLICE.md`, `docs/DUAL_TIME_MODEL.md`, and `docs/REALTIME_STORY_HOOKS.md` for system details and prototype findings.

## Tests

Run an individual headless suite from the project directory, for example:

```powershell
godot --headless --path . --script res://tests/FacilityOperationSliceTests.gd
```

## License

Copyright (c) 2026 Adam "Brute" Sangwin-Remesnik. All rights reserved.
This project is proprietary software; see [LICENSE](LICENSE) for its terms.

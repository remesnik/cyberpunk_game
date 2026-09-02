# Cyberspace Authoring Studio

Cyberspace Authoring Studio is a Godot 4 editor plugin for creating the game's linked cyber, story, and meatspace content. Enable it in **Project > Project Settings > Plugins**, then open the **CYBERSPACE** bottom panel.

## First workflow

1. Choose **OPEN** and load `res://data/authoring/server_facility_infiltration.tres`, or choose **NEW**.
2. Use **GRAPH** to add, duplicate, connect, disconnect, and reposition network nodes. Node positions are saved to a separate `.editor_state.tres`; moving a box never changes runtime topology.
3. Use **STORY**, **MEATSPACE**, and **CONTENT** to browse and create definitions. The left browser searches IDs, names, tags, linked nodes, and physical locations across the whole document.
4. Use **OPERATION** to inspect the cyber graph, physical route, endpoint relationships, and realtime event timeline together.
5. Select an entry to edit common properties and inspect its structured data. Conditions and actions are stored as data, never executable editor code.
6. Choose **VALIDATE**. Errors, warnings, and informational findings appear in the lower panel; selecting an issue focuses its referenced entry.
7. Use **PREVIEW** to compare true-world and new-player views, modify editor-only capability/credential/flag profiles, and scrub cyber and realtime clocks independently.
8. Choose **SAVE** to persist the content document and its separate editor state. **PLAY FROM HERE** saves and launches the project main scene.

## Workspaces

- **GRAPH** edits objective network topology. Links are stable-ID relationships; screen positions are editor state.
- **STORY** manages hooks, bundles, variables, graffiti, and flavor text.
- **MEATSPACE** manages locations, endpoints, devices, comms, video, alarms, teams, equipment, and realtime events.
- **CONTENT** provides a compact collection-oriented editor for all definitions.
- **OPERATION** gives a cross-domain view for authored missions.
- **PREVIEW** is a safe, non-persistent inspection surface. It does not mutate the document or expose hidden definitions to player-knowledge views.

## Templates

**CREATE FROM TEMPLATE** provides starter nodes, services, endpoints, story hooks, physical systems, teams, orders, and realtime events. Templates create normal document entries; saved content has no dependency on template code.

## Architecture boundary

Runtime-safe authored data lives in `res://data/authoring/` and uses `CyberspaceContentDocument`. Editor UI, layout, selection, preview profiles, validators, and templates live under `res://addons/cyberspace_authoring/`. Runtime systems must never import addon scripts. Realtime definitions express durations in seconds and do not reference or advance `CyberspaceClock`.

See [AUTHORING_DATA_MODEL.md](AUTHORING_DATA_MODEL.md) for schema details and [AUTHORING_TOOL_LIMITATIONS.md](AUTHORING_TOOL_LIMITATIONS.md) for deliberately deferred work.
## Guided mission sequences

The STORY workspace includes a SEQUENCES tab for composing tutorials and authored missions from generic event nodes. Supported nodes cover remote-hacker presence and movement, dialogue, objective lifecycle, gameplay-event waits, highlights, program rewards, ICE spawning, trace changes, realtime events, conditional branches, escalating optional hints, and completion flags.

Doorstop deployment, suspension, and re-entry are ordinary `WAIT_FOR` nodes using `DOORSTOP_DEPLOYED`, `INTRUSION_SUSPENDED_AT_DOORSTOP`, and `INTRUSION_RESUMED_FROM_DOORSTOP`. They are not tutorial-specific commands. Node dictionaries contain runtime data only; selection, layout, and open panels remain editor-only state.

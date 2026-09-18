# Architecture

The project is organized by gameplay responsibility:

- `autoload/`: small global services and cross-module signals (`Game`, `EventBus`, `Debug`).
- `core/`: application lifecycle and top-level orchestration.
- `player/`: player command intent and player-specific state; not a physics-driven avatar.
- `world/` and `cyberspace/`: logical network graph, mission state, and their visual projection. Logical state must be kept separate from scene presentation.
- `entities/`: reusable nodes, services, data stores, gateways, and security actors.
- `programs/`, `combat/`, and `hacking/`: independent gameplay systems communicating through explicit APIs and `EventBus` signals.
- `ui/`: player-facing interfaces; `debug/`: development-only visualization and tools.
- `data/`: resource definitions and configuration; `assets/`, `materials/`, `meshes/`, and `audio/`: content grouped by type.
- `scenes/`: shared or cross-feature scene compositions; `tests/`: automated and manual verification scenes/scripts.

`Main` owns startup and coordinates the active session. The eventual logical model is authoritative for graph topology, occupancy, turns, trace, access, and security. Scenes project that state and emit player intent; they do not determine rules through transforms, collision, or visual node lifetime. Feature modules should avoid direct knowledge of one another where a signal or narrow interface suffices. Autoloads should remain small and must not become general-purpose state containers.

The authoritative design is defined in `CORE_GAMEPLAY.md`, `MOVEMENT_MODEL.md`, and `DISPLAY_MODEL.md`.

The initial navigation domain lives in `cyberspace/`: definitions describe nodes and links, `NetworkGraph` owns topology and traversal rules, and `PlayerNetworkPosition` owns logical player occupancy and history. These classes extend `RefCounted` so tests and simulation do not require a loaded 3D scene.

Within a network, `SphereDefinition` records persistent authored subnet membership, while `SecuritySleeve.current_members` records the mutable security boundary that exists now. Nodes retain their `sphere_id` when a sleeve is breached, split, bypassed, or disabled; current sleeve connectivity must never be used to reconstruct Sphere membership.

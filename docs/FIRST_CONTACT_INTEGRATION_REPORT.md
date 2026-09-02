# FIRST_CONTACT Integration Report

This pass audits a fresh run with all authored tutorial flags at their defaults. The automated coverage combines the full authored graph audit with the existing production-system integration scenarios for scanning, trace, ICE, realtime communications, program rewards, Doorstop suspension/re-entry, meat-space loadout management, programming, confrontation, objective extraction, and normal intrusion completion.

| Tutorial step | Mechanic taught | Trigger | Completion | Production systems |
|---|---|---|---|---|
| Enter and meet Latch | Diegetic guidance | Enter `ENTRY` | Latch ingress communication begins | StoryHooks, HackerNPC, realtime comms |
| Inspect ingress | Node knowledge | Opening objective | `ENTRY` scanned | ScanSystem, PlayerKnowledge |
| Reach relay/router | Discrete movement and action cost | Ingress inspected | Enter `ACCESS_RELAY`, then reveal `ROUTER_A` | NetworkGraph, PlayerNetworkPosition, ActionClock |
| Inspect services | Local service discovery | Scan router/camera node | `CAMERA_MATRIX` identified | ScanSystem, PlayerKnowledge |
| Compromise cameras | Cyber-to-physical control | Camera service discovered | Camera feed disabled | VideoFeedManager, ActionClock |
| Observe trace and ICE | Security consequences | Camera state changes | Trace displayed and auditor detected | Trace updater, IceController, PlayerKnowledge |
| Intercept live call | Independent realtime activity | Communications endpoint discovered | Listen, intercept, or deliberately ignore | RealtimeWorldClock, RealtimeProcessManager, CommsInterceptionManager |
| Discover cache | Optional exploration and rewards | Inspect `FILE_CACHE`/`CACHE_INDEX` | Cache rewards collected | authored rewards, SoftwareProgrammingManager grant pipeline |
| Acquire/deploy Doorstop | Disposable instance and anchor placement | Doorstop instance acquired | A legal DoorstopAnchor is deployed | ProgramInventory, ProgramLoadout, DoorstopController |
| Jack Out | Suspend rather than abort | Active Doorstop anchor | Lifecycle becomes `SUSPENDED_AT_DOORSTOP` | IntrusionSession, DoorstopAnchor |
| Manage deck | Persistent meat-space management | Suspended intrusion | Inspect deck and change one valid loadout instance | MeatspaceManagement, ProgramLoadout |
| Start programming | Realtime software production | Loadout changed | Software task queued | SoftwareProgrammingManager, RealtimeWorldClock |
| Jack Back In | Exact-node continuity | Suspended intrusion and active anchor | Lifecycle returns to `ACTIVE`; anchor is destroyed | IntrusionSession, DoorstopController, current loadout snapshot |
| Handle active ICE | Topology-based confrontation | Re-entry state presented | Retreat, disrupt, damage, redirect, or spoof succeeds | IceController, ConfrontationController, ActionClock |
| Complete objective | Scan/exploit/transfer synthesis | Enter `OPS_SERVER` | Route manifest objective completes | ScanSystem, mission action validation, resource state |
| Exit | Normal intrusion completion | Objective complete and `OPS_EXIT` unlocked | Enter `EXIT_GATE`; lifecycle becomes `COMPLETED` | NetworkGraph, IntrusionSession |

## Integration findings

- Tutorial resources contain no debug/cheat commands and fresh story flags default to false.
- Tutorial objectives have no tutorial-only hard failures. Genuine trace failure, illegal graph traversal, invalid programs, and prohibited actions still follow production rules.
- Doorstop rewards create unique program instances through the generic reward/software pipeline. Deployment, burning, suspension, exact-node return, and anchor destruction use `DoorstopController` and `IntrusionSession`.
- Camera calls run through objective realtime processes and communications sessions. Cyber ticks do not advance their elapsed time.
- The passive auditor is built through `AuthoredIceFactory` and updated by `IceController`; confrontation choices use `ConfrontationController`.
- Loadout changes made while suspended are captured on re-entry. The programming task is queued against realtime rather than cyber ticks.
- Context reactions are once/cooldown constrained. Progressive hints stop after their final authored line.

## Remaining generalization work

- FIRST_CONTACT still contains legacy `beats` alongside the new generic mission-event-node schema. The authoring plugin can convert these non-destructively, but the level should eventually be migrated and reviewed entirely as event nodes.
- A single production `MissionSequenceRunner` should become the sole runtime interpreter for generic event nodes. Some current tutorial orchestration remains represented by legacy StoryHook/beat condition-action dictionaries.
- Mission save/load is not implemented. RealtimeWorldClock supports restoring elapsed time, but there is no complete serializer for sequence cursor, fired dialogue/hints, intrusion lifecycle, ICE, knowledge, inventory, programming tasks, and realtime sessions. Saving during FIRST_CONTACT should remain unavailable until that aggregate snapshot exists.

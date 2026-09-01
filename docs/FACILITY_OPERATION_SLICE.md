# Facility Operation Vertical Slice

## Scenario

The active prototype is **BREACH WINDOW**. Team Alpha begins moving immediately in realtime from `STREET` toward `LOADING_DOCK`, `SERVICE_HALL`, and `SERVER_ROOM`. The first segment takes approximately 45 seconds. In parallel, the player begins at `PUBLIC_GATEWAY` and traverses this discrete cyber graph:

`PUBLIC_GATEWAY → CORP_ROUTER → SECURITY_NET → CAMERA_SERVER → ACCESS_CONTROL → PBX_SERVER → ALARM_CONTROLLER`

Scanning nodes reveals services; scanning those services reveals sanitized realtime endpoints through `PlayerKnowledge`. Available discoveries include `CAM_LOADING_DOCK`, `CAM_SERVICE_HALL`, `SECURITY_RADIO`, `GUARD_PHONE_CALL`, `DOOR_12`, and `ALARM_ZONE_SERVER`.

The operation is not an automatic success sequence:

- If `CAM_LOADING_DOCK` is still live when Team Alpha reaches the dock, the team is exposed and enters an encounter state.
- If `DOOR_12` remains locked, the physical route blocks between the loading dock and service hall.
- If `ALARM_ZONE_SERVER` is not bypassed when the team reaches the server room, security detects the team and the operation fails.
- Looping/disabling/spoofing the dock camera, exploiting the door controller, and compromising then bypassing the server alarm permit Team Alpha to reach the objective.

The guard phone call and security radio use their objective realtime processes. Transcript events occur at absolute stream offsets even while cyber actions resolve. Arriving or intercepting late can therefore miss useful information. The phone call explicitly reports that a guard is moving toward the loading dock.

The F3 overlay shows recent `CYBERSPACE EVENTS` and `MEATSPACE EVENTS` in side-by-side columns. Entries retain their own tick or realtime timestamp; the timeline does not convert between domains.

## Problems revealed

### Architecture

- `Game.gd` still performs too much fixture construction and mission wiring. The slice needed several coordinated setup functions to agree on IDs. A mission package or composition root should own graph, endpoints, processes, hooks, and physical routes as one validated authored asset.
- The earlier `PayrollMissionController` mixed generic service exploitation with payroll-specific rewards. The facility controller currently subclasses it to reuse validation, exposing the need for a generic exploitation controller plus mission-specific effect tables.
- Some UI code still references payroll constants for Crash Cache presentation. It is harmless in this slice because no ledger exists, but objective UI should consume a mission interface rather than concrete mission classes.
- Realtime support commands are inconsistent: camera manipulation spends cyber actions, while alarm commands currently execute directly from the realtime monitor after authority validation. A unified cross-domain command definition should explicitly declare whether each command consumes cyber ticks, realtime only, or both.
- Scenario outcomes currently query manager state by stable IDs. This is deterministic and testable, but authored condition/effect resources should replace hard-coded gate checks before multiple operations are built.
- Restarting sessions reconnects many manager signals. The current bootstrap assumes one active run; robust restart/save support needs explicit unbind/reset lifecycles.

### UX

- A 45-second opening window is demanding before the player understands scan depth, service selection, monitor docking, and exploit prerequisites. A first-run version needs concise staged prompts without pausing realtime.
- Critical deadlines appear primarily in the F3 debug view. Production UI needs a compact always-visible operation clock and upcoming physical milestone indicator.
- Discovery can produce several monitors at once. Auto-expanding all of them would obscure the graph, while leaving them minimized can hide urgent information. Priority badges and audible but non-modal alerts are needed.
- The difference between scanning a node, scanning its service, and exploiting that service is mechanically sound but not yet visually obvious enough under realtime pressure.
- Missing an early transcript line is intentional, but the player needs unmistakable feedback that the call was already in progress and earlier content was missed.
- Failure causes need a short causal summary—camera live, door locked, or alarm active—so realtime loss feels attributable rather than arbitrary.

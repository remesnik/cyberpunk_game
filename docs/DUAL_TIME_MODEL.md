# Dual Time Model

The game has two simulation domains with deliberately different clocks. Sharing events between them does not make their time progression interchangeable.

## Cyberspace time

`CyberspaceClock` is the explicit domain name for the existing discrete `ActionClock`. Its integer tick advances only after a cyberspace action is validated and successfully applied. The action's declared cost determines the number of ticks spent; costs are not assumed to be one.

The existing resolution order remains:

1. Validate the player action.
2. Apply the player action.
3. Advance the cyberspace tick by its cost.
4. Update ICE.
5. Update trace.
6. Update network systems.
7. Resolve and publish events.
8. Return control to the player.

Rendering frames, animation time, menu navigation, and deliberation never advance this clock. The compatibility property `Game.action_clock` continues to reference the same `CyberspaceClock` instance so existing systems do not require a migration.

## Meatspace time

`RealtimeWorldClock` measures continuous session seconds from frame delta while a session is running. It is owned by the `Game` autoload rather than a visual scene, so changing displays cannot reset or become authoritative for meatspace time.

Realtime seconds advance while the player studies the network, selects targets, or delays taking a cyberspace action. Calling `resolve_action()` never advances this clock. Future calls, cameras, alarms, deliveries, physical teams, and scheduled physical events should subscribe to or sample this time domain rather than cyberspace ticks.

The clock currently provides foundation only; no meatspace simulation systems are attached.

## Cross-domain interactions

Interactions must be explicit events or commands with a recorded source time. Examples include a cyberspace exploit activating a physical alarm, or a realtime security-team arrival changing a network access condition.

When an interaction crosses domains:

- The source domain emits a fact containing its own timestamp.
- The receiving system queues or applies that fact at a defined synchronization boundary.
- It does not convert arbitrary seconds into ticks or ticks into seconds.
- Cyberspace action resolution remains atomic; realtime callbacks must not mutate the middle of its validation/apply/update sequence.

A future coordinator should queue realtime outcomes that occur during an action and resolve them immediately before or after the atomic cyberspace transaction according to a documented rule. This avoids frame-order nondeterminism.

## Pause behavior

`PausePolicy` is the single authority for pause semantics. Gameplay UI must not assign `SceneTree.paused` directly. Menus request a policy mode, and clocks, action entry points, audio, and future subsystems query or subscribe to the policy.

| Mode | Cyber input/actions | Realtime meatspace | Audio | Scene tree |
| --- | --- | --- | --- | --- |
| `GAMEPLAY` | Active; successful actions spend ticks | Advances continuously | Active | Running |
| `SOFT_PAUSE` | Frozen; action requests are rejected at zero cost | Continues | Active | Running |
| `HARD_PAUSE` | Frozen | Frozen | Paused | Paused centrally |

Soft pause is intended for data inspection and selected menus. Because the scene tree keeps running, camera feeds, calls, alarms, physical teams, delivery timers, and realtime scheduled events continue. Opening an ordinary monitor remains gameplay rather than entering soft pause unless a specific interface explicitly requests it.

Hard pause is the explicit single-player pause. Only `PausePolicy` applies `SceneTree.paused`, and the policy itself runs in `PROCESS_MODE_ALWAYS` so the pause input can resume the game. Ordinary pausable audio nodes freeze with the tree. Audio systems that deliberately run in always-processing mode must subscribe to `audio_pause_changed` and pause their streams on hard pause; soft pause must not stop calls or monitoring audio.

`Game.request_action()` enforces the cyber boundary centrally, preventing UI or debug callers from advancing ticks during either pause state. `RealtimeWorldClock` asks `PausePolicy.allows_realtime_advance()` rather than inferring its behavior from arbitrary UI or scene state.

For future multiplayer sessions, the session authority sets `hard_pause_available` to false. A hard-pause request is then denied without changing modes; soft pause can still freeze one player's cyber commands while the authoritative realtime session continues. Multiplayer synchronization policy remains future work.

## Save and load

A save should store both values independently:

- the integer cyberspace tick and any pending discrete-domain events;
- realtime elapsed seconds plus deadlines expressed in that same session timeline.

Loading restores the values without inferring one from the other. The initial policy should be that time spent outside the running game does **not** advance meatspace. If offline progression is added later, store a wall-clock save timestamp separately and apply a deliberate, validated catch-up step. Never use a system wall clock as the live simulation authority.

Fractional realtime seconds should be serialized at sufficient precision for scheduled events. UI formatting such as `MM:SS.cc` is presentation only.

## Multiplayer implications

No multiplayer behavior is implemented. A future multiplayer design should make the server authoritative for both domains:

- cyberspace actions are ordered and resolved against a server tick;
- realtime events use a server monotonic session timeline;
- clients estimate realtime presentation but reconcile to server timestamps;
- pause policy must be session-wide and server-controlled, not decided by one client's menu;
- cross-domain events carry stable IDs and timestamps so replay or reconciliation cannot apply them twice.

Player decision time must never be translated into free cyberspace ticks, and network latency must never become meatspace simulation time.

## Dual-pressure operations

`OperationPressureDefinition` describes an authored situation with two parallel quantities: a realtime threat deadline and an ordered cyberspace action plan. Each cyber step retains its own discrete action cost. `OperationPressureInstance` records the realtime start/deadline and cyber start tick independently, while `OperationPressureManager` observes both authorities without advancing either one.

For example, a guard can be 42 realtime seconds from `SERVER_ROOM` while the cyber plan still requires MOVE, SCAN, EXPLOIT, controller access, and a door command. Taking a successful cyber action advances the cyber clock through the normal action resolver and may complete a plan step. It does not subtract seconds from the realtime deadline. Conversely, deliberating for twelve actual seconds reduces the guard deadline by twelve seconds without creating any cyberspace ticks, ICE turns, or trace updates.

The remaining cyber cost is useful for tactical comparison, but it is never an estimated duration. UI must label the two domains separately and must not display a conversion rate such as “ticks per second.” Deadline outcomes should enter gameplay through explicit realtime events or commands at documented synchronization boundaries.

## Debug readout

The F3 debug overlay displays the two authorities separately:

```text
CYBER TICK: ###
REALTIME SESSION: ##:##.##
```

The first value changes only after successful discrete actions. The second changes continuously during an unpaused active session.

The debug operation fixture additionally displays both pressures at once:

```text
DUAL PRESSURE // INDEPENDENT CLOCKS
CYBER  TICK 003 // PLAN 2/5 // 6 COST REMAINS
REAL   SECURITY GUARD REACHES SERVER_ROOM IN 31.40s
SECONDS ARE NEVER CONVERTED TO CYBER TICKS
```

# Action and Time Model

## Principle

Simulation time advances only when a meaningful action successfully resolves. It is measured in integer ticks and is independent of rendered frames, animation duration, and wall-clock time. Different actions may spend different amounts of time; a move across a costly route need not equal a ping, transfer, exploit, or program execution.

The initial action vocabulary is `MOVE`, `SCAN`, `PING`, `EXPLOIT`, `TRANSFER`, `WAIT`, and `USE_PROGRAM`. Movement, scanning, and waiting have application handlers in the current slice. Unsupported actions fail validation and spend no time.

## Data contracts

`ActionRequest` contains the acting entity, action type, target, declared cost, and extensible metadata. The authority handling the action must validate both permission and cost rather than trusting presentation code.

`ActionResult` reports success, time spent, a human-readable reason, and an ordered list of generated event dictionaries. Failed validation or application reports zero time spent.

## Resolution order

For every request, `ActionClock` performs this fixed pipeline:

1. Validate the request and its cost.
2. Apply the player action.
3. Advance the integer simulation tick by the action cost.
4. Invoke registered ICE updaters in registration order.
5. Invoke registered trace updaters in registration order.
6. Invoke registered network-system updaters in registration order.
7. Append event-resolution output and return control.

Events retain this phase order. System updaters receive the resulting tick and immutable action intent; they return event data instead of depending on `_process()` or `_physics_process()`.

## Ownership

`Game` composes the clock and domain systems. `NetworkGraph` validates and applies graph traversal but does not advance simulation time. `NetworkDisplay` submits intent and observes results. Animation can continue after the action resolves, but it cannot affect tick count or outcome.

The current ICE, trace, and network update callbacks are deterministic integration points that emit diagnostic events. Their gameplay rules are intentionally deferred.

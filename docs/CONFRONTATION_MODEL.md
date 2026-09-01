# Confrontation Model

## Intent

A confrontation is a tactical exchange between logical actors on the network graph. It is resolved through discrete `ActionRequest`s and simulation ticks. It has no aiming, projectiles, hitboxes, physical chase, or melee loop.

The important questions are where the player and ICE are located, which links connect them, what each side knows, which routes remain available, how much time an action spends, which programs are loaded, and how much trace the player can tolerate.

## Action vocabulary

- `DISRUPT`: delays identified ICE within program range and reduces alert.
- `HIDE`: uses `GHOST` to remove ICE's current player fix; ICE retains stale knowledge and searches.
- `SPOOF`: uses `SPOOF` to reduce alert and send targeted ICE back toward its home route.
- `ATTACK_PROCESS`: damages the integrity of identified ICE. Disabled ICE stops updating; this is program interaction, not shooting.
- `BREAK_LOCK`: uses `DECRYPT` against a locally addressable link and changes authoritative route control.
- `REDIRECT`: uses `SPOOF` to assign an identified ICE a known adjacent graph destination.
- `TRACE_SCRAMBLE`: uses `TRACE_SCRAMBLER` to reduce accumulated trace.
- `RETREAT`: spends its base action cost plus the selected link cost and moves to a valid adjacent node.

Each action is described by `ConfrontationActionDefinition`: cost, graph range, required capabilities, effect power, trace generation, and valid target categories are data rather than hard-coded UI values.

## Range and information

Range is measured in traversable graph links. Range zero means the current node; range one supports the same or an adjacent node. Disabled links do not carry confrontation programs. Specific future programs may apply additional link constraints.

Exact ICE targeting requires `IDENTIFIED` knowledge. A vague signal can inform route choice without granting permission to attack or redirect an unseen process. The confrontation controller reads authoritative positions for validation but never exposes them to presentation.

## Resolution

Confrontation requests use the normal pipeline:

1. Validate target type, knowledge, topology, capability, and canonical cost.
2. Apply the player program or route action.
3. Advance the action clock by the data-defined cost.
4. Update operational, non-disrupted ICE.
5. Apply confrontation and ICE trace changes.
6. Update network systems and resolve events.

This ordering makes action economy meaningful. A costly attack may disable ICE before its update, while an insufficient attack still spends enough time for security to respond. Disruption trades time and trace for a deterministic future window.

## Prototype encounter

The test scenario places the player at `AUTH_SERVER` and identified ICE at adjacent `SECURITY_SERVER`. It verifies adjacent attacks, disruption, hiding, spoofing, redirecting, lock breaking, trace scrambling, and graph-based retreat. All outcomes are deterministic and use node/link IDs.

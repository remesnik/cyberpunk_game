# Core Gameplay

## Intended experience

Cyberspace is a tactical digital dungeon crawl played on an abstract network graph. The player infiltrates a network by entering hosts, inspecting incomplete information, choosing routes, executing programs, managing exposure, and deciding whether to press deeper or retreat.

The core tension comes from making consequential decisions with limited information and resources. Position is logical rather than physical: the player occupies a host, not a coordinate inside a walkable level. A host is a room or location; a connection is an available route, exit, or portal.

Moment-to-moment play should emphasize:

- discovering hosts, connections, services, and security conditions;
- scanning before committing to a route;
- exploiting services and executing programs for specific tactical effects;
- anticipating or avoiding ICE moving through the same network;
- managing trace, access, program capacity, damage, and other mission pressures;
- choosing when to advance, change routes, hold position, or retreat.

## Core loop

1. Observe the current host and known neighboring routes.
2. Inspect threats, opportunities, objectives, and incomplete information.
3. Choose one intentional action: scan, exploit, execute a program, move, wait, or retreat.
4. Resolve its cost and outcome.
5. Advance network time and resolve ICE, security, trace, and other graph-level responses.
6. Present the updated state clearly and ask for the next decision.

The exact turn structure may evolve, but movement must always consume an action, turn, or defined time unit. Traversal is never continuous locomotion.

## Player verbs

The baseline verbs are route selection, movement between connected hosts, scanning, infiltration, exploitation, program execution, threat avoidance, and retreat. Combat may exist as one form of program/security interaction, but aiming, twitch movement, platforming, and free-look navigation are not core verbs.

## Success criteria

A successful mission is understandable as a sequence of network decisions: find a route, gain required access, reach or manipulate an objective, and exit before security pressure becomes unacceptable. Readability and decision quality take priority over physical simulation.


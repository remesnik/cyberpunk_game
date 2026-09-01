# Movement Model

## Network topology

The traversable world is a graph:

- **Host/node:** a discrete location that can contain services, data, programs, ICE, security state, and mission objectives.
- **Connection/edge:** a directed or bidirectional route between two hosts. A connection may be known, hidden, locked, monitored, conditional, or differently weighted.
- **Occupant:** the player, ICE, and other mobile security entities each occupy a node and use graph connections to move.

Logical graph state is authoritative. Visual positions and animations are projections of that state and must never determine adjacency, reachability, or occupancy.

## Traversal rules

The player may move only from the current host to a host connected by a valid route. The player selects a route or destination and confirms the action. A successful traversal updates logical occupancy once and consumes an action, turn, or explicit amount of network time.

Traversal may be refused when a route is unavailable, undiscovered, access-controlled, or invalidated by current state. Such validation belongs to the logical movement system, not collision geometry.

Movement does not use velocity, gravity, jumping, collision-based navigation, or per-frame directional input. There is no meaningful position between hosts for baseline gameplay. A transition animation may visually connect two states, but cannot create additional movement states or alter the outcome.

## Time and other actors

After an action commits, the turn/time authority resolves consequences in a deterministic order. ICE and security entities operate on the same graph and obey explicit movement or action rules. They do not rely on 3D pathfinding or physical proximity.

The eventual rules must define:

- when movement cost is paid;
- when ICE and security act;
- how simultaneous arrivals or contested occupancy resolve;
- whether different connections have different time or risk costs;
- what information is revealed before confirmation;
- how cancellation, interruption, and retreat work.

These details are intentionally deferred. The invariant is that each committed graph traversal is a discrete, consequential action.

## Input intent

Input should express selections and commands, such as selecting an adjacent node, cycling available routes, confirming an action, cancelling, opening program controls, or inspecting the network. Input actions should describe gameplay intent rather than camera-relative directions.


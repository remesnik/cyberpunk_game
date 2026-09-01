# Display Model

## Purpose

The 3D presentation is an abstract, readable visualization of authoritative graph state. It should make topology, current location, known information, route status, threats, objectives, and security pressure easy to understand. It is not a physical level that owns gameplay state.

## Visual language

Hosts may appear as platforms, chambers, geometric structures, or luminous anchors in a dark void. Connections may appear as beams, tunnels, arcs, gates, or data paths. Programs, services, data stores, gateways, and ICE should use distinct silhouettes, colors, motion, and labels.

The synthetic style should favor grids, wireframes, procedural geometry, emissive materials, and deliberate color semantics. Depth, scale, animation, and camera motion can create atmosphere, but must preserve tactical clarity.

## State projection

The display layer reads graph and encounter state and presents it. For example:

- node visuals reflect discovered, current, compromised, objective, or alerted states;
- edge visuals reflect hidden, available, blocked, monitored, selected, or traversing states;
- entity visuals reflect their logical node occupancy and known status;
- UI communicates action cost, risk, trace impact, access requirements, and possible outcomes.

Scene nodes may retain presentation-only state such as animation progress, hover focus, camera framing, or temporary effects. They must not be the sole owner of host identity, adjacency, access, occupancy, trace, objectives, or security state.

## Camera and transitions

The camera is a presentation tool. It may frame the current host, show a local cluster, pull back to a network-board view, or animate along a selected route. The player does not steer it as a free-look traversal camera unless a later presentation mode explicitly calls for limited inspection.

Travel animation occurs after a logical move is validated or as part of its presentation. Animation duration must not imply free movement or allow collision-based interaction en route. Skipping or accelerating an animation must not change game state.

## Scene responsibility

Godot scenes compose views and reusable visual components. A separate logical model should eventually own the graph, turn/time progression, actors, and mission state. The display subscribes to state changes and emits user intent; an application/controller layer validates commands and updates the model.

The initial implementation is in `cyberspace/display/`. `NetworkDisplay` reads `NetworkGraph`, `PlayerNetworkPosition`, and `PlayerKnowledge`; `NodeVisual` and `LinkVisual` draw procedural presentation primitives. Clicking a visible neighboring host emits a traversal request through `Game`, while the display reacts to resulting events. No display object mutates graph topology or player position.

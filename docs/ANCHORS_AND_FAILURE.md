# Anchors and Failure

## Structural intent

Anchors, shortcuts, volatile-resource loss, and deep excursions create a cycle of preparation, risk, failure, return, and mastery over the network graph. They borrow structural tension from Souls-like games without importing melee combat, physical corpses, or real-time traversal.

Every rule operates on stable `NetworkNode` IDs. Scene transforms and visual objects are never authoritative.

## Anchors

An Anchor is a registered safe, controlled node. Activating one records it as a reconnect destination and can make it part of the fast-travel network. At an active Anchor the player may eventually:

- reconnect after forced disconnection;
- commit volatile data into stored resources;
- change equipped programs;
- store resources;
- recover session condition;
- fast travel between activated Anchors that permit it.

`AnchorController` owns Anchor definitions, activation, resource commitment, and logical fast travel. Fast travel directly changes `PlayerNetworkPosition` through a deliberate relocation operation; it is not movement through physical space.

## Shortcuts

A shortcut is a persistent change to an objective route. `ShortcutController` applies a named `ShortcutDefinition` once and records it as active. Supported forms describe their logical cause:

- a compromised router reduces routing overhead;
- an encrypted tunnel establishes a cheaper protected path;
- a stolen credential removes an identity barrier;
- an enabled gateway restores a disabled connection.

Activation may enable or unlock a link, reduce traversal cost, grant a credential, and commit the route to `PlayerKnowledge`. Visual changes merely communicate the authoritative routing mutation.

## Crash Cache

Volatile resources are separate from committed Anchor storage. On forced disconnect, `FailureRecoveryController`:

1. records the current node as the failure node;
2. removes all volatile resources from the player;
3. creates or replaces the single active `CrashCache` at that node ID;
4. reconnects the player at the most recently activated Anchor.

Returning to the exact cache node allows recovery into volatile storage and clears the cache. No corpse, dropped mesh, collision trigger, or 3D pickup exists. A later forced disconnect replaces the previous cache, whether or not its resources were recovered.

## Dangerous deep exploration

`DeepExplorationController` measures shortest logical link distance from the latest Anchor. It combines this depth with current trace to produce a deterministic risk score. Maximum reached depth is retained for diagnostics and future progression hooks.

Depth does not directly inflict arbitrary damage. It expresses structural exposure: more actions are required to return, more ICE updates can occur, accumulated volatile resources are at risk, and a crash cache may be harder to recover. Specific future network rules may add monitored regions, expensive links, limited recovery, or strategic pressure while preserving this graph-based foundation.

## Ownership boundaries

- `PlayerResourceState` owns volatile and committed resource counts.
- `AnchorController` owns safe-node activation and Anchor services.
- `ShortcutController` owns persistent routing changes.
- `FailureRecoveryController` owns disconnect/reconnect flow.
- `CrashCache` owns the one recoverable volatile-resource snapshot.
- `DeepExplorationController` derives depth and risk from graph state.
- `NetworkDisplay` may visualize all of the above through knowledge/events, but owns none of it.

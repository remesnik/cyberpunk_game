# Player Knowledge

## Separation from the world

`NetworkGraph` is the objective world: it owns real node identities, links, restrictions, and topology. `IceController` owns real ICE positions and states. Neither is a presentation model.

`PlayerKnowledge` is the only source used to decide what `NetworkDisplay` may reveal. It stores sanitized records rather than references to world definitions. A detected contact can therefore exist without containing a destination ID, hidden endpoint, lock state, faction, or security value.

The F3 debug overlay is the deliberate exception: it compares true world records with player knowledge for development verification. This information must not be used by normal gameplay UI.

## Knowledge levels

- `UNKNOWN`: no player-facing record exists.
- `DETECTED`: evidence exists, but identity and objective details are unavailable. Examples include an unknown node contact, signal fragment, or unknown security process.
- `IDENTIFIED`: identity and basic type are known.
- `SCANNED`: operational details such as security level, ownership, route cost, and restrictions may be shown.
- `COMPROMISED`: the entity is under sufficient player control to expose all information allowed by its eventual compromise rules.

Knowledge advances explicitly and does not regress automatically. Each entity category—nodes, links, and ICE—has an independent record and level.

## Display contract

`NetworkDisplay` asks for the sanitized current-node view and local contact list. It does not enumerate objective connected links. Unknown contacts receive synthetic contact IDs and generic labels. Only identified contacts include a usable destination ID; only scanned links include lock, disabled, cost, authority, or capability fields.

ICE knowledge follows the same rule. Signal or route activity can create observations without disclosing a process position. Exact detection can promote a process to identified and record its observed node, but that position becomes stale if the process moves unseen.

## Scanning

`SCAN` is a discrete action resolved by `ScanSystem`. Current-host scans cost one tick; adjacent targets include topology distance in their cost. Scan depth is calculated deterministically from scanner power, player capability, target security, existing knowledge, and topology distance. The structured `ScanResult` records depth, time, trace, discoveries, and events.

The scan system does not mutate UI or knowledge. After a successful player action, `Game` commits the result through `PlayerKnowledge`, and only then does `NetworkDisplay` rebuild from sanitized records. Current nodes, adjacent identified nodes, visible or detected links, detected local services, and detected ICE contacts are supported target categories. Player-signal targeting is reserved explicitly for a later slice.

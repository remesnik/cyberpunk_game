# Graph Progression

## The graph is the world

Progression changes which logical routes, hosts, information, and strategies are available. It does not grant jumping, climbing, or physical traversal abilities. Returning to an earlier router with a new capability can expose a branch, satisfy a protocol, reduce its practical risk, or create a shortcut through the network graph.

Capabilities describe coherent cyber operations:

- `DECRYPT`: satisfies supported encryption requirements.
- `SPOOF`: substitutes an accepted logical identity when a credential is unavailable.
- `GHOST`: supports low-observability actions.
- `ROOTKIT`: enables persistent privileged compromise.
- `BRIDGE`: connects incompatible network segments.
- `LEGACY_PROTOCOL`: communicates over obsolete services and routes.
- `DARK_ROUTE`: recognizes and uses concealed routing infrastructure.
- `TRACE_SCRAMBLER`: reduces trace pressure; security-heavy areas may be possible without it but strategically dangerous.
- `DEEP_SCAN`: increases scan power and reveals deeper topology or detail.

## Logical requirements

Nodes and links may require every capability in an `all` set. They may also define an `any` set combined with accepted credentials. For example, an identity gate can accept either `SPOOF` or an archive credential. Recommended capabilities express practical guidance without becoming hard locks; `TRACE_SCRAMBLER` belongs here for highly monitored regions.

Requirements must follow the fiction and system rules. A route requires `DECRYPT` because it uses supported encryption, not because its visual color is blue. A hidden legacy route requires `LEGACY_PROTOCOL` because modern clients cannot negotiate it. Display styling communicates the rule but never defines it.

## Acquisition and return loops

`GraphProgressionController` grants capabilities associated with logical locations and produces explicit acquisition events. It can also commit newly revealed shortcuts to `PlayerKnowledge`. The objective graph exists independently; unrevealed shortcut topology is never exposed by `NetworkDisplay`.

The progression test network demonstrates the intended loop:

1. Travel from the Anchor to an entry router.
2. Encounter an encrypted archive branch that requires `DECRYPT`.
3. Take an alternate route to a tool repository.
4. Acquire `DECRYPT` and return to the entry router.
5. Traverse the formerly inaccessible encrypted branch.
6. Reveal a one-way shortcut from the archive back toward the Anchor.

The fixture also includes an identity gate satisfied by either `SPOOF` or a valid credential, demonstrating logical alternatives rather than a colored-key lock.

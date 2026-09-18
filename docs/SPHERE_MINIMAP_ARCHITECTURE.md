# Sphere Minimap Architecture

The Sphere minimap is a tactical view of the player's current logical subnet. It does not own nodes, links, Sphere membership, Sleeve membership, SAN placement, trails, ICE positions, or objectives. Its dictionaries and node controls are disposable layout/render caches rebuilt from the systems below.

| Concern | Authority | Player-facing gate | Minimap use |
|---|---|---|---|
| Nodes and links | `NetworkGraph` | `PlayerKnowledge` node/link records | Draw only discovered topology in the current Sphere |
| Stable subnet membership | `SphereDefinition` and node `sphere_id` | Known node existence | Select the current map and retain historical Sleeve members |
| Current protection | `SecuritySleeve` | Known Sleeve observations | Draw a subordinate, optional overlay; never filter Sphere nodes |
| Player position | `PlayerNetworkPosition` | Always known locally | Draw the primary current-location marker and determine current Sphere |
| Deck connection | `SystemAccessNodeController` | Local SAN record in `PlayerKnowledge` | Draw the SAN marker at its current host |
| Hacker movement | `HackerTrailSystem` | Trail visibility rules | Draw permitted recent segments with authoritative decay |
| ICE | ICE simulation | Current/stale `PlayerKnowledge` observations | Draw current or last-known markers without querying true ICE position |
| Mission targets | Mission/story systems | Discovered objective capability in `PlayerKnowledge` | Draw a persistent objective marker |

## Invariants

- A Sphere is stable subnet membership, including nodes that share or historically shared its original Security Sleeve. Breaking, splitting, bypassing, disabling, or restoring a Sleeve changes only the protection overlay.
- `SphereMinimapCanvas.visible_node_ids()` intersects current-Sphere membership with player knowledge. Hidden nodes reserve no player-facing layout slots. Known nodes with unknown level use the shared UNKNOWN style; known levels use the same configured `NodeLevelStyle` resources as the primary graph.
- Player, SAN, objective, ICE, exit, and alert markers are additive. They never replace security-level appearance.
- Cross-Sphere links terminate at boundary markers. Entering the destination changes `PlayerNetworkPosition`, which causes the minimap to rebuild for the new Sphere rather than drawing both Spheres.
- Minimap activation emits a focus request only. It never calls traversal, spends actions, changes position, or unlocks links.
- Dense Spheres use semantic LOD: topology and critical markers remain, labels and minor dynamic detail reduce. Zoom and pan restore inspection detail without hiding arbitrary known nodes.

## Verification

`SphereMinimapDebug.tscn` is the interactive mutation lab. `SphereMinimapIntegrationPassTests.gd` checks the complete contract, while the focused minimap, trail, stale-information, mutation, and LOD suites isolate regressions in individual layers.

# Cyberspace Node Visualization

## Visual hierarchy

A network node is always represented by a hex. Security knowledge determines its base fill, border, and level glyph. Interaction states are overlays: hover adds a light outline, selection adds an amber outline, and the current location adds its own marker and restrained pulse. These overlays never replace the semantic base style.

The hex interior is intentionally sparse. CLOSE and MEDIUM views show a short node label; CLOSE may also show concise status. FAR shows the level glyph or unknown state without attempting to shrink long text into an unreadable label.

Hosted content is shown in perimeter sockets. It does not turn into graph destinations and does not replace the host node's appearance.

## Discovery rules

`NetworkNodeDefinition` contains objective world data. `PlayerKnowledge` contains what may be rendered. Visibility of a graph contact does not reveal security level, contents, services, or ICE.

The principal facts are independent:

- UNKNOWN: existence may be known while identity, level, and contents remain hidden.
- LEVEL KNOWN: security appearance can be learned through scanning, story intelligence, another hacker, or other sources without visitation.
- SCANNED: records that a scan occurred. A scan may reveal level, contents, both, or neither depending on its structured result.
- VISITED: records physical graph traversal and does not imply a full scan.

Unknown contents use an aggregate uncertainty indicator. Specific icons appear only after their categories enter player knowledge. Scan reveals compare previous and new sanitized views, animate only changed facts, and resolve immediately in reduced-animation mode.

## Icon taxonomy

The shared capability catalog defines IO, FEED, DATASTORE, DATABASE, MEAT SPACE, COMMUNICATIONS, CONTROL, SECURITY, ICE, SOFTWARE, CREDENTIALS, ACTIVE PROCESS, SAN, and OBJECTIVE.

Capabilities are derived from discovered services and hosted entities. They are not stored as camera/database/door booleans. Repeated discovered services aggregate into one category with a count at CLOSE detail. Generic SECURITY and current known ICE occupancy are separate categories. SAN and OBJECTIVE are hosted state and never alter the underlying security style.

## Security rendering

Unknown security uses the configured neutral-grey style and `L?`. Known levels use `NodeLevelStyle` resources containing fill, border, accessible glyph, name, and intensity. Color is never the only signal: known levels retain `L0`–`L5` glyphs. Selection, hover, current location, SAN, and objective state are additive markers.

## Perimeter sockets

Each hex has 12 deterministic sockets, approximately two per side. Icons remain upright and outside the border. The capability catalog supplies stable priority and preferred socket values; collision resolution walks sockets in a deterministic order. Empty sockets are not drawn.

SAN has highest priority, followed by objective and security-related information. Counts represent only discovered instances. Socket hitboxes remain fixed while visual pulses and scan effects draw around them.

## Zoom and level of detail

LOD is selected from zoom and visible-node density using `CyberspaceVisualizationConfig`:

- CLOSE: short label, concise status, all discovered categories, and aggregate counts.
- MEDIUM: short label and major capability categories; status and counts are removed.
- FAR: security hex/glyph plus SAN, OBJECTIVE, and known ICE only.

FAR mode filters information rather than uniformly shrinking every UI element. Hex size reduces moderately, important glyphs retain readable size, and links become thinner and fainter. Dense neighborhoods use deterministic cell placement rather than placing every contact on one ring. Mouse-wheel LOD adjustment is limited to the graph canvas.

## Debug scene

Run `res://debug/visualization/NodeVisualizationLab.tscn` directly from the Godot editor. Its live specimen toggles player knowledge, level, scan state, capability discovery, SAN, ICE, objective, compromise, reduced animation, and zoom. Fixed reference specimens make the primary visual states comparable on one screen.

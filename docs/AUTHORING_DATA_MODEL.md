# Authoring Data Model

`CyberspaceContentDocument` is a versioned native Godot Resource containing structured authored definitions. It lives under `res://data/authoring/`, outside the editor addon, and can be loaded headlessly with the plugin disabled. Runtime code never imports addon classes.

The document stores collections for network nodes and links, services, graffiti, flavor text, story hooks and bundles, physical locations and devices, realtime endpoints, comms, video, alarms, teams and operations, equipment, vendors, orders, and realtime events. Entries use stable IDs and structured dictionaries. Conditions use operator/type/reference/value fields; actions use type/target/value fields. Neither accepts executable script strings or NodePaths.

Cross-domain relationships are IDs:

`NetworkNode -> Service -> RealtimeEndpoint -> Process/Device -> MeatspaceLocation`

Graph screen coordinates are deliberately absent. `AuthoringEditorState`, stored in a separate `.editor_state.tres`, owns graph positions, zoom, scroll, selection, active workspace, and preview configuration. Changing layout cannot alter runtime topology.

The proof document is [server_facility_infiltration.tres](../data/authoring/server_facility_infiltration.tres). Its companion layout Resource is editor-only. Realtime definitions contain seconds, conditions, actions, and process IDs; they never reference `CyberspaceClock`.

PlayerKnowledge previews derive a sanitized subset from discovery fields. `TRUE WORLD` may inspect every definition, while player profiles must filter nodes, endpoints, processes, and hidden links before presentation. Preview state is transient editor state and is never saved into the gameplay document.

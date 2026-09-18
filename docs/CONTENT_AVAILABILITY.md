# Content Availability

`ContentAvailability` is the central mode-gating boundary for missions, contracts, dialogue, events, locations, tutorials, vendors, encounters, and jobs. Call `Game.is_content_available(content_id)` or `Game.resolve_content_id(content_id)` instead of comparing the current game mode in each consumer.

Availability rules are:

- `AVAILABLE_IN_ALL_MODES`: shared simulation or content available in both modes.
- `STORY_ONLY`: authored campaign content.
- `FREE_ROAM_ONLY`: sandbox-only content such as its home entry and generated-job surfaces.
- `MODE_SPECIFIC_VARIANT`: a logical content ID resolves to a separately authored variant for each mode.

`CyberspaceContentDocument.availability` supplies the default for every entry in that document. An individual entry can override it with its own `availability` and optional `mode_variants` fields. FIRST_CONTACT explicitly declares `STORY_ONLY`; it is not loaded in Free Roam and its dialogue is not merely hidden.

Tutorial entry policy is separate from tutorial content. Story Mode selects `FIRST_CONTACT` automatically. Free Roam first offers `RUN INTRODUCTION?`; declining enters `FREE_ROAM_HOME`, while accepting selects the Free-Roam-only `FIRST_CONTACT_FREE_ROAM_TUTORIAL` wrapper. That wrapper reuses FIRST_CONTACT's graph, Latch, and production mechanics but carries `campaign_progression_enabled = false` and returns to Free Roam afterward. It never populates campaign state.

Runtime bundles use the same boundary. A session may activate named bundles in its content profile; `Game.is_runtime_bundle_active()` verifies both that the bundle was selected and that it is eligible for the current mode. The legacy facility-operation prototype is Story-only and is no longer injected into authored Story sessions or Free Roam. Shared economy initialization remains available in both modes.

Authored network construction filters nodes, links, services, ICE definitions/instances, and hacker NPCs through entry eligibility. Links whose filtered endpoint is unavailable are omitted. The optional Free Roam introduction explicitly opts into reuse of the tutorial document; this is a declared wrapper policy, not an accidental campaign launch.

The existing structured prerequisite vocabulary also supports `ConditionDefinition.ConditionType.GAME_MODE` and the authoring condition editor exposes `GAME_MODE`. This is intended for a condition within otherwise shared content. Whole-content eligibility should use `ContentAvailability` so callers receive consistent fail-closed behavior.

Mode eligibility does not create separate gameplay implementations. Cyberspace traversal, Spheres, Security Sleeves, SANs, Doorstop, trails, ICE, hacking, realtime meat-space processes, programming, upgrades, and economy remain shared runtime systems.

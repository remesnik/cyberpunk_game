# Persistent Game Mode

`GameMode.Value` defines the explicit top-level modes `STORY` and `FREE_ROAM`. `Game.persistent_game_state` is the canonical owner during a running application. New-game mode confirmation writes this value before the frontend hands off to gameplay; missions, flags, tutorial progress, and save-slot names are never used to infer it.

Runtime queries are `Game.get_game_mode()`, `Game.is_story_mode()`, and `Game.is_free_roam_mode()`. Systems should use these only where mode policy genuinely differs, rather than scattering story-content checks.

`PersistentGameState` serializes `schema_version`, `game_mode`, campaign state, and persistent player starter state, and provides JSON file helpers for the future aggregate save service. Save schema version 2 introduced the explicit mode field; schema version 3 adds campaign/player bootstrap data. A development save with version 1 or no `game_mode` migrates to `STORY`, because all saves predating this feature came from the authored campaign prototype. Unknown mode strings also fail safely to `STORY`.

## Story Mode bootstrap

Starting Story Mode initializes the main campaign, starter software inventory, credits, programming resources, and initial story flags as persistent data. The first pending entry is the authored meat-space `STORY_PROLOGUE`. Its bedroom interactions select the clan/play style and starter deck, allow an optional hardware adjustment, and establish the BBS request that unlocks `FIRST_CONTACT`. Runtime builds the tutorial graph and its SAN only after that handoff.

Story Mode does not replace or disable the simulation layer. Action/realtime clocks, graph traversal, scanning, ICE, trace, programs, meat-space managers, and other dynamic systems remain shared with Free Roam. Campaign missions, NPCs, gates, unlocks, and optional authored content are an additional orchestration layer.

## Free Roam bootstrap

Free Roam initializes an independent sandbox world state rather than loading campaign content with its dialogue hidden. Its persistent state includes the home deck location, known networks, dynamic-job board seeds, world flags, economy, reputation, starter hardware, unique program instances, and installed loadout. `campaign_state` remains empty, so mandatory campaign missions, narrative gates, and FIRST_CONTACT are bypassed cleanly.

The initial runtime domain is `MEATSPACE` at the home deck-management screen. The player can configure software, program utilities, upgrade hardware, and order equipment before explicitly connecting to the Public Mesh starter network. Entering that network uses the same graph, Sphere, Security Sleeve, SAN, Doorstop, trail, ICE, hacking, realtime, and economy implementations used elsewhere.

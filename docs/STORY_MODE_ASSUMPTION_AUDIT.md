# Story Mode Assumption Audit

## Corrected boundaries

| Area | Previous assumption | Current behavior |
| --- | --- | --- |
| Session bootstrap | The legacy facility-operation mission, Team Alpha, calls, cameras, alarms, timeline, pressure demo, and story hooks were created for every session. | They belong to the `FACILITY_OPERATION_PROTOTYPE` runtime bundle. The bundle is `STORY_ONLY` and must also be selected by the active content profile. |
| Mission/objective injection | `FacilityOperationMission` was selected from an indirect empty-world-state check. | It is created only when the eligible facility bundle is active. Free Roam receives no campaign objective controller. |
| Scripted physical scenario | `FacilityOperationScenario` used the same indirect check. | It is gated by the same bundle and cannot start in Free Roam. |
| Authored graph content | Loading a document instantiated every node, service, link, ICE actor, and hacker actor. | Runtime construction filters entries through `ContentAvailability`; links to unavailable endpoints are dropped. |
| Tutorial/NPC reuse | Reusing FIRST_CONTACT in Free Roam risked looking like an implicit campaign launch. | The optional introduction is an explicit `FREE_ROAM_ONLY` wrapper with `campaign_progression_enabled = false` and declared authored-content reuse. Declining it enters the sandbox directly. |
| Shared economy | Prototype delivery destinations included a campaign facility cache. | Shared vendors/equipment remain available in all modes and use neutral home/public delivery destinations. |
| Session reuse | Persistent manager nodes could retain scenario records from a previous session. | Scenario-owned manager registries and story routing state are cleared before the next content profile is populated. |

## Verified Free Roam behavior

- No campaign mission or facility scripted scenario is assigned.
- Facility-only realtime actors, forced calls, alarms, physical teams, scheduled events, and hooks are not created.
- FIRST_CONTACT and Latch appear only when the player explicitly accepts the optional introduction.
- SAN, trails, ICE, Spheres, Security Sleeves, programming, meat-space management, vendors, equipment, and economy remain shared.
- Generic systems do not require campaign flags to initialize or operate.

## Remaining assumptions / follow-up work

1. `Game.gd` still constructs the legacy facility prototype procedurally. It is now correctly gated, but it should eventually become an authored content bundle rather than bootstrap code.
2. Authored `story_sequences`, objectives, dialogue sessions, hooks, and completion actions are data and validation-ready, but the project still lacks one generic sequence executor that applies entry eligibility at every event dispatch. Any future executor must call `Game.is_content_available(entry_id)` before spawning dialogue, objectives, actors, or world mutations.
3. `NetworkDisplay.gd` contains a direct `PayrollMissionController.OBJECTIVE_RESOURCE` reference for crash-cache presentation. It does not start a campaign, but the UI should eventually consume a generic active-objective/resource interface.
4. Starter content registration currently lives in `Game._configure_content_availability()`. As the catalog grows, registrations should be loaded from authored manifests instead of expanding the bootstrap function.
5. `FacilityOperationMission` and its scenario remain concrete legacy classes. Their activation is safe, but future missions should use the generic authored objective/sequence path.

No generic NPC, vendor, network activity, economy, or simulation system was disabled as part of this audit.

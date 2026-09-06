# Team Status

Team Status is a view over `PhysicalTeamKnowledge` and player-known remote-hacker records. It does not inspect authoritative hidden actor state.

Its default compact roster contains only a callsign/name, a tactical state, and critical emphasis. Physical-team states are reduced to useful summaries such as READY, BUSY, HOLD, ENGAGED!, TRACE!, DOWN, and CLEAR. Known allied hacker connections use ONLINE or SIGNAL LOST. Hostile or undiscovered hackers are excluded.

Selecting an entry expands the existing detailed team telemetry, objective, route-decision, and recording controls, or the known remote-hacker details. When no relevant entries exist, the entire Team Status control is hidden.

Important structured events temporarily surface the compact control even when no roster is currently shown. Detection, attack, SAN breach, Dump, communications loss, objective completion, and critical hardware damage use `EventBus.tactical_status_alert`; action results carrying the same event types are also adapted. Alerts queue, expire independently, and never force detailed status open. After the queue clears, the normal compact roster—or nothing when the roster is empty—returns.

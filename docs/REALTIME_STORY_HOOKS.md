# Realtime StoryHooks

`RealtimeStoryRouter` is the boundary between objective meatspace simulation and authored narrative reactions. Runtime managers publish semantic facts; StoryHooks consume the normalized history. Hooks never inspect widgets, monitor visibility, button state, or audio playback nodes.

The supported structured event types are:

- `COMMS_INTERCEPTED`
- `COMMS_RECORDED`
- `HEARD_COMMS_EVENT`
- `VIDEO_OBSERVED`
- `VIDEO_EVENT_SEEN`
- `ALARM_TRIGGERED`
- `ALARM_BYPASSED`
- `TEAM_REACHED_LOCATION`
- `TEAM_LOST`
- `TEAM_SUCCESS`
- `EQUIPMENT_DELIVERED`
- `REALTIME_EVENT_OCCURRED`

Each `StoryEvent` contains a stable event ID, type, source ID, realtime timestamp, structured payload, and story tags. COMMS transcript definitions may include a semantic `event_id`; this lets authored conditions react to meaning such as `MENTION_LOADING_DOCK` without parsing rendered transcript text or checking whether an audio node is playing. `VIDEO_EVENT_SEEN` is emitted only when an authored feed event occurs while that feed is being observed through the runtime video manager.

`ConditionDefinition.STORY_EVENT_OCCURRED` searches accumulated story facts by event type and optional source/payload filters. Multiple conditions on a hook are ALL conditions. Hooks are one-shot initially and activate only when their trigger matches the newest event and every condition is satisfied.

Hook effects are structured action dictionaries. The router emits each action and sends it only to a registered handler. Initial game handlers support `REVEAL_NODE`, `ADD_GRAFFITI`, and `SEND_MESSAGE`; unsupported action types remain visible to tooling without being executed. This keeps narrative authoring extensible while preventing hooks from reaching directly into presentation code.

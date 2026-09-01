# Evidence Recording

`EvidenceArchive` stores recordings made from discovered meatspace streams. Objective VIDEO, COMMS, RADIO, alarm, and team systems remain authoritative; the archive receives only the structured content exposed by an authorized recording provider.

An `EvidenceRecord` identifies its source, records realtime start and end timestamps, and preserves placeholder content as timed events. Transcript lines, authored video events, alarm history, and team telemetry can therefore use the same archive without requiring media assets. `content_reference` is intentionally a structured reference so a future implementation can point to saved audio/video media without changing story-facing code.

The supported source categories are VIDEO, COMMS, RADIO, ALARM LOG, and TEAM TELEMETRY. Radio channels use the existing comms interception pipeline but retain their distinct evidence source type.

Recordings use `RealtimeWorldClock`; cyberspace actions and ticks do not alter their timestamps or skip captured events. Soft pause continues recording, while hard pause freezes the source clock according to `PausePolicy`.

Evidence may be reviewed, marked important, analyzed, shared with an authored recipient, or associated with a StoryHook. Initial analysis is deliberately lightweight: authored rules match phrases in structured recorded content and return StoryHook IDs and tags. These operations update archive metadata and emit signals; they do not implement a forensic minigame or directly execute arbitrary story effects.

Discovery remains mandatory. The game-facing alarm and team recording commands verify that the associated realtime process is present in `PlayerKnowledge`. COMMS and VIDEO continue to use their existing access validation before opening an evidence record.

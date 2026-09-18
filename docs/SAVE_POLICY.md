# Save Policy

Normal saves are a meat-space operation. `Game.request_meatspace_autosave(reason)` is the single autosave entry point, backed by `MeatspaceAutosaveService`. Calls made while the game domain is cyberspace fail with `ERR_UNAUTHORIZED`; actions, traversal, ticks, scans, exploits, and program execution never invoke the service.

Every legitimate cyberspace-to-meat-space transition must use `Game.enter_meatspace(reason, metadata)`. Normal Jack Out, Doorstop suspension, and completed-intrusion return use `NORMAL_JACK_OUT`, `DOORSTOP_EXIT`, and `MISSION_COMPLETE` respectively. Other transitions use `RETURN_TO_MEATSPACE`. The transition changes domain, emits the domain event, synchronizes live runtime state into `PersistentGameState`, and updates `user://saves/current_autosave.json`.

The snapshot includes explicit game mode, existing campaign/world progression, inventory and unique program instances, installed loadout, deck hardware, credits and programming resources, realtime programming tasks, player network knowledge, intrusion lifecycle/resume data, trace, current meat-space state, reputation, hardware damage, and other persistent player fields. Fields with no active runtime owner remain preserved rather than being discarded.

Doorstop re-entry is intentionally not an autosave point because it enters cyberspace. The next save occurs only after a later legitimate return to meat space.

## Game Over recovery

`Game.trigger_game_over()` marks an active intrusion failed, terminates the runtime session, and emits the presentation event. It never synchronizes or writes state. The Game Over overlay offers Continue; `Game.continue_from_game_over()` validates and loads `current_autosave.json`, then reconstructs the saved meat-space runtime. Consequently, changes made after the last meat-space entry—including node position, ticks, commands, trace, and unsaved loot—are discarded.

If the autosave is missing or invalid, Continue creates the normal start state for the mode that failed and explicitly reports that fallback. Debug snapshots are outside this normal-save policy.

## Doorstop recovery audit

Deploying Doorstop remains a cyberspace program action and does not save. Its successful Jack Out enters meat space and therefore creates the normal autosave. Synchronization happens after the selected Doorstop instance burns and after the intrusion becomes `SUSPENDED_AT_DOORSTOP`, so the snapshot contains no consumed copy and does contain the suspended intrusion, exact anchor/SAN host, resume state, knowledge, trace, loot, and programming queue.

Loading that autosave rebuilds one intrusion, one SAN, and one Doorstop anchor from stable IDs. It restores the saved inventory and task records instead of merging them into a newly generated collection. If Game Over occurs after re-entry, Continue returns to this suspended meat-space state; it does not recover the later cyberspace position or create a second Doorstop, SAN, loot grant, task, or intrusion.

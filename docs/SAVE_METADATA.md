# Save Metadata

Every `PersistentGameState` save stores `game_mode` directly as `STORY` or `FREE_ROAM`. Mode is never inferred from the save ID, filename, mission, tutorial flags, or network name.

Presentation-safe `save_metadata` contains the save ID, known network/location labels, playtime seconds, save timestamp, and resumable state. `FrontendSaveSummary.from_save_data()` migrates the full state first, then copies its explicit mode into the frontend record.

The load browser renders save ID, mode label, known network/location context, and `HH:MM:SS` playtime. Continue and Load use `PersistentGameSaveProvider`, which asks `Game.load_persistent_state()` to restore the serialized state before handing off to gameplay. They do not call either new-game initializer.

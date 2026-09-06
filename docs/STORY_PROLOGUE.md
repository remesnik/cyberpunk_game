# Story Mode prologue

Story Mode now begins with `STORY_PROLOGUE` in the player's bedroom rather than creating the FIRST_CONTACT intrusion immediately. The temporary narrative content is stored in `res://data/authoring/story_prologue.tres`; the reusable runtime interpretation lives in `MeatspacePrologueController`, and `StoryPrologueScreen` only renders its current interactions and choices.

The authored sequence opens the starter box, chooses More slots or More storage, optionally spends ICs on a toolbox hardware change, performs the fictional Jack In, connects to a local BBS, and asks for a guide. The final choice sets `LATCH_CONTACTED`, unlocks FIRST_CONTACT, and hands control to the existing authored intrusion. Only that handoff creates the real NetworkGraph, hacker actors, intrusion session, and System Access Node.

Interactions use stable IDs, phases, prerequisite flags, authored choice text, and generic actions such as `SET_FLAG`, `SET_PLAYER_FIELD`, `SET_HARDWARE`, `MODIFY_HARDWARE`, `SET_LOADOUT`, `SPEND_CREDITS`, and `COMPLETE_PROLOGUE`. The scene contains no fixed clan, deck, BBS, or dialogue sequence. Replacing the temporary story therefore requires data changes rather than a bedroom-scene rewrite.

The prologue modifies the normal `PersistentGameState` inventory, credits, hardware, and installed-program fields. FIRST_CONTACT reconstructs its production `ProgramInventory`, `ProgramLoadout`, and meat-space management systems from those fields, so the selected deck is not a parallel tutorial-only loadout.

## 3D room presentation

`PlayerBedroom` now builds a real Node3D world inside an isolated SubViewport. The Control root only embeds that rendered world in the existing Story Mode UI. A fixed perspective Camera3D frames three walls, with the bed on the left, desk and posters at the back, and table and bookshelf on the right. Furniture uses modest multi-part meshes; posters are PNG-textured QuadMesh surfaces. No movement controller is required.

`MeatspaceRoomView3D` provides reusable camera-ray picking, keyboard selection (left/right and accept), contextual hover text, and state subscription cleanup. Each `MeatspaceTarget3D` Area3D carries the same authored object ID and data previously used by the 2D view. Selection emits `object_selected` to the existing `StoryPrologueScreen` phase mapping and `MeatspacePrologueController`; the 3D view never executes story actions.

Authored `visual_state` dictionaries map visual keys to persistent story flags. The generic target applies bindings to node properties: `open` rotates a container lid, and `equipped` controls equipment visibility. The starter box opens with `BOX_OPEN`, disappears with `DECK_SELECTED`, and reveals the computer. The toolbox lid uses `TOOLBOX_OPEN`; `TOOLBOX_USED` prevents repeat upgrades. A fresh game resets all bindings. Loading a save or returning to the room reconstructs visuals from `PersistentGameState`, without a second room save format. Additional stateful props can bind other properties and authored flags using the same adapter.

Poster placeholders can be regenerated with `powershell -ExecutionPolicy Bypass -File tools/art/generate_bedroom_posters.ps1`. Run `Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/PlayerBedroomTests.tscn` for mapping, perspective projection, ray/click dispatch, authored choices, save roundtrip, unload cleanup, and reentry coverage.


## Interactive Meatspace prototype

An authored phase migration moves old saves at the former clan-selection opening to deck selection without resetting their currency or other player state. Fresh Story Mode starts at deck selection with **25 ICs** in the normal persistent `credits` field. Posters are flavor scenery; no clan selection is required to open the box. The computer stays hidden and unpickable until `DECK_SELECTED`, which hides the box. The two choices retain stable internal deck IDs for loadout compatibility; their player-facing labels are exactly **More slots** and **More storage**. These are alternative supplied starter decks with different built-in hardware, not upgrades. Choosing one costs no ICs, and the starter selection shows no price labels.

Hover shows authored `examine` text. Click dispatches `primary_action` to either the first currently available non-examine physical action or the current authored story interaction. The old action bar and time selector are hidden. Keyboard left/right cycles visible targets and Enter activates them. Room rendering takes about 90% of the gameplay area; choices appear only when requested.

The existing toolbox options remain **FIT SPARE MEMORY** (75 ICs) and **CLOSE THE CASE** (0 ICs). Choice costs, required flags and one-time purchase flags are authored data. The UI refreshes affordability on state changes; the controller validates again before charging and applying effects. Opening the toolbox before selecting a deck shows unavailable options, with Back to Room always available.

The two tall windows have separate state flags. The wider window opens onto the right wall above the table. Both expose the same lightweight exterior presentation and entry-relative train event. Opening either window removes the shared exterior low-pass/attenuation, including the train. Story code controls DAY, DUSK, NIGHT and DAWN through persistent `world_state.time_of_day`; sleep advances the existing four-period time abstraction and reduces Fatigue by 60.

The existing city/utility beds are joined by three original, free 60-second synthesized layers: rooftop wind, distant traffic with occasional horn tones, and electrical ambience. Each profile authors independent gains. See `assets/meatspace/audio/PROVENANCE.md`; these are prototype synthesis, not field recordings. The user's existing train audio is preserved. Its authored ten-second pass starts 20 seconds after entry, stops cleanly, and restarts on reentry. Sound and visuals cancel on exit, including exits before the deadline.

Verification scenes: `MeatspacePrototypeTests`, `PlayerBedroomTests`, and `StoryPrologueIntegrationTests`. The prototype test accepts `-- --capture` with graphical Godot to write `.godot/meatspace-{day,dusk,night,dawn}.png`. These cover picking/hover, direct actions, deck variants and cost validation, IC initialization, toolbox availability, independent window persistence, time/audio profiles, train lifecycle, save restoration, and the real FIRST_CONTACT handoff.

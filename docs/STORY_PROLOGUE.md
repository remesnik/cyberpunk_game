# Story Mode prologue

Story Mode now begins with `STORY_PROLOGUE` in the player's bedroom rather than creating the FIRST_CONTACT intrusion immediately. The temporary narrative content is stored in `res://data/authoring/story_prologue.tres`; the reusable runtime interpretation lives in `MeatspacePrologueController`, and `StoryPrologueScreen` only renders its current interactions and choices.

The authored sequence selects a clan/play style, chooses a starter deck configuration, optionally spends credits on a toolbox hardware change, performs the fictional Jack In, connects to a local BBS, and asks for a guide. The final choice sets `LATCH_CONTACTED`, unlocks FIRST_CONTACT, and hands control to the existing authored intrusion. Only that handoff creates the real NetworkGraph, hacker actors, intrusion session, and System Access Node.

Interactions use stable IDs, phases, prerequisite flags, authored choice text, and generic actions such as `SET_FLAG`, `SET_PLAYER_FIELD`, `SET_HARDWARE`, `MODIFY_HARDWARE`, `SET_LOADOUT`, `SPEND_CREDITS`, and `COMPLETE_PROLOGUE`. The scene contains no fixed clan, deck, BBS, or dialogue sequence. Replacing the temporary story therefore requires data changes rather than a bedroom-scene rewrite.

The prologue modifies the normal `PersistentGameState` inventory, credits, hardware, and installed-program fields. FIRST_CONTACT reconstructs its production `ProgramInventory`, `ProgramLoadout`, and meat-space management systems from those fields, so the selected deck is not a parallel tutorial-only loadout.

## 3D room presentation

`PlayerBedroom` now builds a real Node3D world inside an isolated SubViewport. The Control root only embeds that rendered world in the existing Story Mode UI. A fixed perspective Camera3D frames three walls, with the bed on the left, desk and posters at the back, and table and bookshelf on the right. Furniture uses modest multi-part meshes; posters are PNG-textured QuadMesh surfaces. No movement controller is required.

`MeatspaceRoomView3D` provides reusable camera-ray picking, keyboard selection (left/right and accept), contextual hover text, and state subscription cleanup. Each `MeatspaceTarget3D` Area3D carries the same authored object ID and data previously used by the 2D view. Selection emits `object_selected` to the existing `StoryPrologueScreen` phase mapping and `MeatspacePrologueController`; the 3D view never executes story actions.

Authored `visual_state` dictionaries map visual keys to persistent story flags. The generic target applies bindings to node properties: `open` rotates a container lid, and `equipped` controls equipment visibility. The starter box and table use `DECK_SELECTED`; the toolbox uses `TOOLBOX_USED`. A fresh game resets all bindings. Loading a save or returning to the room reconstructs visuals from `PersistentGameState`, without a second room save format. Additional stateful props can bind other properties and authored flags using the same adapter.

Poster placeholders can be regenerated with `powershell -ExecutionPolicy Bypass -File tools/art/generate_bedroom_posters.ps1`. Run `Godot_v4.7-stable_win64_console.exe --headless --path . --scene res://tests/PlayerBedroomTests.tscn` for mapping, perspective projection, ray/click dispatch, authored choices, save roundtrip, unload cleanup, and reentry coverage.


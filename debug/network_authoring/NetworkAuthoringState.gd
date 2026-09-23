class_name NetworkAuthoringState
extends RefCounted

## Temporary debug-session state. This is deliberately not part of a saved
## network document or runtime gameplay state.
enum Mode { PLAYER, AUTHOR_GOD, AUTHOR_TEST }

var mode := Mode.PLAYER

func is_authoring() -> bool:
	return mode != Mode.PLAYER

func is_god() -> bool:
	return mode == Mode.AUTHOR_GOD

func label() -> String:
	return Mode.keys()[mode]

class_name PlayerOperationCatalog
extends RefCounted

const SCAN := &"SCAN"
const ENUMERATE := &"ENUMERATE"
const BYPASS := &"BYPASS"
const AUTHENTICATE := &"AUTHENTICATE"
const SPOOF := &"SPOOF"
const READ := &"READ"
const MONITOR := &"MONITOR"
const SEARCH := &"SEARCH"
const DOWNLOAD := &"DOWNLOAD"
const UPLOAD := &"UPLOAD"
const EDIT := &"EDIT"
const DELETE := &"DELETE"
const ACTIVATE := &"ACTIVATE"
const DEACTIVATE := &"DEACTIVATE"
const INTERCEPT := &"INTERCEPT"
const INJECT := &"INJECT"
const REDIRECT := &"REDIRECT"
const UNLOCK := &"UNLOCK"
const LOCK := &"LOCK"
const ENCRYPT := &"ENCRYPT"
const DECRYPT := &"DECRYPT"
const SCRUB := &"SCRUB"
const FORGE := &"FORGE"
const SUPPRESS := &"SUPPRESS"
const DISABLE := &"DISABLE"
const REQUEST := &"REQUEST"
const RUN_PROGRAM := &"RUN_PROGRAM"
const INSTALL_UTILITY := &"INSTALL_UTILITY"
const UNLOAD_UTILITY := &"UNLOAD_UTILITY"

const ALL: Array[StringName] = [SCAN, ENUMERATE, BYPASS, AUTHENTICATE, SPOOF, READ, MONITOR, SEARCH, DOWNLOAD, UPLOAD, EDIT, DELETE, ACTIVATE, DEACTIVATE, INTERCEPT, INJECT, REDIRECT, UNLOCK, LOCK, ENCRYPT, DECRYPT, SCRUB, FORGE, SUPPRESS, DISABLE, REQUEST, RUN_PROGRAM, INSTALL_UTILITY, UNLOAD_UTILITY]

static func normalize(value: Variant) -> StringName:
	return StringName(String(value).strip_edges().to_upper().replace("/", "_").replace(" ", "_"))

static func is_supported(value: Variant) -> bool:
	return ALL.has(normalize(value))

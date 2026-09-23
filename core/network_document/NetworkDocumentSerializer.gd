class_name NetworkDocumentSerializer
extends RefCounted

static func serialize(document: NetworkDocument) -> PackedByteArray:
	return JSON.stringify(_canonical(document.to_dict()), "  ", true).to_utf8_buffer()

static func deserialize(data: PackedByteArray) -> NetworkDocument:
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	return NetworkDocument.from_dict(parsed) if parsed is Dictionary else null

static func save_file(document: NetworkDocument, path: String) -> Dictionary:
	var issues := document.validate()
	if not issues.is_empty(): return {"success": false, "error": ERR_INVALID_DATA, "issues": issues}
	if path.get_extension().to_lower() != "netspace": path += ".netspace"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"success": false, "error": FileAccess.get_open_error(), "issues": [{"message": "Could not open '%s' for writing." % path}]}
	var package := NetworkPackageCodec.encode(serialize(document))
	if not bool(package.get("success", false)): file.close(); return {"success": false, "error": package.error, "issues": [{"message": package.message}]}
	file.store_buffer(package.data); file.close()
	return {"success": true, "error": OK, "issues": [], "path": path}

static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"success": false, "error": FileAccess.get_open_error(), "issues": [{"message": "Could not open '%s'." % path}]}
	var decoded := NetworkPackageCodec.decode(file.get_buffer(file.get_length())); file.close()
	if not bool(decoded.get("success", false)): return {"success": false, "error": decoded.error, "issues": [{"message": decoded.message}]}
	var document := deserialize(decoded.data)
	if document == null: return {"success": false, "error": ERR_PARSE_ERROR, "issues": [{"message": "Decrypted network document is invalid."}]}
	var issues := document.validate()
	return {"success": issues.is_empty(), "error": OK if issues.is_empty() else ERR_INVALID_DATA, "issues": issues, "document": document, "path": path}

static func save_plaintext_debug(document: NetworkDocument, path: String) -> Dictionary:
	if not OS.is_debug_build(): return {"success": false, "error": ERR_UNAUTHORIZED, "issues": [{"message": "Plaintext network export is debug-only."}]}
	var issues := document.validate()
	if not issues.is_empty(): return {"success": false, "error": ERR_INVALID_DATA, "issues": issues}
	if not path.ends_with(".netspace.json"): path = path.trim_suffix(".json").trim_suffix(".netspace") + ".netspace.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"success": false, "error": FileAccess.get_open_error(), "issues": [{"message": "Could not open plaintext diagnostic export."}]}
	file.store_buffer(serialize(document)); file.close()
	return {"success": true, "error": OK, "issues": [], "path": path}

static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}; var keys: Array = value.keys(); keys.sort_custom(func(a, b): return String(a) < String(b))
		for key in keys: result[String(key)] = _canonical(value[key])
		return result
	if value is Array:
		var result := []
		for item in value: result.append(_canonical(item))
		return result
	if value is StringName: return String(value)
	return value

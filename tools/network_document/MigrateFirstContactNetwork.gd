extends SceneTree

const SOURCE_PATH := "res://data/authoring/first_contact_current.tres"
const OUTPUT_PATH := "res://data/networks/first_contact.netspace"

func _initialize() -> void:
	var source := load(SOURCE_PATH) as CyberspaceContentDocument
	if source == null:
		push_error("First Contact migration could not load %s" % SOURCE_PATH)
		quit(1)
		return
	var document := NetworkDocument.from_content_document(source)
	var result := NetworkDocumentSerializer.save_file(document, OUTPUT_PATH)
	if not bool(result.get("success", false)):
		push_error("First Contact migration failed: %s" % JSON.stringify(result.get("issues", [])))
		quit(1)
		return
	print("Migrated %s -> %s (%d nodes, %d paths, %d services)" % [SOURCE_PATH, OUTPUT_PATH, document.nodes.size(), document.paths.size(), document.services.size()])
	quit(0)

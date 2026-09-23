class_name NetworkDocumentRuntimeLoader
extends RefCounted

static func build(document: NetworkDocument) -> Dictionary:
	var issues := document.validate()
	if not issues.is_empty(): return {"success": false, "issues": issues}
	var content := document.to_content_document()
	var graph := AuthoredNetworkRuntimeBuilder.build_graph(content)
	return {"success": true, "issues": [], "document": document, "content_document": content, "graph": graph, "player": AuthoredNetworkRuntimeBuilder.build_player(content, graph), "knowledge": AuthoredNetworkRuntimeBuilder.build_knowledge(content, graph)}

static func populate_ice(document: NetworkDocument, controller: IceController) -> void:
	AuthoredNetworkRuntimeBuilder.populate_ice(document.to_content_document(), controller)

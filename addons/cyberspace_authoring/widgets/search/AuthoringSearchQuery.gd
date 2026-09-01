@tool
extends RefCounted


func parse(query: String) -> Dictionary:
	var result := {"text": [], "filters": {}}
	for token in query.strip_edges().split(" ", false):
		var pair := token.split(":", true, 1)
		if pair.size() == 2: result.filters[pair[0].to_lower()] = pair[1].trim_prefix("\"").trim_suffix("\"")
		else: result.text.append(token)
	return result


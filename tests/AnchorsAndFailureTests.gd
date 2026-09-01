extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_anchor_commit_and_fast_travel()
	_test_persistent_shortcut()
	_test_single_crash_cache_and_recovery()
	_test_deep_exploration_risk()
	print("%s: %d anchor/failure assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_anchor_commit_and_fast_travel() -> void:
	var fixture := ProgressionTestNetworkFactory.create_fixture()
	var anchors := AnchorController.new(fixture.graph)
	anchors.register_anchor(AnchorDefinition.new(ProgressionTestNetworkFactory.ANCHOR, "Anchor"))
	anchors.register_anchor(AnchorDefinition.new(ProgressionTestNetworkFactory.TOOL_REPOSITORY, "Repository Anchor"))
	anchors.activate_anchor(ProgressionTestNetworkFactory.ANCHOR)
	anchors.activate_anchor(ProgressionTestNetworkFactory.TOOL_REPOSITORY)
	var resources := PlayerResourceState.new()
	resources.add_volatile(&"DATA", 12)
	var committed := anchors.commit_resources(ProgressionTestNetworkFactory.ANCHOR, resources)
	_expect(committed.DATA == 12 and resources.stored_resources.DATA == 12, "active anchor commits volatile resources")
	_expect(anchors.fast_travel(fixture.player, ProgressionTestNetworkFactory.TOOL_REPOSITORY), "fast travel works between activated anchors")

func _test_persistent_shortcut() -> void:
	var fixture := ProgressionTestNetworkFactory.create_fixture()
	var shortcuts := ShortcutController.new(fixture.graph)
	var link := fixture.graph.get_link(&"EARLY_ENCRYPTED_BRANCH") as NetworkLinkDefinition
	shortcuts.register_shortcut(ShortcutDefinition.new(&"COMPROMISE_ENTRY", ShortcutDefinition.ShortcutType.COMPROMISED_ROUTER, link.id, 1))
	_expect(shortcuts.activate(&"COMPROMISE_ENTRY", fixture.player, fixture.knowledge), "shortcut activation succeeds")
	_expect(link.traversal_cost == 1 and shortcuts.active_shortcut_ids.has(&"COMPROMISE_ENTRY"), "shortcut persistently reduces route cost")

func _test_single_crash_cache_and_recovery() -> void:
	var fixture := ProgressionTestNetworkFactory.create_fixture()
	var anchors := AnchorController.new(fixture.graph)
	anchors.register_anchor(AnchorDefinition.new(ProgressionTestNetworkFactory.ANCHOR, "Anchor"))
	anchors.activate_anchor(ProgressionTestNetworkFactory.ANCHOR)
	var resources := PlayerResourceState.new()
	resources.add_volatile(&"SHARDS", 7)
	fixture.player.relocate(ProgressionTestNetworkFactory.ENTRY_ROUTER)
	var failure := FailureRecoveryController.new(anchors, resources, fixture.player)
	_expect(failure.force_disconnect_at_current_node(9), "forced disconnect succeeds with an active anchor")
	_expect(failure.crash_cache.active and failure.crash_cache.node_id == ProgressionTestNetworkFactory.ENTRY_ROUTER, "cache remains at failure node ID")
	_expect(fixture.player.current_node_id == ProgressionTestNetworkFactory.ANCHOR and resources.volatile_resources.is_empty(), "player reconnects at anchor without volatile resources")
	_expect(failure.recover_at(ProgressionTestNetworkFactory.ANCHOR).is_empty(), "cache cannot be recovered from another node")
	fixture.player.relocate(ProgressionTestNetworkFactory.ENTRY_ROUTER)
	var recovered := failure.recover_at(ProgressionTestNetworkFactory.ENTRY_ROUTER)
	_expect(recovered.SHARDS == 7 and not failure.crash_cache.active, "returning to failure node recovers and clears cache")
	resources.add_volatile(&"DATA", 2)
	fixture.player.relocate(ProgressionTestNetworkFactory.TOOL_REPOSITORY)
	failure.force_disconnect_at_current_node(12)
	_expect(failure.crash_cache.node_id == ProgressionTestNetworkFactory.TOOL_REPOSITORY, "new failure replaces the single active cache")

func _test_deep_exploration_risk() -> void:
	var fixture := ProgressionTestNetworkFactory.create_fixture()
	var anchors := AnchorController.new(fixture.graph)
	anchors.register_anchor(AnchorDefinition.new(ProgressionTestNetworkFactory.ANCHOR, "Anchor"))
	anchors.activate_anchor(ProgressionTestNetworkFactory.ANCHOR)
	var exploration := DeepExplorationController.new(fixture.graph, anchors, fixture.player)
	fixture.player.relocate(ProgressionTestNetworkFactory.ENTRY_ROUTER)
	var near := exploration.update(0)
	fixture.player.relocate(ProgressionTestNetworkFactory.TOOL_REPOSITORY)
	var deep := exploration.update(5)
	_expect(deep.depth > near.depth and deep.risk_score > near.risk_score, "risk rises with graph depth and trace")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)

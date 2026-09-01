class_name TestIceFactory
extends RefCounted

static func populate(controller: IceController) -> void:
	var sentinel_route: Array[StringName] = [TestNetworkFactory.SECURITY_SERVER, TestNetworkFactory.AUTH_SERVER, TestNetworkFactory.ROUTER_A, TestNetworkFactory.AUTH_SERVER]
	var sentinel := IceDefinition.new(&"SENTINEL", "Sentinel ICE", 1, 2, 2, sentinel_route)
	controller.add_ice(IceInstance.new(&"SENTINEL_01", sentinel, TestNetworkFactory.SECURITY_SERVER, IceState.Value.DORMANT))

	var watcher_route: Array[StringName] = [TestNetworkFactory.WORKSTATION_01, TestNetworkFactory.ROUTER_A, TestNetworkFactory.WORKSTATION_02, TestNetworkFactory.ROUTER_A]
	var watcher := IceDefinition.new(&"WATCHER", "Watcher Process", 1, 3, 1, watcher_route)
	controller.add_ice(IceInstance.new(&"WATCHER_01", watcher, TestNetworkFactory.WORKSTATION_01, IceState.Value.PATROL))

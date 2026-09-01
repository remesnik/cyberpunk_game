class_name CapabilityCatalog
extends RefCounted

const DECRYPT := &"DECRYPT"
const SPOOF := &"SPOOF"
const GHOST := &"GHOST"
const ROOTKIT := &"ROOTKIT"
const BRIDGE := &"BRIDGE"
const LEGACY_PROTOCOL := &"LEGACY_PROTOCOL"
const DARK_ROUTE := &"DARK_ROUTE"
const TRACE_SCRAMBLER := &"TRACE_SCRAMBLER"
const DEEP_SCAN := &"DEEP_SCAN"

static func create_definitions() -> Dictionary:
	return {
		DECRYPT: CapabilityDefinition.new(DECRYPT, "Decrypt", "Breaks supported cryptographic route and host barriers."),
		SPOOF: CapabilityDefinition.new(SPOOF, "Spoof", "Presents an accepted logical identity when credentials are unavailable."),
		GHOST: CapabilityDefinition.new(GHOST, "Ghost", "Reduces observable activity during supported actions.", &"STEALTH"),
		ROOTKIT: CapabilityDefinition.new(ROOTKIT, "Rootkit", "Enables persistent privileged compromise of compatible systems.", &"CONTROL"),
		BRIDGE: CapabilityDefinition.new(BRIDGE, "Bridge", "Joins otherwise incompatible network segments.", &"ROUTING"),
		LEGACY_PROTOCOL: CapabilityDefinition.new(LEGACY_PROTOCOL, "Legacy Protocol", "Communicates across obsolete routes and services.", &"ROUTING"),
		DARK_ROUTE: CapabilityDefinition.new(DARK_ROUTE, "Dark Route", "Recognizes and traverses concealed network paths.", &"ROUTING"),
		TRACE_SCRAMBLER: CapabilityDefinition.new(TRACE_SCRAMBLER, "Trace Scrambler", "Mitigates trace pressure in monitored regions.", &"STEALTH"),
		DEEP_SCAN: CapabilityDefinition.new(DEEP_SCAN, "Deep Scan", "Reveals topology and detail beyond standard scanner depth.", &"SCANNING"),
	}

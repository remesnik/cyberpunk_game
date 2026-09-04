class_name NodeCapabilityIconTheme
extends Resource

enum PaletteRole { STANDARD, PHYSICAL, SECURITY, HOSTILE, LOCAL_LINK, OBJECTIVE }

@export var standard_color := Color("9cb3bb")
@export var physical_color := Color("c0aa79")
@export var security_color := Color("c18d72")
@export var hostile_color := Color("d05e69")
@export var local_link_color := Color("b9c7db")
@export var objective_color := Color("d4b766")
@export var uncertainty_color := Color("89959b")
@export var background_color := Color(0.025, 0.035, 0.045, 0.96)
@export var line_width := 1.45

func color_for(role: int) -> Color:
	match role:
		PaletteRole.PHYSICAL: return physical_color
		PaletteRole.SECURITY: return security_color
		PaletteRole.HOSTILE: return hostile_color
		PaletteRole.LOCAL_LINK: return local_link_color
		PaletteRole.OBJECTIVE: return objective_color
	return standard_color

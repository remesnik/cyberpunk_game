class_name DeckResourceProfile
extends Resource

@export_range(1, 99, 1) var storage_per_hardware_level := 4
@export_range(1, 99, 1) var memory_per_hardware_level := 4
@export_range(1, 99, 1) var minimum_storage := 4
@export_range(1, 99, 1) var minimum_memory := 4
@export_range(0.0, 60.0, 0.1) var install_utility_seconds := 4.0
@export_range(0.0, 60.0, 0.1) var uninstall_utility_seconds := 2.0
@export_range(0.0, 60.0, 0.1) var start_active_program_seconds := 3.0
@export_range(0.0, 60.0, 0.1) var stop_active_program_seconds := 1.5
@export_range(0.0, 60.0, 0.1) var swap_active_program_seconds := 4.0
@export_range(0.0, 0.9, 0.01) var time_reduction_per_cpu_level := 0.1

func storage_capacity(hardware_level: int) -> int:
	return maxi(minimum_storage, maxi(1, hardware_level) * storage_per_hardware_level)

func memory_capacity(hardware_level: int) -> int:
	return maxi(minimum_memory, maxi(1, hardware_level) * memory_per_hardware_level)

func reconfiguration_duration(base_seconds: float, cpu_level: int) -> float:
	var reduction := clampf(float(maxi(0, cpu_level - 1)) * time_reduction_per_cpu_level, 0.0, 0.9)
	return maxf(0.0, base_seconds * (1.0 - reduction))

# GameConfig.gd - Centralized game configuration
extends Resource
class_name GameConfig

# Faction configuration
@export_group("Faction Settings")
@export var max_factions: int = 5
@export var starting_funds: float = 5000.0
@export var starting_supplies: float = 1000.0
@export var members_per_faction: int = 3
@export var territories_per_faction: int = 1
@export var businesses_per_territory: int = 2
@export var max_members_per_faction: int = 10

# Economy configuration
@export_group("Economy Settings")
@export var base_supply_consumption_per_member: float = 0.5
@export var base_supply_consumption_per_territory: float = 2.0
@export var supply_order_amount: float = 1000.0
@export var recruitment_cost: float = 1500.0
@export var business_capture_protection_penalty: float = 0.3

# AI configuration
@export_group("AI Settings")
@export var commander_think_interval: float = 5.0  # Normal speed
@export var member_think_interval: float = 2.0  # Normal speed
@export var ai_think_budget_ms: float = 16.0
@export var max_ai_updates_per_frame: int = 10
@export var max_orders_in_queue: int = 10

# Order configuration
@export_group("Order Settings")
@export var order_travel_time_base: float = 2.0  # Base travel time in seconds
@export var order_work_time_base: float = 3.0  # Base work time in seconds
@export var order_return_time_base: float = 2.0  # Base return time in seconds
@export var order_time_multiplier: float = 1.0  # Global order time multiplier
@export var supply_order_priority: int = 80
@export var defend_order_priority: int = 90
@export var spy_order_priority: int = 60

# Combat configuration
@export_group("Combat Settings")
@export var attack_success_base_chance: float = 0.6
@export var defend_success_base_chance: float = 0.8
@export var spy_success_base_chance: float = 0.7
@export var sabotage_success_base_chance: float = 0.65
@export var loyalty_loss_on_injury: float = 10.0
@export var loyalty_gain_on_success: float = 3.0

# Scale configuration
@export_group("Scale Settings")
@export var world_scale: float = 1.0  # Base scale for all world elements
@export var character_scale: float = 1.0  # Character mesh scale (1.0 = normal human size)
@export var character_height: float = 1.8  # Character height in meters
@export var character_radius: float = 0.4  # Character collision radius in meters

# Movement configuration
@export_group("Movement Settings")
@export var character_movement_speed: float = 3.0  # Base movement speed in m/s (walking speed)
@export var character_run_speed: float = 6.0  # Running speed in m/s
@export var speed_multiplier: float = 1.0  # Global speed multiplier
@export var fast_travel_enabled: bool = true

# Collision avoidance configuration
@export_group("Collision Avoidance Settings")
@export var avoidance_radius: float = 2.0  # Radius for collision avoidance detection
@export var avoidance_strength: float = 3.0  # Strength of avoidance force
@export var separation_radius: float = 1.5  # Radius for separation behavior
@export var separation_strength: float = 2.0  # Strength of separation force
@export var max_avoidance_force: float = 5.0  # Maximum avoidance force magnitude

# Distance configuration
@export_group("Distance Settings")
@export var spawn_radius_min: float = 5.0  # Minimum spawn distance from base (meters)
@export var spawn_radius_max: float = 15.0  # Maximum spawn distance from base (meters)
@export var min_distance_between_members: float = 2.0  # Minimum spacing between members (meters)
@export var base_radius: float = 10.0  # Base influence radius (meters)
@export var territory_radius: float = 50.0  # Territory radius (meters)

# Performance configuration
@export_group("Performance Settings")
@export var max_entities: int = 10000
@export var entity_cleanup_interval: float = 5.0
@export var event_queue_max_per_frame: int = 100
@export var cache_validity_duration: float = 5.0
@export var object_pool_size: int = 50

# Game balance
@export_group("Balance Settings")
@export var critical_supplies_threshold: float = 100.0
@export var critical_funds_threshold: float = 200.0
@export var min_funds_for_operations: float = 500.0
@export var min_supplies_for_operations: float = 200.0
@export var territory_safety_decay_rate: float = 0.01
@export var contested_territory_safety_penalty: float = 0.05

# Save/Load configuration
@export_group("Save System")
@export var autosave_interval: float = 60.0
@export var max_save_slots: int = 10
@export var save_file_prefix: String = "gang_save_"

# Default instance
static var default_config: GameConfig

static func get_default() -> GameConfig:
	if not default_config:
		default_config = GameConfig.new()
	return default_config

# Validation
func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	# Validate faction settings
	Validatable.validate_positive(max_factions, "max_factions", result)
	Validatable.validate_positive(starting_funds, "starting_funds", result)
	Validatable.validate_positive(starting_supplies, "starting_supplies", result)
	Validatable.validate_positive(members_per_faction, "members_per_faction", result)
	
	# Validate AI settings
	Validatable.validate_positive(commander_think_interval, "commander_think_interval", result)
	Validatable.validate_positive(ai_think_budget_ms, "ai_think_budget_ms", result)
	
	# Validate performance settings
	Validatable.validate_positive(max_entities, "max_entities", result)
	Validatable.validate_positive(entity_cleanup_interval, "entity_cleanup_interval", result)
	
	# Validate balance
	if critical_supplies_threshold >= starting_supplies:
		result.add_warning("Critical supplies threshold is higher than starting supplies")
	
	if min_funds_for_operations >= starting_funds:
		result.add_warning("Minimum funds for operations is higher than starting funds")
	
	return result

# Save configuration to file
func save_to_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var data = {}
		for property in get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE:
				data[property.name] = get(property.name)
		file.store_string(JSON.stringify(data))
		file.close()
		Logger.info("Configuration saved", "GameConfig", {"path": path})
	else:
		Logger.error("Failed to save configuration", "GameConfig", {"path": path})

# Load configuration from file
func load_from_file(path: String) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			for key in data:
				if has_property(key):
					set(key, data[key])
			
			Logger.info("Configuration loaded", "GameConfig", {"path": path})
			return true
		else:
			Logger.error("Failed to parse configuration file", "GameConfig", {
				"path": path,
				"error": parse_result
			})
	else:
		Logger.error("Failed to open configuration file", "GameConfig", {"path": path})
	
	return false

func has_property(property_name: String) -> bool:
	for property in get_property_list():
		if property.name == property_name:
			return true
	return false

# Get a formatted summary of the configuration
func get_summary() -> String:
	var summary = "=== Game Configuration ===\n"
	
	summary += "\nFaction Settings:\n"
	summary += "  Max Factions: %d\n" % max_factions
	summary += "  Starting Funds: %.1f\n" % starting_funds
	summary += "  Starting Supplies: %.1f\n" % starting_supplies
	summary += "  Members per Faction: %d\n" % members_per_faction
	
	summary += "\nAI Settings:\n"
	summary += "  Commander Think Interval: %.1fs\n" % commander_think_interval
	summary += "  Max Orders in Queue: %d\n" % max_orders_in_queue
	
	summary += "\nPerformance Settings:\n"
	summary += "  Max Entities: %d\n" % max_entities
	summary += "  Cleanup Interval: %.1fs\n" % entity_cleanup_interval
	
	return summary

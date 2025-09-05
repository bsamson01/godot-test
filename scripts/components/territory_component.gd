# TerritoryComponent.gd - Component for territory control
extends Component
class_name TerritoryComponent

@export var territory_name: String = ""
@export var territory_type: String = "residential"
@export var center_location: Vector3 = Vector3.ZERO
@export var radius: float = 50.0
@export var value: float = 1000.0
@export var income_per_hour: float = 100.0

# Control status
var controlled_by: String = ""  # Faction ID
var control_level: float = 0.0  # 0-100
var last_income_time: float = 0.0

# Territory stats
var population: int = 100
var safety_level: float = 50.0
var corruption_level: float = 30.0
var development_level: float = 40.0

# Events
var events: Array[Dictionary] = []

func get_component_name() -> String:
	return "TerritoryComponent"

func _on_attached(_entity: Entity) -> void:
	# Generate random name if not set
	if territory_name.is_empty():
		territory_name = _generate_territory_name()
	
	# Initialize territory
	_initialize_territory()
	
	# Subscribe to events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.FACTION_DESTROYED, _on_faction_destroyed)

func _on_detached(_entity: Entity) -> void:
	# Unsubscribe from events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.FACTION_DESTROYED, _on_faction_destroyed)

func _initialize_territory() -> void:
	# Set initial values based on territory type
	match territory_type:
		"residential":
			population = randi_range(50, 200)
			safety_level = randf_range(40, 80)
			corruption_level = randf_range(20, 60)
			development_level = randf_range(30, 70)
			income_per_hour = randf_range(50, 150)
		
		"commercial":
			population = randi_range(20, 100)
			safety_level = randf_range(30, 70)
			corruption_level = randf_range(40, 80)
			development_level = randf_range(50, 90)
			income_per_hour = randf_range(100, 300)
		
		"industrial":
			population = randi_range(10, 50)
			safety_level = randf_range(20, 50)
			corruption_level = randf_range(60, 90)
			development_level = randf_range(40, 80)
			income_per_hour = randf_range(80, 200)
		
		"downtown":
			population = randi_range(100, 500)
			safety_level = randf_range(60, 90)
			corruption_level = randf_range(10, 40)
			development_level = randf_range(70, 95)
			income_per_hour = randf_range(200, 500)

func _generate_territory_name() -> String:
	var prefixes = ["Old", "New", "East", "West", "North", "South", "Central", "Upper", "Lower"]
	var names = ["Town", "District", "Quarter", "Heights", "Hills", "Valley", "Square", "Plaza", "Avenue"]
	
	return prefixes[randi() % prefixes.size()] + " " + names[randi() % names.size()]

func update(delta: float) -> void:
	if not is_enabled:
		return
	
	# Update territory over time
	_update_territory_stats(delta)
	
	# Generate income if controlled
	if controlled_by != "" and control_level > 50.0:
		_generate_income(delta)

func _update_territory_stats(delta: float) -> void:
	# Safety level changes based on control
	if controlled_by != "":
		# Controlled territory becomes safer over time
		safety_level = min(100, safety_level + delta * 0.1)
	else:
		# Uncontrolled territory becomes less safe
		safety_level = max(0, safety_level - delta * 0.05)
	
	# Corruption level changes based on control
	if controlled_by != "" and control_level > 80.0:
		# High control reduces corruption
		corruption_level = max(0, corruption_level - delta * 0.02)
	else:
		# Low control or no control increases corruption
		corruption_level = min(100, corruption_level + delta * 0.01)
	
	# Development level changes based on income
	if income_per_hour > 0:
		development_level = min(100, development_level + delta * 0.001)

func _generate_income(_delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if last_income_time == 0.0:
		last_income_time = current_time
		return
	
	var time_since_last_income = current_time - last_income_time
	var income_interval = 3600.0  # 1 hour in seconds
	
	if time_since_last_income >= income_interval:
		var income = income_per_hour * (time_since_last_income / 3600.0)
		
		# Give income to controlling faction
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var faction_entity = entity_manager.get_entity(controlled_by)
			if faction_entity:
				var faction_comp = faction_entity.get_component("FactionComponent")
				if faction_comp:
					faction_comp.add_funds(income, "Territory income: " + territory_name)
		
		last_income_time = current_time
		
		Logger.info("Territory generated income", "Territory", {
			"territory": territory_name,
			"income": income,
			"faction": controlled_by
		})

func claim_territory(faction_id: String, control_amount: float = 100.0) -> bool:
	if controlled_by == faction_id:
		# Already controlled by this faction
		control_level = min(100, control_level + control_amount)
		return true
	
	# Check if territory can be claimed
	if control_level > 0 and controlled_by != "":
		# Territory is contested
		return false
	
	# Claim the territory
	controlled_by = faction_id
	control_level = control_amount
	
	Logger.info("Territory claimed", "Territory", {
		"territory": territory_name,
		"faction": faction_id,
		"control_level": control_level
	})
	
	return true

func lose_control(amount: float = 100.0) -> void:
	control_level = max(0, control_level - amount)
	
	if control_level <= 0:
		controlled_by = ""
		control_level = 0.0
		
		Logger.info("Territory lost", "Territory", {
			"territory": territory_name,
			"previous_controller": controlled_by
		})

func is_controlled_by(faction_id: String) -> bool:
	return controlled_by == faction_id and control_level > 50.0

func get_control_percentage() -> float:
	return control_level

func is_contested() -> bool:
	return controlled_by != "" and control_level < 100.0

func add_event(event_type: String, description: String, data: Dictionary = {}) -> void:
	var event = {
		"type": event_type,
		"description": description,
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"data": data
	}
	
	events.append(event)
	
	# Keep only last 100 events
	if events.size() > 100:
		events.pop_front()

func get_recent_events(count: int = 10) -> Array[Dictionary]:
	var start_index = max(0, events.size() - count)
	return events.slice(start_index)

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	Validatable.validate_not_empty(territory_name, "territory_name", result)
	Validatable.validate_in_range(control_level, 0, 100, "control_level", result)
	Validatable.validate_positive(radius, "radius", result)
	Validatable.validate_positive(value, "value", result)
	Validatable.validate_in_range(safety_level, 0, 100, "safety_level", result)
	Validatable.validate_in_range(corruption_level, 0, 100, "corruption_level", result)
	Validatable.validate_in_range(development_level, 0, 100, "development_level", result)
	
	return result

func get_stats() -> Dictionary:
	return {
		"name": territory_name,
		"type": territory_type,
		"controlled_by": controlled_by,
		"control_level": control_level,
		"population": population,
		"safety_level": safety_level,
		"corruption_level": corruption_level,
		"development_level": development_level,
		"income_per_hour": income_per_hour,
		"value": value,
		"center_location": center_location,
		"radius": radius
	}

# Event handlers
func _on_faction_destroyed(event: EventBus.Event) -> void:
	var destroyed_faction_id = event.data.get("faction_id")
	if controlled_by == destroyed_faction_id:
		lose_control(100.0)

# TerritoryComponent.gd - Component for territory data and management
extends Component
class_name TerritoryComponent

@export var territory_name: String = ""
@export var owner_faction_id: String = ""
@export var location: Vector2 = Vector2.ZERO

# Territory attributes
@export var safety_level: float = 0.5  # 0.0 to 1.0
@export var defense_bonus: float = 0.0
@export var income_multiplier: float = 1.0

# Business management
var business_ids: Array[String] = []
var max_businesses: int = 5

# Control tracking
var control_points: float = 100.0
var contested: bool = false
var contesting_faction_id: String = ""

func get_component_name() -> String:
	return "TerritoryComponent"

func _on_attached(entity: Entity) -> void:
	# Subscribe to territory events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.BUSINESS_CAPTURED, _on_business_captured)
		event_bus.subscribe(EventBus.EventType.BUSINESS_DESTROYED, _on_business_destroyed)

func _on_detached(entity: Entity) -> void:
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.BUSINESS_CAPTURED, _on_business_captured)
		event_bus.unsubscribe(EventBus.EventType.BUSINESS_DESTROYED, _on_business_destroyed)

func add_business(business_id: String) -> bool:
	if business_ids.size() >= max_businesses:
		Logger.warning("Territory at maximum business capacity", "Territory", {
			"territory": territory_name,
			"current": business_ids.size(),
			"max": max_businesses
		})
		return false
	
	if not business_ids.has(business_id):
		business_ids.append(business_id)
		_update_territory_stats()
		return true
	
	return false

func remove_business(business_id: String) -> void:
	business_ids.erase(business_id)
	_update_territory_stats()

func contest_territory(attacking_faction_id: String) -> void:
	if contested and contesting_faction_id != attacking_faction_id:
		Logger.warning("Territory already being contested", "Territory", {
			"territory": territory_name,
			"current_attacker": contesting_faction_id,
			"new_attacker": attacking_faction_id
		})
		return
	
	contested = true
	contesting_faction_id = attacking_faction_id
	
	Logger.info("Territory contested", "Territory", {
		"territory": territory_name,
		"defender": owner_faction_id,
		"attacker": attacking_faction_id
	})

func damage_control(amount: float) -> void:
	control_points = max(0, control_points - amount)
	
	if control_points <= 0 and contested:
		_capture_territory()

func restore_control(amount: float) -> void:
	control_points = min(100, control_points + amount)
	
	if control_points >= 100 and contested:
		contested = false
		contesting_faction_id = ""
		Logger.info("Territory defended successfully", "Territory", {
			"territory": territory_name,
			"owner": owner_faction_id
		})

func _capture_territory() -> void:
	var old_owner = owner_faction_id
	owner_faction_id = contesting_faction_id
	contested = false
	contesting_faction_id = ""
	control_points = 100.0
	
	Logger.info("Territory captured", "Territory", {
		"territory": territory_name,
		"old_owner": old_owner,
		"new_owner": owner_faction_id
	})
	
	# Emit capture event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.FACTION_TERRITORY_LOST,
			{
				"territory_id": entity.id,
				"territory_name": territory_name,
				"faction_id": old_owner
			}
		)
		
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.FACTION_TERRITORY_GAINED,
			{
				"territory_id": entity.id,
				"territory_name": territory_name,
				"faction_id": owner_faction_id
			}
		)

func update_safety(delta: float) -> void:
	# Safety naturally decays
	safety_level = max(0, safety_level - delta * 0.01)
	
	# Contested territories are less safe
	if contested:
		safety_level = max(0, safety_level - delta * 0.05)

func improve_safety(amount: float) -> void:
	safety_level = min(1.0, safety_level + amount)

func _update_territory_stats() -> void:
	# More businesses = higher income multiplier but lower safety
	var business_count = business_ids.size()
	income_multiplier = 1.0 + (business_count * 0.1)
	
	# Each business slightly reduces safety
	var safety_penalty = business_count * 0.05
	safety_level = max(0.1, safety_level - safety_penalty)

func get_businesses() -> Array[Entity]:
	var businesses: Array[Entity] = []
	var entity_manager = Engine.get_singleton("EntityManager") if Engine.has_singleton("EntityManager") else null
	
	if entity_manager:
		for business_id in business_ids:
			var business = entity_manager.get_entity(business_id)
			if business:
				businesses.append(business)
	
	return businesses

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	Validatable.validate_not_empty(territory_name, "territory_name", result)
	Validatable.validate_in_range(safety_level, 0, 1, "safety_level", result)
	Validatable.validate_positive(income_multiplier, "income_multiplier", result)
	Validatable.validate_in_range(control_points, 0, 100, "control_points", result)
	
	return result

func get_stats() -> Dictionary:
	return {
		"name": territory_name,
		"owner": owner_faction_id,
		"safety": safety_level,
		"control": control_points,
		"contested": contested,
		"businesses": business_ids.size(),
		"income_multiplier": income_multiplier
	}

# Event handlers
func _on_business_captured(event: EventBus.Event) -> void:
	var business_id = event.data.get("business_id")
	if business_ids.has(business_id):
		# Business in this territory was captured
		improve_safety(-0.1)  # Reduce safety when business changes hands

func _on_business_destroyed(event: EventBus.Event) -> void:
	var business_id = event.data.get("business_id")
	if business_ids.has(business_id):
		remove_business(business_id)
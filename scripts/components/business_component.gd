# BusinessComponent.gd - Component for business data and income generation
extends Component
class_name BusinessComponent

@export var business_name: String = ""
@export var business_type: String = ""
@export var base_income: float = 50.0
@export var territory_id: String = ""
@export var owner_faction_id: String = ""

# Business types and their characteristics
const BUSINESS_TYPES = {
	"Nightclub": {"base_income": 100.0, "night_bonus": 0.5, "day_penalty": -0.2},
	"Barbershop": {"base_income": 40.0, "night_bonus": -0.3, "day_penalty": 0.0},
	"Casino": {"base_income": 150.0, "night_bonus": 0.3, "day_penalty": -0.1},
	"Garage": {"base_income": 60.0, "night_bonus": 0.0, "day_penalty": 0.0},
	"Pawn Shop": {"base_income": 80.0, "night_bonus": 0.1, "day_penalty": 0.0},
	"Restaurant": {"base_income": 70.0, "night_bonus": 0.2, "day_penalty": 0.1}
}

# Income tracking
var income_generated_today: float = 0.0
var total_income_generated: float = 0.0
var last_income_time: float = 0.0

# Business state
var operational: bool = true
var damage_level: float = 0.0  # 0.0 = pristine, 1.0 = destroyed
var protection_level: float = 0.5  # How well protected the business is

func get_component_name() -> String:
	return "BusinessComponent"

func _on_attached(entity: Entity) -> void:
	# Subscribe to business events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.DAMAGE_DEALT, _on_damage_dealt)

func _on_detached(entity: Entity) -> void:
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.DAMAGE_DEALT, _on_damage_dealt)

func generate_random() -> void:
	# Random business type
	var types = BUSINESS_TYPES.keys()
	business_type = types[randi() % types.size()]
	
	# Random name based on type
	business_name = _generate_business_name(business_type)
	
	# Set base income from type
	var type_data = BUSINESS_TYPES.get(business_type, {})
	base_income = type_data.get("base_income", 50.0)

func calculate_income(time_of_day: String) -> float:
	if not operational or damage_level >= 1.0:
		return 0.0
	
	var income = base_income
	var type_data = BUSINESS_TYPES.get(business_type, {})
	
	# Apply time of day modifiers
	if time_of_day == "Night":
		income *= (1.0 + type_data.get("night_bonus", 0.0))
	else:
		income *= (1.0 + type_data.get("day_penalty", 0.0))
	
	# Apply damage penalty
	income *= (1.0 - damage_level)
	
	# Apply territory safety bonus (need to get from territory)
	var territory_safety = _get_territory_safety()
	income *= (0.5 + territory_safety * 0.5)  # 50% to 100% based on safety
	
	# Apply protection bonus
	income *= (0.8 + protection_level * 0.4)  # 80% to 120% based on protection
	
	# Track income
	income_generated_today += income
	total_income_generated += income
	last_income_time = Time.get_ticks_msec() / 1000.0
	
	return income

func damage_business(amount: float) -> void:
	damage_level = min(1.0, damage_level + amount)
	
	if damage_level >= 1.0:
		operational = false
		Logger.info("Business destroyed", "Business", {
			"name": business_name,
			"owner": owner_faction_id
		})
		
		# Emit destruction event
		if Engine.has_singleton("EventBus"):
			Engine.get_singleton("EventBus").emit_event(
				EventBus.EventType.BUSINESS_DESTROYED,
				{
					"business_id": entity.id,
					"business_name": business_name,
					"territory_id": territory_id,
					"faction_id": owner_faction_id
				}
			)
	elif damage_level >= 0.5:
		Logger.warning("Business heavily damaged", "Business", {
			"name": business_name,
			"damage": damage_level
		})

func repair_business(amount: float) -> void:
	if damage_level <= 0:
		return
	
	damage_level = max(0, damage_level - amount)
	
	if damage_level < 1.0 and not operational:
		operational = true
		Logger.info("Business repaired and operational", "Business", {
			"name": business_name,
			"damage": damage_level
		})

func improve_protection(amount: float) -> void:
	protection_level = min(1.0, protection_level + amount)

func capture_business(new_owner_id: String) -> void:
	var old_owner = owner_faction_id
	owner_faction_id = new_owner_id
	
	# Reset some stats on capture
	protection_level = max(0.2, protection_level - 0.3)
	
	Logger.info("Business captured", "Business", {
		"name": business_name,
		"old_owner": old_owner,
		"new_owner": new_owner_id
	})
	
	# Emit capture event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.BUSINESS_CAPTURED,
			{
				"business_id": entity.id,
				"business_name": business_name,
				"territory_id": territory_id,
				"old_faction": old_owner,
				"new_faction": new_owner_id
			}
		)

func _get_territory_safety() -> float:
	var entity_manager = Engine.get_singleton("EntityManager") if Engine.has_singleton("EntityManager") else null
	if not entity_manager:
		return 0.5
	
	var territory = entity_manager.get_entity(territory_id)
	if not territory:
		return 0.5
	
	var territory_comp = territory.get_component("TerritoryComponent")
	if not territory_comp:
		return 0.5
	
	return territory_comp.safety_level

func _generate_business_name(type: String) -> String:
	var prefixes = {
		"Nightclub": ["The Velvet", "Neon", "Electric", "Midnight"],
		"Barbershop": ["Tony's", "Classic", "Razor's", "The Clean"],
		"Casino": ["Lucky", "Golden", "Diamond", "Royal"],
		"Garage": ["Mike's", "Chrome", "Turbo", "Grease"],
		"Pawn Shop": ["Quick", "Gold", "Cash", "Easy"],
		"Restaurant": ["Mama's", "The Hungry", "Golden", "Tony's"]
	}
	
	var suffixes = {
		"Nightclub": ["Lounge", "Dreams", "Paradise", "Underground"],
		"Barbershop": ["Cuts", "Fade", "Shop", "Style"],
		"Casino": ["Palace", "Fortune", "Royale", "Luck"],
		"Garage": ["Motors", "Repair", "Works", "Auto"],
		"Pawn Shop": ["Pawn", "Exchange", "Trade", "Cash"],
		"Restaurant": ["Kitchen", "Grill", "Diner", "Bistro"]
	}
	
	var type_prefixes = prefixes.get(type, ["Generic"])
	var type_suffixes = suffixes.get(type, ["Business"])
	
	var prefix = type_prefixes[randi() % type_prefixes.size()]
	var suffix = type_suffixes[randi() % type_suffixes.size()]
	
	return prefix + " " + suffix

func reset_daily_income() -> void:
	income_generated_today = 0.0

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	Validatable.validate_not_empty(business_name, "business_name", result)
	Validatable.validate_not_empty(business_type, "business_type", result)
	Validatable.validate_positive(base_income, "base_income", result)
	Validatable.validate_in_range(damage_level, 0, 1, "damage_level", result)
	Validatable.validate_in_range(protection_level, 0, 1, "protection_level", result)
	
	if not BUSINESS_TYPES.has(business_type):
		result.add_warning("Unknown business type: " + business_type)
	
	return result

func get_stats() -> Dictionary:
	return {
		"name": business_name,
		"type": business_type,
		"owner": owner_faction_id,
		"operational": operational,
		"base_income": base_income,
		"damage": damage_level,
		"protection": protection_level,
		"income_today": income_generated_today,
		"total_income": total_income_generated
	}

# Event handlers
func _on_damage_dealt(event: EventBus.Event) -> void:
	if event.data.get("target_id") == entity.id:
		var damage = event.data.get("amount", 0.1)
		damage_business(damage)
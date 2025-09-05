# BusinessComponent.gd - Component for businesses that can be controlled
extends Component
class_name BusinessComponent

@export var business_name: String = ""
@export var business_type: String = "shop"
@export var location: Vector3 = Vector3.ZERO
@export var value: float = 5000.0
@export var income_per_hour: float = 200.0

# Control status
var controlled_by: String = ""  # Faction ID
var control_level: float = 0.0  # 0-100
var protection_paid: bool = false
var last_income_time: float = 0.0
var territory_id: String = ""  # Territory ID this business belongs to

# Business stats
var reputation: float = 50.0
var customer_satisfaction: float = 75.0
var security_level: float = 40.0
var efficiency: float = 60.0

# Business operations
var is_operational: bool = true
var operational_hours: Dictionary = {"start": 8, "end": 20}  # 8 AM to 8 PM
var last_operation_check: float = 0.0

# Events
var events: Array[Dictionary] = []

func get_component_name() -> String:
	return "BusinessComponent"

func _on_attached(_entity: Entity) -> void:
	# Generate random name if not set
	if business_name.is_empty():
		business_name = _generate_business_name()
	
	# Initialize business
	_initialize_business()
	
	# Subscribe to events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.FACTION_DESTROYED, _on_faction_destroyed)

func _on_detached(_entity: Entity) -> void:
	# Unsubscribe from events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.FACTION_DESTROYED, _on_faction_destroyed)

func _initialize_business() -> void:
	# Set initial values based on business type
	match business_type:
		"shop":
			reputation = randf_range(40, 80)
			customer_satisfaction = randf_range(60, 90)
			security_level = randf_range(30, 70)
			efficiency = randf_range(50, 85)
			income_per_hour = randf_range(100, 300)
		
		"restaurant":
			reputation = randf_range(30, 90)
			customer_satisfaction = randf_range(50, 95)
			security_level = randf_range(20, 60)
			efficiency = randf_range(40, 80)
			income_per_hour = randf_range(150, 400)
		
		"warehouse":
			reputation = randf_range(20, 60)
			customer_satisfaction = randf_range(30, 70)
			security_level = randf_range(60, 90)
			efficiency = randf_range(70, 95)
			income_per_hour = randf_range(200, 500)
		
		"nightclub":
			reputation = randf_range(40, 90)
			customer_satisfaction = randf_range(60, 95)
			security_level = randf_range(50, 80)
			efficiency = randf_range(60, 90)
			income_per_hour = randf_range(300, 800)

func _generate_business_name() -> String:
	var prefixes = ["Elite", "Golden", "Royal", "Premium", "Luxury", "Grand", "Supreme", "Ultimate"]
	var business_types = ["Shop", "Store", "Market", "Boutique", "Emporium", "Mart", "Center", "Plaza"]
	
	return prefixes[randi() % prefixes.size()] + " " + business_types[randi() % business_types.size()]

func generate_random() -> void:
	# Generate random business type
	var business_types = ["shop", "restaurant", "warehouse", "nightclub"]
	business_type = business_types[randi() % business_types.size()]
	
	# Generate random name
	business_name = _generate_business_name()
	
	# Generate random location (will be set by the calling code)
	location = Vector3.ZERO
	
	# Generate random value and income
	value = randf_range(2000, 10000)
	income_per_hour = randf_range(50, 500)
	
	# Initialize business with random stats
	_initialize_business()

func calculate_income(time_of_day: String) -> float:
	var multiplier := 1.0
	
	# Time-based multipliers
	if time_of_day == "Night" and business_type == "nightclub":
		multiplier += 0.5  # More business at night for nightclubs
	elif time_of_day == "Day" and business_type == "shop":
		multiplier += 0.2  # More business during day for shops
	elif time_of_day == "Evening" and business_type == "restaurant":
		multiplier += 0.3  # More business in evening for restaurants
	
	# Business stats affect income
	var efficiency_multiplier = efficiency / 100.0
	var reputation_multiplier = reputation / 100.0
	var customer_satisfaction_multiplier = customer_satisfaction / 100.0
	
	# Combine all multipliers
	var total_multiplier = multiplier * efficiency_multiplier * reputation_multiplier * customer_satisfaction_multiplier
	
	# Check if territory is safe (controlled by same faction)
	var territory_safe = false
	if territory_id != "" and Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var territory_entity = entity_manager.get_entity(territory_id)
		if territory_entity:
			var territory_comp = territory_entity.get_component("TerritoryComponent")
			if territory_comp and territory_comp.controlled_by == controlled_by:
				territory_safe = true
	
	# Territory safety affects income
	if not territory_safe:
		total_multiplier -= 0.3  # Scared customers
	
	# Ensure minimum multiplier
	total_multiplier = max(0.1, total_multiplier)
	
	return income_per_hour * total_multiplier

func update(delta: float) -> void:
	if not is_enabled:
		return
	
	# Update business over time
	_update_business_stats(delta)
	
	# Check operational status
	_check_operational_status()
	
	# Generate income if controlled and operational
	if controlled_by != "" and control_level > 50.0 and is_operational:
		_generate_income(delta)

func _update_business_stats(delta: float) -> void:
	# Reputation changes based on control and protection
	if controlled_by != "" and protection_paid:
		# Protected business gains reputation
		reputation = min(100, reputation + delta * 0.05)
	else:
		# Unprotected business loses reputation
		reputation = max(0, reputation - delta * 0.02)
	
	# Customer satisfaction changes based on reputation and efficiency
	var satisfaction_change = (reputation / 100.0) * (efficiency / 100.0) * delta * 0.1
	customer_satisfaction = clamp(customer_satisfaction + satisfaction_change, 0, 100)
	
	# Security level changes based on control
	if controlled_by != "" and control_level > 80.0:
		# High control increases security
		security_level = min(100, security_level + delta * 0.03)
	else:
		# Low control decreases security
		security_level = max(0, security_level - delta * 0.01)
	
	# Efficiency changes based on customer satisfaction
	efficiency = clamp(efficiency + (customer_satisfaction - 50) * delta * 0.001, 0, 100)

func _check_operational_status() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var current_hour = int(current_time / 3600) % 24
	
	# Check if business should be operational
	var should_be_operational = (current_hour >= operational_hours.start and current_hour < operational_hours.end)
	
	if should_be_operational != is_operational:
		is_operational = should_be_operational
		
		if is_operational:
			add_event("business_opened", "Business opened for the day")
		else:
			add_event("business_closed", "Business closed for the day")

func _generate_income(_delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	if last_income_time == 0.0:
		last_income_time = current_time
		return
	
	var time_since_last_income = current_time - last_income_time
	var income_interval = 3600.0  # 1 hour in seconds
	
	if time_since_last_income >= income_interval:
		# Calculate income based on efficiency and customer satisfaction
		var income_multiplier = (efficiency / 100.0) * (customer_satisfaction / 100.0)
		var income = income_per_hour * income_multiplier * (time_since_last_income / 3600.0)
		
		# Give income to controlling faction
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var faction_entity = entity_manager.get_entity(controlled_by)
			if faction_entity:
				var faction_comp = faction_entity.get_component("FactionComponent")
				if faction_comp:
					faction_comp.add_funds(income, "Business income: " + business_name)
		
		last_income_time = current_time
		
		Logger.info("Business generated income", "Business", {
			"business": business_name,
			"income": income,
			"faction": controlled_by,
			"efficiency": efficiency,
			"customer_satisfaction": customer_satisfaction
		})

func claim_business(faction_id: String, control_amount: float = 100.0) -> bool:
	if controlled_by == faction_id:
		# Already controlled by this faction
		control_level = min(100, control_level + control_amount)
		return true
	
	# Check if business can be claimed
	if control_level > 0 and controlled_by != "":
		# Business is contested
		return false
	
	# Claim the business
	controlled_by = faction_id
	control_level = control_amount
	
	Logger.info("Business claimed", "Business", {
		"business": business_name,
		"faction": faction_id,
		"control_level": control_level
	})
	
	return true

func lose_control(amount: float = 100.0) -> void:
	control_level = max(0, control_level - amount)
	
	if control_level <= 0:
		controlled_by = ""
		control_level = 0.0
		protection_paid = false
		
		Logger.info("Business lost", "Business", {
			"business": business_name,
			"previous_controller": controlled_by
		})

func is_controlled_by(faction_id: String) -> bool:
	return controlled_by == faction_id and control_level > 50.0

func get_control_percentage() -> float:
	return control_level

func is_contested() -> bool:
	return controlled_by != "" and control_level < 100.0

func pay_protection(faction_id: String, amount: float) -> bool:
	if controlled_by != faction_id:
		return false
	
	# Check if faction has enough funds
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var faction_entity = entity_manager.get_entity(faction_id)
		if faction_entity:
			var faction_comp = faction_entity.get_component("FactionComponent")
			if faction_comp and faction_comp.funds >= amount:
				faction_comp.spend_funds(amount, "Protection payment: " + business_name)
				protection_paid = true
				
				Logger.info("Protection payment made", "Business", {
					"business": business_name,
					"faction": faction_id,
					"amount": amount
				})
				
				return true
	
	return false

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
	
	Validatable.validate_not_empty(business_name, "business_name", result)
	Validatable.validate_in_range(control_level, 0, 100, "control_level", result)
	Validatable.validate_positive(value, "value", result)
	Validatable.validate_in_range(reputation, 0, 100, "reputation", result)
	Validatable.validate_in_range(customer_satisfaction, 0, 100, "customer_satisfaction", result)
	Validatable.validate_in_range(security_level, 0, 100, "security_level", result)
	Validatable.validate_in_range(efficiency, 0, 100, "efficiency", result)
	
	return result

func get_stats() -> Dictionary:
	return {
		"name": business_name,
		"type": business_type,
		"controlled_by": controlled_by,
		"control_level": control_level,
		"protection_paid": protection_paid,
		"reputation": reputation,
		"customer_satisfaction": customer_satisfaction,
		"security_level": security_level,
		"efficiency": efficiency,
		"income_per_hour": income_per_hour,
		"value": value,
		"location": location,
		"is_operational": is_operational
	}

# Event handlers
func _on_faction_destroyed(event: EventBus.Event) -> void:
	var destroyed_faction_id = event.data.get("faction_id")
	if controlled_by == destroyed_faction_id:
		lose_control(100.0)

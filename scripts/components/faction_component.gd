# FactionComponent.gd - Component for faction data and behavior
extends Component
class_name FactionComponent

@export var faction_name: String = ""
@export var color: Color = Color.WHITE
@export var funds: float = 1000.0
@export var supplies: float = 1000.0

# Relationships by faction ID
@export var relationships: Dictionary = {} # faction_id -> RelationType

enum RelationType {
	HOSTILE,
	NEUTRAL,
	ALLY
}

# Runtime data
var income_this_period: float = 0.0
var expenses_this_period: float = 0.0
var supply_consumption_rate: float = 0.0
var intel: Dictionary = {} # faction_id -> intel_data

# Cached references
var _member_entities: Array[Entity] = []
var _territory_entities: Array[Entity] = []
var _business_entities: Array[Entity] = []

func get_component_name() -> String:
	return "FactionComponent"

func _on_attached(entity: Entity) -> void:
	# Validate initial state
	var result = validate()
	if not result.is_valid:
		Logger.error("Invalid faction component attached: " + result.to_string(), "Faction")
	
	# Subscribe to events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.FACTION_MEMBER_ADDED, _on_member_added)
		event_bus.subscribe(EventBus.EventType.FACTION_MEMBER_REMOVED, _on_member_removed)
		event_bus.subscribe(EventBus.EventType.BUSINESS_INCOME_GENERATED, _on_income_generated)

func _on_detached(entity: Entity) -> void:
	# Unsubscribe from events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.FACTION_MEMBER_ADDED, _on_member_added)
		event_bus.unsubscribe(EventBus.EventType.FACTION_MEMBER_REMOVED, _on_member_removed)
		event_bus.unsubscribe(EventBus.EventType.BUSINESS_INCOME_GENERATED, _on_income_generated)
	
	# Clear cached references
	_member_entities.clear()
	_territory_entities.clear()
	_business_entities.clear()

func add_funds(amount: float, source: String = "") -> bool:
	if amount < 0:
		Logger.warning("Attempted to add negative funds", "Faction", {"amount": amount})
		return false
	
	var old_funds = funds
	funds += amount
	income_this_period += amount
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.FACTION_FUNDS_CHANGED,
			{
				"faction_id": entity.id,
				"old_value": old_funds,
				"new_value": funds,
				"change": amount,
				"source": source
			}
		)
	
	Logger.debug("Faction funds increased", "Faction", {
		"faction": faction_name,
		"amount": amount,
		"new_total": funds,
		"source": source
	})
	
	return true

func spend_funds(amount: float, purpose: String = "") -> bool:
	if amount < 0:
		Logger.warning("Attempted to spend negative funds", "Faction", {"amount": amount})
		return false
	
	if funds < amount:
		Logger.info("Insufficient funds", "Faction", {
			"faction": faction_name,
			"requested": amount,
			"available": funds,
			"purpose": purpose
		})
		return false
	
	var old_funds = funds
	funds -= amount
	expenses_this_period += amount
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.FACTION_FUNDS_CHANGED,
			{
				"faction_id": entity.id,
				"old_value": old_funds,
				"new_value": funds,
				"change": -amount,
				"purpose": purpose
			}
		)
	
	return true

func add_supplies(amount: float) -> bool:
	if amount < 0:
		Logger.warning("Attempted to add negative supplies", "Faction", {"amount": amount})
		return false
	
	var old_supplies = supplies
	supplies += amount
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.FACTION_SUPPLIES_CHANGED,
			{
				"faction_id": entity.id,
				"old_value": old_supplies,
				"new_value": supplies,
				"change": amount
			}
		)
	
	return true

func consume_supplies(amount: float) -> bool:
	if amount < 0:
		Logger.warning("Attempted to consume negative supplies", "Faction", {"amount": amount})
		return false
	
	var old_supplies = supplies
	supplies = max(0, supplies - amount)
	
	# Emit event if supplies depleted
	if supplies == 0 and old_supplies > 0:
		Logger.warning("Faction supplies depleted", "Faction", {"faction": faction_name})
	
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.FACTION_SUPPLIES_CHANGED,
			{
				"faction_id": entity.id,
				"old_value": old_supplies,
				"new_value": supplies,
				"change": -amount
			}
		)
	
	return true

func calculate_supply_consumption() -> float:
	var base_rate = 1.0
	var member_count = _member_entities.size()
	var territory_count = _territory_entities.size()
	
	# More members and territories = more supply consumption
	supply_consumption_rate = base_rate * (member_count * 0.5 + territory_count * 2.0)
	
	# Add some variation
	supply_consumption_rate *= randf_range(0.9, 1.1)
	
	return supply_consumption_rate

func get_relationship(other_faction_id: String) -> RelationType:
	return relationships.get(other_faction_id, RelationType.NEUTRAL)

func set_relationship(other_faction_id: String, relation: RelationType) -> void:
	relationships[other_faction_id] = relation
	Logger.info("Faction relationship changed", "Faction", {
		"faction": faction_name,
		"other_faction": other_faction_id,
		"relation": RelationType.keys()[relation]
	})

func get_members() -> Array[Entity]:
	return _member_entities

func get_territories() -> Array[Entity]:
	return _territory_entities

func get_businesses() -> Array[Entity]:
	return _business_entities

func add_member(member_entity: Entity) -> void:
	if not _member_entities.has(member_entity):
		_member_entities.append(member_entity)

func remove_member(member_entity: Entity) -> void:
	_member_entities.erase(member_entity)

func add_territory(territory_entity: Entity) -> void:
	if not _territory_entities.has(territory_entity):
		_territory_entities.append(territory_entity)

func remove_territory(territory_entity: Entity) -> void:
	_territory_entities.erase(territory_entity)

func add_business(business_entity: Entity) -> void:
	if not _business_entities.has(business_entity):
		_business_entities.append(business_entity)

func remove_business(business_entity: Entity) -> void:
	_business_entities.erase(business_entity)

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	Validatable.validate_not_empty(faction_name, "faction_name", result)
	Validatable.validate_positive(funds, "funds", result)
	Validatable.validate_positive(supplies, "supplies", result)
	
	return result

func reset_period_stats() -> void:
	income_this_period = 0.0
	expenses_this_period = 0.0

func get_financial_summary() -> Dictionary:
	return {
		"funds": funds,
		"supplies": supplies,
		"income_this_period": income_this_period,
		"expenses_this_period": expenses_this_period,
		"net_income": income_this_period - expenses_this_period,
		"supply_consumption_rate": supply_consumption_rate
	}

# Event handlers
func _on_member_added(event: EventBus.Event) -> void:
	if event.data.get("faction_id") == entity.id:
		var member_entity = event.data.get("member_entity")
		if member_entity:
			add_member(member_entity)

func _on_member_removed(event: EventBus.Event) -> void:
	if event.data.get("faction_id") == entity.id:
		var member_entity = event.data.get("member_entity")
		if member_entity:
			remove_member(member_entity)

func _on_income_generated(event: EventBus.Event) -> void:
	if event.data.get("faction_id") == entity.id:
		var amount = event.data.get("amount", 0.0)
		var source = event.data.get("source", "")
		add_funds(amount, source)

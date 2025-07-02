# OrderComponent.gd - Component for order data and execution
extends Component
class_name OrderComponent

enum OrderType {
	BUY_SUPPLIES,
	SPY,
	ATTACK,
	DEFEND,
	RECRUIT,
	PATROL,
	NEGOTIATE,
	SABOTAGE
}

@export var order_type: OrderType = OrderType.PATROL
@export var priority: int = 50
@export var target_id: String = ""
@export var issued_at: float = 0.0
@export var issued_by: String = ""  # Entity ID of issuer

# Time requirements (in seconds)
@export var travel_time: float = 5.0
@export var work_time: float = 10.0
@export var return_time: float = 5.0

# Order parameters
@export var parameters: Dictionary = {}

# Execution state
var assigned_to: String = ""  # Entity ID of assigned member
var status: String = "pending"  # pending, assigned, in_progress, completed, failed, cancelled
var started_at: float = 0.0
var completed_at: float = 0.0
var failure_reason: String = ""

# Success conditions
var required_funds: float = 0.0
var required_supplies: float = 0.0
var success_chance: float = 0.8

func get_component_name() -> String:
	return "OrderComponent"

func _on_attached(entity: Entity) -> void:
	issued_at = Time.get_ticks_msec() / 1000.0
	_calculate_requirements()
	
	# Subscribe to relevant events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.ORDER_ASSIGNED, _on_order_assigned)
		event_bus.subscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)

func _on_detached(entity: Entity) -> void:
	# Unsubscribe from events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.ORDER_ASSIGNED, _on_order_assigned)
		event_bus.unsubscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)

func _calculate_requirements() -> void:
	# Calculate requirements based on order type
	match order_type:
		OrderType.BUY_SUPPLIES:
			required_funds = parameters.get("amount", 500.0)
			travel_time = 5.0
			work_time = 2.0
			return_time = 5.0
			priority = 80
			
		OrderType.DEFEND:
			required_supplies = 50.0
			travel_time = 1.0
			work_time = 10.0
			return_time = 1.0
			priority = 90
			
		OrderType.SPY:
			required_funds = 100.0
			travel_time = 4.0
			work_time = 6.0
			return_time = 4.0
			priority = 60
			success_chance = 0.7
			
		OrderType.ATTACK:
			required_funds = 200.0
			required_supplies = 100.0
			travel_time = 5.0
			work_time = 8.0
			return_time = 5.0
			priority = 50
			success_chance = 0.6
			
		OrderType.RECRUIT:
			required_funds = 1500.0
			travel_time = 3.0
			work_time = 4.0
			return_time = 3.0
			priority = 40
			
		OrderType.PATROL:
			travel_time = 2.0
			work_time = 5.0
			return_time = 2.0
			priority = 30
			
		OrderType.NEGOTIATE:
			required_funds = 300.0
			travel_time = 3.0
			work_time = 10.0
			return_time = 3.0
			priority = 70
			success_chance = 0.5
			
		OrderType.SABOTAGE:
			required_supplies = 75.0
			travel_time = 6.0
			work_time = 5.0
			return_time = 6.0
			priority = 45
			success_chance = 0.65

func get_total_time() -> float:
	return travel_time + work_time + return_time

func can_be_executed_by(faction_comp: FactionComponent) -> bool:
	if not faction_comp:
		return false
	
	# Check resource requirements
	if faction_comp.funds < required_funds:
		Logger.debug("Order cannot be executed: insufficient funds", "Order", {
			"required": required_funds,
			"available": faction_comp.funds
		})
		return false
	
	if faction_comp.supplies < required_supplies:
		Logger.debug("Order cannot be executed: insufficient supplies", "Order", {
			"required": required_supplies,
			"available": faction_comp.supplies
		})
		return false
	
	# Check specific conditions
	match order_type:
		OrderType.SPY:
			# Can't spy if already negotiating
			if parameters.get("negotiating", false):
				return false
		
		OrderType.DEFEND:
			# Always allow defense orders
			pass
	
	return true

func execute(executor_entity: Entity) -> bool:
	var member_comp = executor_entity.get_component("GangMemberComponent")
	if not member_comp:
		Logger.error("Executor missing GangMemberComponent", "Order")
		return false
	
	var faction_entity = _get_faction_entity(member_comp.faction_id)
	if not faction_entity:
		Logger.error("Faction not found", "Order", {"faction_id": member_comp.faction_id})
		return false
	
	var faction_comp = faction_entity.get_component("FactionComponent")
	
	# Deduct resources
	if required_funds > 0:
		if not faction_comp.spend_funds(required_funds, "Order: " + OrderType.keys()[order_type]):
			failure_reason = "Insufficient funds"
			return false
	
	if required_supplies > 0:
		if not faction_comp.consume_supplies(required_supplies):
			failure_reason = "Insufficient supplies"
			return false
	
	status = "in_progress"
	started_at = Time.get_ticks_msec() / 1000.0
	
	Logger.info("Order execution started", "Order", {
		"type": OrderType.keys()[order_type],
		"executor": member_comp.member_name,
		"target": target_id
	})
	
	return true

func complete(executor_entity: Entity) -> Dictionary:
	var member_comp = executor_entity.get_component("GangMemberComponent")
	if not member_comp:
		return {"success": false, "reason": "Invalid executor"}
	
	# Check success chance
	var roll = randf()
	var success = roll <= success_chance * member_comp.get_efficiency()
	
	status = "completed" if success else "failed"
	completed_at = Time.get_ticks_msec() / 1000.0
	
	var result = {
		"success": success,
		"roll": roll,
		"chance": success_chance,
		"efficiency": member_comp.get_efficiency()
	}
	
	# Apply order effects
	if success:
		result.merge(_apply_success_effects(executor_entity))
	else:
		failure_reason = "Failed execution (bad roll)"
		result["reason"] = failure_reason
	
	Logger.info("Order completed", "Order", {
		"type": OrderType.keys()[order_type],
		"success": success,
		"executor": member_comp.member_name
	})
	
	return result

func _apply_success_effects(executor_entity: Entity) -> Dictionary:
	var effects = {}
	var member_comp = executor_entity.get_component("GangMemberComponent")
	var faction_entity = _get_faction_entity(member_comp.faction_id)
	var faction_comp = faction_entity.get_component("FactionComponent") if faction_entity else null
	
	match order_type:
		OrderType.BUY_SUPPLIES:
			var amount = parameters.get("amount", 500.0)
			if faction_comp:
				faction_comp.add_supplies(amount)
			effects["supplies_gained"] = amount
			
		OrderType.SPY:
			# Add intel
			if faction_comp and target_id:
				faction_comp.intel[target_id] = {
					"gathered_at": Time.get_ticks_msec() / 1000.0,
					"quality": randf_range(0.5, 1.0)
				}
			effects["intel_gathered"] = true
			
		OrderType.RECRUIT:
			# Create new member
			effects["new_member"] = true
			effects["recruitment_cost"] = required_funds
			
		OrderType.PATROL:
			# Increase territory safety
			effects["territory_secured"] = true
			
		OrderType.NEGOTIATE:
			# Improve relations
			if faction_comp and target_id:
				faction_comp.set_relationship(target_id, FactionComponent.RelationType.ALLY)
			effects["relationship_improved"] = true
	
	return effects

func _get_faction_entity(faction_id: String) -> Entity:
	if Engine.has_singleton("EntityManager"):
		return Engine.get_singleton("EntityManager").get_entity(faction_id)
	return null

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	if order_type < 0 or order_type >= OrderType.size():
		result.add_error("Invalid order type: " + str(order_type))
	
	Validatable.validate_positive(travel_time, "travel_time", result)
	Validatable.validate_positive(work_time, "work_time", result)
	Validatable.validate_positive(return_time, "return_time", result)
	Validatable.validate_in_range(priority, 0, 100, "priority", result)
	Validatable.validate_in_range(success_chance, 0, 1, "success_chance", result)
	
	return result

func get_display_name() -> String:
	return OrderType.keys()[order_type].replace("_", " ").capitalize()

func get_description() -> String:
	match order_type:
		OrderType.BUY_SUPPLIES:
			return "Purchase supplies for the faction"
		OrderType.SPY:
			return "Gather intelligence on target faction"
		OrderType.ATTACK:
			return "Launch an attack on enemy territory"
		OrderType.DEFEND:
			return "Defend faction territory from threats"
		OrderType.RECRUIT:
			return "Recruit new gang members"
		OrderType.PATROL:
			return "Patrol territory to maintain order"
		OrderType.NEGOTIATE:
			return "Negotiate with another faction"
		OrderType.SABOTAGE:
			return "Sabotage enemy operations"
		_:
			return "Unknown order"

# Event handlers
func _on_order_assigned(event: EventBus.Event) -> void:
	if event.data.get("order_id") == entity.id:
		assigned_to = event.data.get("member_id", "")
		status = "assigned"

func _on_order_completed(event: EventBus.Event) -> void:
	if event.data.get("order_id") == entity.id:
		# Order completion is handled by the member component
		pass

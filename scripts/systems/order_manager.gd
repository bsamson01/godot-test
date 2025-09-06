# OrderManager.gd - Manages order creation, assignment, and execution
extends Node
class_name OrderManager

# Order queues by faction
var faction_orders: Dictionary = {} # faction_id -> Array[Entity]

# Order assignment tracking
var assigned_orders: Dictionary = {} # member_id -> Entity

# Order execution tracking
var executing_orders: Dictionary = {} # order_id -> Entity

func _ready():
	# Subscribe to relevant events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.ORDER_CREATED, _on_order_created)
		event_bus.subscribe(EventBus.EventType.ORDER_ASSIGNED, _on_order_assigned)
		event_bus.subscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)
		event_bus.subscribe(EventBus.EventType.ORDER_FAILED, _on_order_failed)

func create_order(order_type: Order.OrderType, faction_id: String, data: Dictionary = {}) -> Entity:
	# Create order entity
	var order_entity = Engine.get_singleton("EntityManager").create_entity("order")
	
	# Add OrderComponent
	var order_comp = OrderComponent.new()
	order_comp.target_id = data.get("target_id", "")
	order_comp.parameters = data
	order_comp.issued_by = data.get("issued_by", "")
	order_entity.add_component(order_comp)
	
	# Set the order type
	order_comp.order = Order.new()
	order_comp.order.order_type = order_type
	order_comp.order.data = data
	order_comp.order.target_id = data.get("target_id", "")
	order_comp.order.issued_tick = int(Time.get_ticks_msec() / 1000.0)
	
	# Add to faction queue
	if not faction_orders.has(faction_id):
		faction_orders[faction_id] = []
	faction_orders[faction_id].append(order_entity)
	
	# Emit event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ORDER_CREATED,
			{
				"order_id": order_entity.id,
				"faction_id": faction_id,
				"order_type": order_type
			}
		)
	
	Logger.warning("Order created", "OrderManager", {
		"order_id": order_entity.id,
		"faction_id": faction_id,
		"order_type": Order.OrderType.keys()[order_type]
	})
	
	return order_entity

func assign_order_to_member(order_entity: Entity, member_entity: Entity) -> bool:
	var order_comp = order_entity.get_component("OrderComponent")
	var member_comp = member_entity.get_component("GangMemberComponent")
	
	if not order_comp or not member_comp:
		Logger.error("Invalid entities for order assignment", "OrderManager")
		return false
	
	# Check if member can accept the order
	if not member_comp.is_available():
		Logger.warning("Member not available for order assignment", "OrderManager", {
			"member": member_comp.member_name,
			"state": member_comp.current_state,
			"order_type": Order.OrderType.keys()[order_comp.get_order_type()]
		})
		return false
	
	# Check if faction can execute the order
	var faction_entity = Engine.get_singleton("EntityManager").get_entity(member_comp.faction_id)
	if not faction_entity:
		Logger.error("Faction not found for order assignment", "OrderManager")
		return false
	
	var faction_comp = faction_entity.get_component("FactionComponent")
	if not faction_comp:
		Logger.error("Faction missing FactionComponent", "OrderManager")
		return false
	
	if not order_comp.can_be_executed_by(faction_comp):
		Logger.warning("Order cannot be executed by faction", "OrderManager", {
			"order_id": order_entity.id,
			"faction_id": member_comp.faction_id,
			"reason": order_comp.get_failure_reason()
		})
		return false
	
	# Assign the order
	if member_comp.assign_order(order_entity):
		assigned_orders[member_entity.id] = order_entity
		executing_orders[order_entity.id] = member_entity
		
		# Remove from faction queue
		if faction_orders.has(member_comp.faction_id):
			faction_orders[member_comp.faction_id].erase(order_entity)
		
		Logger.info("Order assigned to member", "OrderManager", {
			"order_id": order_entity.id,
			"member": member_comp.member_name,
			"faction_id": member_comp.faction_id
		})
		
		return true
	
	return false

func get_available_orders(faction_id: String) -> Array[Entity]:
	return faction_orders.get(faction_id, [])

func get_member_order(member_id: String) -> Entity:
	return assigned_orders.get(member_id, null)

func cancel_order(order_entity: Entity, reason: String = "") -> void:
	var order_comp = order_entity.get_component("OrderComponent")
	if not order_comp:
		return
	
	# Find assigned member
	var assigned_member_id = order_comp.order.assigned_to
	if assigned_member_id != "":
		var member_entity = Engine.get_singleton("EntityManager").get_entity(assigned_member_id)
		if member_entity:
			var member_comp = member_entity.get_component("GangMemberComponent")
			if member_comp:
				member_comp.cancel_order(reason)
		
		# Remove from tracking
		assigned_orders.erase(assigned_member_id)
		executing_orders.erase(order_entity.id)
	
	# Remove from faction queue
	for faction_id in faction_orders:
		faction_orders[faction_id].erase(order_entity)
	
	# Mark order as cancelled
	order_comp.order.status = Order.OrderStatus.CANCELLED
	
	Logger.info("Order cancelled", "OrderManager", {
		"order_id": order_entity.id,
		"reason": reason
	})

# Event handlers
func _on_order_created(_event: EventBus.Event) -> void:
	# Order creation is handled in create_order()
	pass

func _on_order_assigned(_event: EventBus.Event) -> void:
	# Order assignment is handled in assign_order_to_member()
	pass

func _on_order_completed(event: EventBus.Event) -> void:
	var order_id = event.data.get("order_id")
	var member_id = event.data.get("member_id")
	
	# Remove from tracking
	assigned_orders.erase(member_id)
	executing_orders.erase(order_id)
	
	Logger.info("Order completed", "OrderManager", {
		"order_id": order_id,
		"member_id": member_id
	})

func _on_order_failed(event: EventBus.Event) -> void:
	var order_id = event.data.get("order_id")
	var member_id = event.data.get("member_id")
	
	# Remove from tracking
	assigned_orders.erase(member_id)
	executing_orders.erase(order_id)
	
	Logger.info("Order failed", "OrderManager", {
		"order_id": order_id,
		"member_id": member_id
	})

func get_stats() -> Dictionary:
	return {
		"faction_orders": faction_orders.size(),
		"assigned_orders": assigned_orders.size(),
		"executing_orders": executing_orders.size()
	}

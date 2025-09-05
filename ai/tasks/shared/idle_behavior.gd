# idle_behavior.gd - Idle behavior when no orders
extends BTAction

func _tick(_delta: float) -> Status:
	var entity_id = blackboard.get_var("entity_id")
	if not entity_id:
		return FAILURE
	
	# Get entity from EntityManager
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return FAILURE
	
	var entity = entity_manager.get_entity(entity_id)
	if not entity:
		return FAILURE
	
	# Get gang member component
	var member_comp = entity.get_component("GangMemberComponent")
	if not member_comp:
		return FAILURE
	
	# Check if member is available for new orders
	if member_comp.is_available():
		# Try to get a new order from OrderManager
		if Engine.has_singleton("OrderManager"):
			var order_manager = Engine.get_singleton("OrderManager")
			var available_orders = order_manager.get_available_orders(member_comp.faction_id)
			
			# Try to assign an order
			for order_entity in available_orders:
				if order_manager.assign_order_to_member(order_entity, entity):
					blackboard.set_var("has_order", true)
					blackboard.set_var("current_action", "assigned_new_order")
					return SUCCESS
		
		# No orders available, just idle
		blackboard.set_var("current_action", "idle")
		return RUNNING
	else:
		# Member is busy with something else
		blackboard.set_var("current_action", "busy")
		return RUNNING

extends BTCondition

# The goal string to match against current order (e.g., 'buy_supplies', 'patrol_territory')
@export var goal_to_match: String = ""

func _tick(_delta: float) -> Status:
	# Validate input
	if goal_to_match.is_empty():
		push_error("is_valid_goal: goal_to_match is empty")
		return FAILURE
	
	# Get entity ID from blackboard
	var entity_id = blackboard.get_var("entity_id")
	if not entity_id:
		# Try to get entity_id from agent if available
		var agent_node = blackboard.get_var("agent")
		if agent_node and agent_node.has_method("get") and agent_node.member_id:
			entity_id = agent_node.member_id
			blackboard.set_var("entity_id", entity_id)
		else:
			# Entity ID not yet available, wait
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
	
	# Check if member has a current order
	if not member_comp.current_order:
		return FAILURE
	
	# Get the order component
	var order_comp = member_comp.current_order.get_component("OrderComponent")
	if not order_comp:
		return FAILURE
	
	# Convert goal string to OrderType enum
	var target_order_type = _string_to_order_type(goal_to_match)
	if target_order_type == -1:
		push_error("is_valid_goal: Unknown goal type '" + goal_to_match + "'")
		return FAILURE
	
	# Compare current order type with target
	var current_order_type = order_comp.get_order_type()
	if current_order_type == target_order_type:
		# Store additional info in blackboard for debugging/logging
		blackboard.set_var("matched_goal", goal_to_match)
		blackboard.set_var("current_order_name", order_comp.order.name())
		return SUCCESS
	
	return FAILURE

# Convert string goal to Order.OrderType enum
func _string_to_order_type(goal_string: String) -> int:
	var normalized_goal = goal_string.to_lower().strip_edges()
	
	match normalized_goal:
		"buy_supplies":
			return Order.OrderType.BUY_SUPPLIES
		"sell_goods":
			return Order.OrderType.SELL_GOODS
		"patrol_territory":
			return Order.OrderType.PATROL_TERRITORY
		"attack_enemy":
			return Order.OrderType.ATTACK_ENEMY
		"defend_territory":
			return Order.OrderType.DEFEND_TERRITORY
		"collect_protection":
			return Order.OrderType.COLLECT_PROTECTION
		"recruit_members":
			return Order.OrderType.RECRUIT_MEMBERS
		"recruit_specific_npc":
			return Order.OrderType.RECRUIT_SPECIFIC_NPC
		"scout_enemy":
			return Order.OrderType.SCOUT_ENEMY
		"spy":
			return Order.OrderType.SPY
		"negotiate":
			return Order.OrderType.NEGOTIATE
		"sabotage":
			return Order.OrderType.SABOTAGE
		_:
			return -1  # Unknown goal type

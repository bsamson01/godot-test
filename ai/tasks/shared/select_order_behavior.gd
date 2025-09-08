extends BTAction

# Preload behavior trees for each order type
var BehaviorTrees = {
	Order.OrderType.BUY_SUPPLIES: preload("res://ai/behaviors/buy_supplies_behavior.tres"),
	Order.OrderType.SELL_GOODS: preload("res://ai/behaviors/sell_goods_behavior.tres"),
	Order.OrderType.PATROL_TERRITORY: preload("res://ai/behaviors/patrol_behavior.tres"),
	# Order.OrderType.ATTACK_ENEMY: preload("res://ai/behaviors/attack_enemy_behavior_new.tres"),
	# Order.OrderType.DEFEND_TERRITORY: preload("res://ai/behaviors/defend_territory_behavior_new.tres"),
	# Order.OrderType.COLLECT_PROTECTION: preload("res://ai/behaviors/collect_protection_behavior_new.tres"),
	# Order.OrderType.RECRUIT_MEMBERS: preload("res://ai/behaviors/recruit_behavior.tres"),
	# Order.OrderType.RECRUIT_SPECIFIC_NPC: preload("res://ai/behaviors/recruit_behavior_new.tres"),
	# Order.OrderType.SCOUT_ENEMY: preload("res://ai/behaviors/scout_enemy_behavior_new.tres"),
	# Order.OrderType.SPY: preload("res://ai/behaviors/spy_behavior_new.tres"),
	# Order.OrderType.NEGOTIATE: preload("res://ai/behaviors/negotiate_behavior_new.tres"),
	# Order.OrderType.SABOTAGE: preload("res://ai/behaviors/sabotage_behavior_new.tres")
}

var _current_subtree: BehaviorTree = null
var _subtree_instance: BTInstance = null
var _instantiation_failed: bool = false

func _enter():
	# Reset the failure flag
	_instantiation_failed = false
	
	# Safe get with fallback
	var order_type
	if blackboard.has_var("order_type"):
		order_type = blackboard.get_var("order_type")
	else:
		# Set default and log warning
		order_type = -1
		blackboard.set_var("order_type", order_type)
		push_warning("SELECT_ORDER_BEHAVIOR: order_type not set, using default")
	
	if not order_type in BehaviorTrees:
		push_error("SELECT_ORDER_BEHAVIOR: Unknown order type: " + str(order_type))
		_instantiation_failed = true
		return
		
	# Load the appropriate behavior tree
	var behavior_tree = BehaviorTrees[order_type]
	if behavior_tree:
		_current_subtree = behavior_tree

		print("SELECT_ORDER_BEHAVIOR: Instantiating behavior tree for order type: ", order_type)
		# Get the scene root from the agent
		var current_scene = null
		if agent and agent.get_tree():
			current_scene = agent.get_tree().current_scene
		
		_subtree_instance = _current_subtree.instantiate(agent, blackboard, agent, current_scene)
		
		if not _subtree_instance:
			push_error("SELECT_ORDER_BEHAVIOR: Failed to instantiate behavior tree for order type: " + str(order_type))
			_instantiation_failed = true
		else:
			print("SELECT_ORDER_BEHAVIOR: Successfully instantiated behavior tree for order type: ", order_type)
	else:
		push_error("SELECT_ORDER_BEHAVIOR: No behavior tree found for order type: " + str(order_type))
		_instantiation_failed = true

func _tick(delta: float) -> Status:
	# If instantiation failed, don't keep trying
	if _instantiation_failed:
		return FAILURE
	
	if not _subtree_instance:
		return FAILURE
		
	var result = _subtree_instance.update(delta)
	
	if result != Status.RUNNING:
		_subtree_instance = null
		
	return result

func _exit():
	if _subtree_instance:
		_subtree_instance = null

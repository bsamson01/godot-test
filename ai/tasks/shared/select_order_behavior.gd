extends BTAction

# Preload behavior trees for each order type
var BehaviorTrees = {
	Order.OrderType.BUY_SUPPLIES: preload("res://ai/behaviors/buy_supplies_behavior_new.tres"),
	Order.OrderType.SELL_GOODS: preload("res://ai/behaviors/sell_goods_behavior_new.tres"),
	Order.OrderType.PATROL_TERRITORY: preload("res://ai/behaviors/patrol_behavior_new.tres"),
	Order.OrderType.ATTACK_ENEMY: preload("res://ai/behaviors/attack_enemy_behavior_new.tres"),
	Order.OrderType.DEFEND_TERRITORY: preload("res://ai/behaviors/defend_territory_behavior_new.tres"),
	Order.OrderType.COLLECT_PROTECTION: preload("res://ai/behaviors/collect_protection_behavior_new.tres"),
	Order.OrderType.RECRUIT_MEMBERS: preload("res://ai/behaviors/recruit_behavior.tres"),
	Order.OrderType.RECRUIT_SPECIFIC_NPC: preload("res://ai/behaviors/recruit_behavior_new.tres"),
	Order.OrderType.SCOUT_ENEMY: preload("res://ai/behaviors/scout_enemy_behavior_new.tres"),
	Order.OrderType.SPY: preload("res://ai/behaviors/spy_behavior_new.tres"),
	Order.OrderType.NEGOTIATE: preload("res://ai/behaviors/negotiate_behavior_new.tres"),
	Order.OrderType.SABOTAGE: preload("res://ai/behaviors/sabotage_behavior_new.tres")
}

var _current_subtree: BTTask = null
var _subtree_instance: BTTask = null

func _enter():
	var order_type = blackboard.get_var("order_type")
	if not order_type in BehaviorTrees:
		push_error("Unknown order type: " + str(order_type))
		return
		
	# Load the appropriate behavior tree
	var behavior_tree = BehaviorTrees[order_type]
	if behavior_tree:
		_current_subtree = behavior_tree
		_subtree_instance = _current_subtree.instantiate(agent, blackboard)
		_subtree_instance._enter()

func _tick(delta: float) -> Status:
	if not _subtree_instance:
		return FAILURE
		
	var result = _subtree_instance._tick(delta)
	
	if result != Status.RUNNING:
		_subtree_instance._exit()
		_subtree_instance = null
		
	return result

func _exit():
	if _subtree_instance:
		_subtree_instance._exit()
		_subtree_instance = null

extends BTAction

# Preload behavior trees for each order type
const BehaviorTrees = {
	Order.TYPE_BUY_SUPPLIES: preload("res://ai/behaviors/buy_supplies_behavior.tres"),
	Order.TYPE_SELL_GOODS: preload("res://ai/behaviors/sell_goods_behavior.tres"),
	Order.TYPE_PATROL_TERRITORY: preload("res://ai/behaviors/patrol_behavior.tres"),
	Order.TYPE_ATTACK_ENEMY: preload("res://ai/behaviors/attack_behavior.tres"),
	Order.TYPE_DEFEND_TERRITORY: preload("res://ai/behaviors/defend_behavior.tres"),
	Order.TYPE_COLLECT_PROTECTION: preload("res://ai/behaviors/collect_protection_behavior.tres"),
	Order.TYPE_RECRUIT_MEMBERS: preload("res://ai/behaviors/recruit_behavior.tres"),
	Order.TYPE_SCOUT_ENEMY: preload("res://ai/behaviors/scout_behavior.tres")
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

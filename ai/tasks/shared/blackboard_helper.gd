# BlackboardHelper.gd - Utility functions for safe blackboard variable access
class_name BlackboardHelper

# Safe get with automatic default setting
static func safe_get_var(blackboard: Blackboard, key: String, default_value):
	if blackboard.has_var(key):
		return blackboard.get_var(key)
	else:
		# Set the default value for future use
		blackboard.set_var(key, default_value)
		return default_value

# Safe get without setting (for read-only access)
static func safe_get_var_readonly(blackboard: Blackboard, key: String, default_value):
	if blackboard.has_var(key):
		return blackboard.get_var(key)
	else:
		return default_value

# Initialize common blackboard variables with defaults
static func initialize_common_variables(blackboard: Blackboard):
	# Movement and positioning
	safe_get_var(blackboard, "pos", Vector3.ZERO)
	safe_get_var(blackboard, "target_location", Vector3.ZERO)
	safe_get_var(blackboard, "patrol_center", Vector3.ZERO)
	safe_get_var(blackboard, "patrol_radius", 20.0)
	
	# Order execution results
	safe_get_var(blackboard, "supplies_bought", 0)
	safe_get_var(blackboard, "supplies_cost", 0.0)
	safe_get_var(blackboard, "goods_sold", 0)
	safe_get_var(blackboard, "sale_revenue", 0.0)
	safe_get_var(blackboard, "threats_detected", [])
	safe_get_var(blackboard, "combat_result", "unknown")
	safe_get_var(blackboard, "enemies_defeated", 0)
	safe_get_var(blackboard, "protection_money", 0.0)
	safe_get_var(blackboard, "businesses_visited", 0)
	
	# State tracking
	safe_get_var(blackboard, "current_action", "idle")
	safe_get_var(blackboard, "last_update_time", 0.0)

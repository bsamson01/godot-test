extends BehaviorTree
class_name MasterAIBehavior

# This is the main entry point for all AI behaviors
# It checks for orders and executes the appropriate behavior tree

static func create_behavior_tree() -> BTTask:
	# Root selector - tries each option in order
	var root = BTSelector.new()
	
	# Priority 1: Check for emergency situations (health, threats)
	var emergency_sequence = BTSequence.new()
	emergency_sequence.add_child(_create_emergency_check())
	emergency_sequence.add_child(_create_emergency_response())
	root.add_child(emergency_sequence)
	
	# Priority 2: Execute orders
	var order_sequence = BTSequence.new()
	order_sequence.add_child(preload("res://ai/tasks/shared/check_for_order.gd").new())
	order_sequence.add_child(preload("res://ai/tasks/shared/select_order_behavior.gd").new())
	order_sequence.add_child(preload("res://ai/tasks/shared/complete_order.gd").new())
	root.add_child(order_sequence)
	
	# Priority 3: Idle behavior
	var idle_sequence = BTSequence.new()
	idle_sequence.add_child(preload("res://ai/tasks/shared/idle_behavior.gd").new())
	idle_sequence.add_child(preload("res://ai/tasks/shared/move_to_location.gd").new())
	root.add_child(idle_sequence)
	
	return root

static func _create_emergency_check() -> BTCondition:
	# Custom condition to check for emergencies
	var check = BTCondition.new()
	check.set_script(preload("res://ai/tasks/shared/check_emergency.gd"))
	return check

static func _create_emergency_response() -> BTSelector:
	var response = BTSelector.new()
	
	# Flee if low health
	var flee_sequence = BTSequence.new()
	flee_sequence.add_child(_create_low_health_check())
	flee_sequence.add_child(preload("res://ai/tasks/shared/flee_to_safety.gd").new())
	response.add_child(flee_sequence)
	
	# Defend if under attack
	var defend_sequence = BTSequence.new()
	defend_sequence.add_child(_create_under_attack_check())
	defend_sequence.add_child(preload("res://ai/tasks/shared/defend_self.gd").new())
	response.add_child(defend_sequence)
	
	return response

static func _create_low_health_check() -> BTCondition:
	var check = BTCondition.new()
	check.set_script(preload("res://ai/tasks/shared/check_health.gd"))
	return check

static func _create_under_attack_check() -> BTCondition:
	var check = BTCondition.new()
	check.set_script(preload("res://ai/tasks/shared/check_under_attack.gd"))
	return check
extends BTAction

@export var search_radius: float = 50.0
@export var prefer_closest: bool = true

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return FAILURE
		
	var order = blackboard.get_var("current_order")
	var target_faction_id = order.data.get("target_faction", "") if order else ""
	
	var enemies = []
	var agent_pos = agent.global_transform.origin
	
	# Find all enemy gang members
	for potential_enemy in agent.get_tree().get_nodes_in_group("gang_members"):
		if potential_enemy == agent:
			continue
			
		var enemy_member = potential_enemy.get_member() if potential_enemy.has_method("get_member") else null
		if not enemy_member:
			continue
			
		# Check if it's an enemy
		var is_enemy = false
		if target_faction_id and enemy_member.faction_id == target_faction_id:
			is_enemy = true
		elif enemy_member.faction_id != member.faction_id:
			is_enemy = true
			
		if is_enemy:
			var distance = agent_pos.distance_to(potential_enemy.global_transform.origin)
			if distance <= search_radius:
				enemies.append({
					"target": potential_enemy,
					"member": enemy_member,
					"distance": distance,
					"strength": enemy_member.level
				})
	
	if enemies.is_empty():
		blackboard.set_var("attack_failure_reason", "no_targets_found")
		return FAILURE
		
	# Sort by preference
	if prefer_closest:
		enemies.sort_custom(func(a, b): return a.distance < b.distance)
	else:
		# Sort by weakest first
		enemies.sort_custom(func(a, b): return a.strength < b.strength)
		
	# Select target
	var target = enemies[0]
	blackboard.set_var("attack_target", target.target)
	blackboard.set_var("attack_target_member", target.member)
	blackboard.set_var("target_location", target.target.global_transform.origin)
	
	return SUCCESS

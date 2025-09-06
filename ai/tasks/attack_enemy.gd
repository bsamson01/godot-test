# attack_enemy.gd - Attack enemy task
extends BTAction

var target_enemy: Node = null
var enemy_location: Vector3 = Vector3.ZERO
var attack_timer: float = 0.0
var attack_duration: float = 6.0

func _tick(_delta: float) -> Status:
	# Find enemy if not already found
	if not target_enemy:
		if not _find_enemy():
			return FAILURE
	
	# Move to enemy
	agent.set_movement_target(enemy_location)
	
	# Check if we're close enough to attack
	var current_pos = agent.get_current_position()
	var distance_to_enemy = current_pos.distance_to(enemy_location)
	
	if distance_to_enemy < 3.0:  # Close enough to attack
		return _perform_attack(_delta)
	
	agent.updateLabel('Approaching enemy (%.1fm)' % distance_to_enemy)
	return RUNNING

func _find_enemy() -> bool:
	# Get target faction from order parameters
	var current_order = blackboard.get_var("current_order", null)
	var target_faction_id = ""
	
	if current_order:
		var order_comp = current_order.get_component("OrderComponent")
		if order_comp:
			target_faction_id = order_comp.parameters.get("target_faction", "")
	
	# Find the nearest enemy gang member from target faction
	var enemies = agent.get_tree().get_nodes_in_group("gang_members")
	if enemies.is_empty():
		agent.updateLabel('No enemies found')
		return false
	
	var nearest_enemy = null
	var nearest_distance = INF
	var current_pos = agent.get_current_position()
	
	# Get our faction ID
	var our_faction_id = _get_our_faction_id()
	if our_faction_id == "":
		agent.updateLabel('No faction ID')
		return false
	
	for enemy in enemies:
		if enemy == agent:  # Skip self
			continue
		
		# Check if this is from the target faction
		var enemy_faction_id = _get_enemy_faction_id(enemy)
		if target_faction_id != "":
			# Attack specific faction
			if enemy_faction_id == target_faction_id:
				var distance = current_pos.distance_to(enemy.global_position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_enemy = enemy
		else:
			# Attack any enemy faction (fallback)
			if enemy_faction_id != "" and enemy_faction_id != our_faction_id:
				var distance = current_pos.distance_to(enemy.global_position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_enemy = enemy
	
	if not nearest_enemy:
		agent.updateLabel('No target enemies found')
		return false
	
	target_enemy = nearest_enemy
	enemy_location = nearest_enemy.global_position
	return true

func _perform_attack(_delta: float) -> Status:
	attack_timer += _delta
	
	# Update enemy position
	if target_enemy:
		enemy_location = target_enemy.global_position
		agent.set_movement_target(enemy_location)
	
	# Check if attack is complete
	if attack_timer >= attack_duration:
		# Attack completed
		_apply_attack_damage()
		agent.updateLabel('Attack completed')
		return SUCCESS
	
	# Show attack progress
	var progress = int((attack_timer / attack_duration) * 100)
	agent.updateLabel('Attacking enemy (%d%%)' % progress)
	return RUNNING

func _apply_attack_damage() -> void:
	# Apply damage to enemy (placeholder - no health system yet)
	if target_enemy and target_enemy.has_method("updateLabel"):
		target_enemy.updateLabel('Under attack!')
	
	# Get our faction for rewards
	if "member_id" in agent and agent.member_id != "":
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(agent.member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp and member_comp.faction_id != "":
					var faction_entity = entity_manager.get_entity(member_comp.faction_id)
					if faction_entity:
						var faction_comp = faction_entity.get_component("FactionComponent")
						if faction_comp:
							# Gain some funds from successful attack
							faction_comp.funds += 100
							
							Logger.info("Enemy attacked", "AttackEnemy", {
								"faction": faction_comp.faction_name,
								"funds_gained": 100,
								"new_funds": faction_comp.funds
							})

func _get_our_faction_id() -> String:
	if "member_id" in agent and agent.member_id != "":
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(agent.member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					return member_comp.faction_id
	return ""

func _get_enemy_faction_id(enemy: Node) -> String:
	if enemy.has_method("get") and enemy.get("member_id"):
		var member_id = enemy.get("member_id")
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					return member_comp.faction_id
	return ""

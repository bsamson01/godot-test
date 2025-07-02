extends BTCondition

@export var threat_detection_radius: float = 15.0
@export var damage_threshold: float = 5.0  # Minimum damage to consider as "under attack"

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member:
		return FAILURE
	
	var agent_pos = agent.global_transform.origin
	var threats = []
	var total_threat_level = 0.0
	
	# Check for nearby enemy gang members
	for potential_threat in agent.get_tree().get_nodes_in_group("gang_members"):
		if potential_threat == agent:
			continue
			
		var threat_member = potential_threat.get_member() if potential_threat.has_method("get_member") else null
		if threat_member and threat_member.faction_id != member.faction_id:
			var distance = agent_pos.distance_to(potential_threat.global_transform.origin)
			if distance <= threat_detection_radius:
				# Check if threat is aggressive (has attack order targeting us)
				var threat_orders = WorldState.get_orders_for_member(threat_member.id)
				for order in threat_orders:
					if order.type == Order.TYPE_ATTACK_ENEMY and order.status == Order.STATUS_IN_PROGRESS:
						# Calculate threat level based on distance and member stats
						var threat_level = 1.0 / max(1.0, distance)
						if threat_member.role == "Enforcer":
							threat_level *= 1.5
						elif threat_member.role == "Sniper":
							threat_level *= 1.3
						
						threats.append({
							"member": threat_member,
							"node": potential_threat,
							"distance": distance,
							"threat_level": threat_level
						})
						total_threat_level += threat_level
						break
	
	# Check if we've taken recent damage (simplified - in a real game you'd track damage events)
	var recent_damage = blackboard.get_var("recent_damage") or 0.0
	if recent_damage > damage_threshold:
		total_threat_level += recent_damage / 10.0
	
	if not threats.is_empty() or total_threat_level > 0.5:
		blackboard.set_var("under_attack", true)
		blackboard.set_var("threats", threats)
		blackboard.set_var("threat_level", total_threat_level)
		blackboard.set_var("nearest_threat_distance", threats[0].distance if not threats.is_empty() else 999.0)
		return SUCCESS
	
	# Not under attack
	blackboard.erase_var("under_attack")
	blackboard.erase_var("threats")
	blackboard.erase_var("threat_level")
	blackboard.erase_var("nearest_threat_distance")
	return FAILURE 

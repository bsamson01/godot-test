extends BTAction

func _tick(_delta: float) -> Status:
	var member = agent.get_member() if agent.has_method("get_member") else null
	if not member or not member.faction_id:
		return FAILURE
		
	var faction = WorldState.get_faction(member.faction_id)
	if not faction:
		return FAILURE
		
	# Get all territories belonging to the faction
	var territories = []
	for territory in agent.get_tree().get_nodes_in_group("territories"):
		if territory.has_method("get_owner") and territory.get_owner() == faction.id:
			territories.append(territory)
	
	if territories.is_empty():
		# If no territories, use faction base location
		var base_location = faction.base_location if faction.has("base_location") else Vector3.ZERO
		blackboard.set_var("patrol_center", base_location)
		blackboard.set_var("patrol_radius", 10.0)
	else:
		# Calculate center and radius of territories
		var center = Vector3.ZERO
		for territory in territories:
			center += territory.global_transform.origin
		center /= territories.size()
		
		# Calculate patrol radius based on territory positions
		var max_distance = 0.0
		for territory in territories:
			var dist = center.distance_to(territory.global_transform.origin)
			max_distance = max(max_distance, dist)
		
		blackboard.set_var("patrol_center", center)
		blackboard.set_var("patrol_radius", max_distance + 5.0)
		blackboard.set_var("territories", territories)
	
	return SUCCESS

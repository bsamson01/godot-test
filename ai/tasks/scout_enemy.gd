# scout_enemy.gd - Scout enemy territory task
extends BTAction

var scout_location: Vector3 = Vector3.ZERO
var scout_timer: float = 0.0
var scout_duration: float = 10.0
var intel_gathered: Dictionary = {}

func _tick(_delta: float) -> Status:
	# Initialize scout location if not done
	if scout_location == Vector3.ZERO:
		if not _initialize_scout_location():
			return FAILURE
	
	# Scout the area
	return _perform_scouting(_delta)

func _initialize_scout_location() -> bool:
	# Find enemy territory to scout
	var enemy_location = _find_enemy_territory()
	if enemy_location == Vector3.ZERO:
		# Fallback: scout a random area
		scout_location = agent.get_current_position() + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
	else:
		scout_location = enemy_location
	
	return true

func _find_enemy_territory() -> Vector3:
	# Find the nearest enemy gang member to scout their territory
	var enemies = agent.get_tree().get_nodes_in_group("gang_members")
	if enemies.is_empty():
		return Vector3.ZERO
	
	var nearest_enemy = null
	var nearest_distance = INF
	var current_pos = agent.get_current_position()
	
	# Get our faction ID
	var our_faction_id = _get_our_faction_id()
	if our_faction_id == "":
		return Vector3.ZERO
	
	for enemy in enemies:
		if enemy == agent:  # Skip self
			continue
		
		# Check if this is actually an enemy (different faction)
		var enemy_faction_id = _get_enemy_faction_id(enemy)
		if enemy_faction_id != "" and enemy_faction_id != our_faction_id:
			var distance = current_pos.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	
	if nearest_enemy:
		return nearest_enemy.global_position
	
	return Vector3.ZERO

func _perform_scouting(_delta: float) -> Status:
	scout_timer += _delta
	
	# Move to scout location
	agent.set_movement_target(scout_location)
	
	# Check if we've reached the scout location
	var current_pos = agent.get_current_position()
	var distance_to_location = current_pos.distance_to(scout_location)
	
	if distance_to_location < 5.0:  # Close enough to scout
		# Gather intel
		_gather_intel()
	
	# Check if scouting is complete
	if scout_timer >= scout_duration:
		# Scouting completed
		_complete_scouting()
		agent.updateLabel('Scouting completed')
		return SUCCESS
	
	# Show scouting progress
	var progress = int((scout_timer / scout_duration) * 100)
	agent.updateLabel('Scouting enemy (%d%%)' % progress)
	return RUNNING

func _gather_intel() -> void:
	# Gather intelligence about the area
	intel_gathered["location"] = scout_location
	intel_gathered["time"] = Time.get_ticks_msec()
	intel_gathered["threat_level"] = randf_range(0.1, 0.9)
	intel_gathered["enemy_activity"] = randf_range(0.0, 1.0)

func _complete_scouting() -> void:
	# Get the member's faction
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
							# Add intel to faction
							faction_comp.intel["scout_" + str(Time.get_ticks_msec())] = intel_gathered
							
							Logger.info("Enemy scouted", "ScoutEnemy", {
								"faction": faction_comp.faction_name,
								"intel_gathered": intel_gathered
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

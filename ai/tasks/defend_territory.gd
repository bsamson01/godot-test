# defend_territory.gd - Defend territory task
extends BTAction

var defense_location: Vector3 = Vector3.ZERO
var defense_timer: float = 0.0
var defense_duration: float = 10.0
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0

func _tick(_delta: float) -> Status:
	# Initialize defense location if not done
	if defense_location == Vector3.ZERO:
		if not _initialize_defense_location():
			return FAILURE
	
	# Defend the territory
	return _perform_defense(_delta)

func _initialize_defense_location() -> bool:
	# Get the member's faction base location
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
							defense_location = faction_comp.base_location
							_generate_patrol_points()
							return true
	
	# Fallback: use current position
	defense_location = agent.get_current_position()
	_generate_patrol_points()
	return true

func _generate_patrol_points() -> void:
	patrol_points.clear()
	
	# Generate patrol points around the defense location
	var radius = 8.0
	for i in range(4):
		var angle = i * PI / 2.0  # 90 degrees apart
		var offset = Vector3(
			cos(angle) * radius,
			0,
			sin(angle) * radius
		)
		patrol_points.append(defense_location + offset)
	
	# Add center point
	patrol_points.append(defense_location)

func _perform_defense(_delta: float) -> Status:
	defense_timer += _delta
	
	# Patrol around the defense area
	var target_point = patrol_points[current_patrol_index]
	agent.set_movement_target(target_point)
	
	# Check if we've reached the patrol point
	var current_pos = agent.get_current_position()
	var distance_to_point = current_pos.distance_to(target_point)
	
	if distance_to_point < 2.0:  # Close enough to patrol point
		# Move to next patrol point
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	
	# Check if defense is complete
	if defense_timer >= defense_duration:
		# Defense completed
		_complete_defense()
		agent.updateLabel('Defense completed')
		return SUCCESS
	
	# Show defense progress
	var progress = int((defense_timer / defense_duration) * 100)
	agent.updateLabel('Defending territory (%d%%)' % progress)
	return RUNNING

func _complete_defense() -> void:
	# Get the member's faction for rewards
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
							# Territory is now more secure
							faction_comp.supplies = max(0, faction_comp.supplies - 25)  # Cost some supplies
							
							Logger.info("Territory defended", "DefendTerritory", {
								"faction": faction_comp.faction_name,
								"supplies_used": 25,
								"new_supplies": faction_comp.supplies
							})

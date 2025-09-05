extends Node

func init_all(config: Dictionary = {}, game_manager: GameManager = null):
	var default_config = {
		"faction_count": 2,
		"members_per_faction": 3,
		"territories_per_faction": 1,
		"businesses_per_faction": 1
	}
	config.merge(default_config)
	
	# Get the GameManager to create entities
	if not game_manager:
		game_manager = get_node("../GameManager") as GameManager
	if not game_manager or not game_manager.entity_manager:
		print("ERROR: GameManager not found! ECS system required.")
		return
	
	var _entity_manager = game_manager.entity_manager
	
	# Get all available bases and businesses from the scene
	var available_bases = _get_unassigned_bases()
	var available_businesses = _get_unassigned_businesses()
	
	print("Found %d unassigned bases and %d unassigned businesses" % [available_bases.size(), available_businesses.size()])
	
	# Create factions using the ECS system
	for i in range(config.faction_count):
		_create_faction_ecs(i, available_bases, available_businesses, config, game_manager)
	
	print("Init completed - factions created using ECS system")

func _create_faction_ecs(faction_index: int, available_bases: Array, _available_businesses: Array, config: Dictionary, game_manager: GameManager = null):
	if not game_manager:
		game_manager = get_node("../GameManager") as GameManager
	var entity_manager = game_manager.entity_manager
	
	# Create faction entity
	var faction_entity = entity_manager.create_entity("faction")
	
	# Add faction component
	var faction_comp = FactionComponent.new()
	faction_comp.faction_name = _get_faction_name(faction_index)
	faction_comp.color = _get_faction_color(faction_index)
	faction_comp.funds = 5000.0
	faction_comp.supplies = 1000.0
	faction_entity.add_component(faction_comp)
	
	# Assign a base to the faction if available
	if available_bases.size() > 0:
		var base_node = available_bases.pop_front() as Node3D
		base_node.set_meta("owner", faction_entity.id)
		var baseText = base_node.get_node('Label3D') as Label3D
		if baseText:
			baseText.text = faction_comp.faction_name
			baseText.modulate = faction_comp.color
		faction_comp.base_location = base_node.global_position
		print("Assigned base at %s to faction %s" % [base_node.global_position, faction_comp.faction_name])
	else:
		print("No available bases for faction %s" % faction_comp.faction_name)
	
	# Create commander
	var commander = _create_gang_member_ecs(faction_entity.id, GangMemberComponent.ROLE_COMMANDER, entity_manager)
	faction_comp.add_member(commander)
	
	# Create visual node for commander
	_create_gang_member_visual_node(commander, faction_comp.base_location, faction_comp.color)
	
	# Create regular members
	for j in range(config.members_per_faction - 1):
		var member = _create_gang_member_ecs(faction_entity.id, "", entity_manager)
		faction_comp.add_member(member)
		
		# Create visual node for member
		_create_gang_member_visual_node(member, faction_comp.base_location, faction_comp.color)
	
	# Create territories
	for i in range(config.territories_per_faction):
		var territory = _create_territory_ecs(faction_entity.id, faction_comp.faction_name + " Territory " + str(i + 1), entity_manager)
		faction_comp.add_territory(territory)
		
		# Create businesses in territory
		for j in range(config.businesses_per_territory):
			var business = _create_business_ecs(territory.id, faction_entity.id, entity_manager)
			faction_comp.add_business(business)
	
	print("Created faction %s with %d members" % [faction_comp.faction_name, faction_comp.get_members().size()])


func _create_gang_member_ecs(faction_id: String, role: String, entity_manager: EntityManager) -> Entity:
	var member_entity = entity_manager.create_entity("gang_member")
	
	# Get existing member names in this faction to avoid duplicates
	var existing_names = _get_faction_member_names_ecs(faction_id, entity_manager)
	
	# Generate random member data
	var member_data = GangMemberComponent.create_random(existing_names)
	
	# Add gang member component
	var member_comp = GangMemberComponent.new()
	member_comp.member_name = member_data.name
	member_comp.role = role if role != "" else member_data.role
	member_comp.loyalty = member_data.loyalty
	member_comp.personality = member_data.personality
	member_comp.faction_id = faction_id
	member_entity.add_component(member_comp)
	
	# Add AI component based on role
	if role == GangMemberComponent.ROLE_COMMANDER:
		var ai_comp = CommanderAIComponent.new()
		member_entity.add_component(ai_comp)
	else:
		var ai_comp = AIComponent.new()
		ai_comp.ai_type = "member"
		member_entity.add_component(ai_comp)
	
	return member_entity

func _get_faction_member_names_ecs(faction_id: String, entity_manager: EntityManager) -> Array:
	var existing_names = []
	var faction_entity = entity_manager.get_entity(faction_id)
	if faction_entity:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if faction_comp:
			for member_entity in faction_comp.get_members():
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					existing_names.append(member_comp.member_name)
	return existing_names

func _create_territory_ecs(faction_id: String, territory_name: String, entity_manager: EntityManager) -> Entity:
	var territory_entity = entity_manager.create_entity("territory")
	
	# Add territory component
	var territory_comp = TerritoryComponent.new()
	territory_comp.territory_name = territory_name
	territory_comp.owner_faction_id = faction_id
	territory_entity.add_component(territory_comp)
	
	return territory_entity

func _create_business_ecs(territory_id: String, faction_id: String, entity_manager: EntityManager) -> Entity:
	var business_entity = entity_manager.create_entity("business")
	
	# Add business component
	var business_comp = BusinessComponent.new()
	business_comp.generate_random()
	business_comp.territory_id = territory_id
	business_comp.owner_faction_id = faction_id
	business_entity.add_component(business_comp)
	
	return business_entity

func _get_faction_name(index: int) -> String:
	var names = ["Red Vipers", "Blue Shadows", "Green Dragons", "Black Ravens", "White Wolves"]
	return names[index % names.size()]

func _get_faction_color(index: int) -> Color:
	var colors = [Color.RED, Color.BLUE, Color.GREEN, Color.BLACK, Color.WHITE]
	return colors[index % colors.size()]

func _get_unassigned_bases() -> Array:
	var unassigned_bases = []
	var base_nodes = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("base")
	for base_node in base_nodes:
		var base_owner = base_node.get_meta("owner", "")
		if base_owner == "":
			unassigned_bases.append(base_node)
	return unassigned_bases

func _get_unassigned_businesses() -> Array:
	var unassigned_businesses = []
	var business_nodes = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("business")
	for business_node in business_nodes:
		var business_owner = business_node.get_meta("owner", "")
		if business_owner == "":
			unassigned_businesses.append(business_node)
	return unassigned_businesses

func _create_gang_member_visual_node(member_entity: Entity, base_location: Vector3, faction_color: Color):
	# Get the gang member component
	var member_comp = member_entity.get_component("GangMemberComponent")
	if not member_comp:
		print("ERROR: Gang member entity missing GangMemberComponent")
		return
	
	# Create visual node using the existing player scene
	var member_scene = preload("res://test/player.tscn")
	var member_node = member_scene.instantiate()
	
	# Use improved spawn positioning
	var spawn_pos = _find_optimal_spawn_position(base_location, member_entity.id)
	member_node.position = spawn_pos
	
	# Add to scene - use get_parent() since Init script is a child of the main scene
	var parent_scene = get_parent()
	if parent_scene:
		parent_scene.add_child(member_node)
	else:
		# Fallback: try to get the main scene using Engine
		var main_scene = Engine.get_main_loop().get_root()
		if main_scene:
			main_scene.add_child(member_node)
		else:
			print("ERROR: Could not find parent scene to add gang member")
			return
	
	# Set member reference
	member_node.member_id = member_entity.id
	
	# Add to gang members group
	member_node.add_to_group("gang_members")
	
	# Set faction color
	if member_node.has_node("MeshInstance3D"):
		var mesh = member_node.get_node("MeshInstance3D")
		if mesh:
			# Create a new material instance to avoid sharing materials
			var new_material = StandardMaterial3D.new()
			new_material.albedo_color = faction_color
			new_material.metallic = 0.56  # Match the original material properties
			mesh.set_surface_override_material(0, new_material)
			print("Set faction color for gang member: %s (color: %s)" % [member_comp.member_name, faction_color])
	
	# WorldState is disabled - using ECS system instead
	# No need to register with legacy WorldState
	
	# Disable legacy behavior tree system - using ECS AI components instead
	# if member_node.has_node("BTPlayer"):
	#	var bt_player = member_node.get_node("BTPlayer")
	#	var behavior_tree = load("res://ai/tres/test.tres")
	#	bt_player.behavior_tree = behavior_tree
	#	bt_player.blackboard.set_var("member_id", member_entity.id)
	
	print("Created visual node for gang member: %s" % member_comp.member_name)

func _find_optimal_spawn_position(base_location: Vector3, _member_id: String) -> Vector3:
	# Configuration for spawn behavior (same as GameManager)
	var spawn_radius_min = 5.0
	var spawn_radius_max = 15.0
	var max_attempts = 20
	var min_distance_between_members = 2.0
	
	# Get existing member positions to avoid collisions
	var existing_positions = _get_existing_member_positions()
	
	# Try to find a good spawn position
	for attempt in range(max_attempts):
		# Generate position using circular distribution
		var angle = randf() * 2 * PI
		var distance = randf_range(spawn_radius_min, spawn_radius_max)
		var candidate_pos = base_location + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
		
		# Check for ground level using raycast
		var ground_pos = _find_ground_level(candidate_pos)
		if ground_pos != Vector3.ZERO:
			candidate_pos = ground_pos
		
		# Check if position is clear of other members
		if _is_position_clear(candidate_pos, existing_positions, min_distance_between_members):
			print("Found optimal spawn position after %d attempts" % (attempt + 1))
			return candidate_pos
	
	# Fallback: spawn near base with small random offset
	var fallback_pos = base_location + Vector3(
		randf_range(-2, 2),
		0,
		randf_range(-2, 2)
	)
	print("Using fallback spawn position after %d failed attempts" % max_attempts)
	return fallback_pos

func _get_existing_member_positions() -> Array:
	var positions = []
	
	# Check if we're in the scene tree
	if not is_inside_tree():
		return positions
	
	var gang_members = get_tree().get_nodes_in_group("gang_members")
	for member in gang_members:
		if member.has_method("get_global_position"):
			positions.append(member.get_global_position())
		elif member.has_method("get_position"):
			positions.append(member.get_position())
	return positions

func _is_position_clear(candidate_pos: Vector3, existing_positions: Array, min_distance: float) -> bool:
	for existing_pos in existing_positions:
		if candidate_pos.distance_to(existing_pos) < min_distance:
			return false
	return true

func _find_ground_level(candidate_pos: Vector3) -> Vector3:
	# Check if we have access to the viewport and world
	if not is_inside_tree():
		return candidate_pos
	
	var viewport = get_viewport()
	if not viewport:
		return candidate_pos
	
	var world_3d = viewport.get_world_3d()
	if not world_3d:
		return candidate_pos
	
	# Use raycast to find ground level
	var space_state = world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		candidate_pos + Vector3(0, 10, 0),  # Start 10 units above
		candidate_pos + Vector3(0, -10, 0)  # End 10 units below
	)
	query.collision_mask = 1  # Ground layer
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.position
	else:
		# No ground found, return original position
		return candidate_pos

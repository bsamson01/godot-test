extends Node

func init_all(config: Dictionary = {}):
	var default_config = {
		"faction_count": 1,
		"members_per_faction": 2,
		"territories_per_faction": 1,
		"businesses_per_faction": 1
	}
	config.merge(default_config)
	
	# Get the GameManager to create entities
	var game_manager = get_node("../GameManager") as GameManager
	if not game_manager or not game_manager.entity_manager:
		print("ERROR: GameManager not found! ECS system required.")
		return
	
	var entity_manager = game_manager.entity_manager
	
	# Get all available bases and businesses from the scene
	var available_bases = _get_unassigned_bases()
	var available_businesses = _get_unassigned_businesses()
	
	print("Found %d unassigned bases and %d unassigned businesses" % [available_bases.size(), available_businesses.size()])
	
	# Create factions using the ECS system
	for i in range(config.faction_count):
		_create_faction_ecs(i, available_bases, available_businesses, config)
	
	print("Init completed - factions created using ECS system")

func _create_faction_ecs(faction_index: int, available_bases: Array, available_businesses: Array, config: Dictionary):
	var game_manager = get_node("../GameManager") as GameManager
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
	
	# Create regular members
	for j in range(config.members_per_faction - 1):
		var member = _create_gang_member_ecs(faction_entity.id, "", entity_manager)
		faction_comp.add_member(member)
	
	# Create territories
	for i in range(config.territories_per_faction):
		var territory = _create_territory_ecs(faction_entity.id, faction_comp.faction_name + " Territory " + str(i + 1), entity_manager)
		faction_comp.add_territory(territory)
		
		# Create businesses in territory
		for j in range(config.businesses_per_faction):
			var business = _create_business_ecs(territory.id, faction_entity.id, entity_manager)
			faction_comp.add_business(business)
	
	print("Created faction %s with %d members" % [faction_comp.faction_name, faction_comp.get_members().size()])


func _create_gang_member_ecs(faction_id: String, role: String, entity_manager: EntityManager) -> Entity:
	var member_entity = entity_manager.create_entity("gang_member")
	
	# Generate random member data
	var member_data = GangMemberComponent.create_random()
	
	# Add gang member component
	var member_comp = GangMemberComponent.new()
	member_comp.member_name = member_data.name
	member_comp.role = role if role != "" else member_data.role
	member_comp.loyalty = member_data.loyalty
	member_comp.personality = member_data.personality
	member_comp.faction_id = faction_id
	member_entity.add_component(member_comp)
	
	return member_entity

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
		var owner = base_node.get_meta("owner", "")
		if owner == "":
			unassigned_bases.append(base_node)
	return unassigned_bases

func _get_unassigned_businesses() -> Array:
	var unassigned_businesses = []
	var business_nodes = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("business")
	for business_node in business_nodes:
		var owner = business_node.get_meta("owner", "")
		if owner == "":
			unassigned_businesses.append(business_node)
	return unassigned_businesses


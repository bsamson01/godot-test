extends Node

func init_all(config: Dictionary = {}):
	var default_config = {
		"faction_count": 3,
		"members_per_faction": 3,
		"territories_per_faction": 4,
		"businesses_per_faction": 4
	}
	config.merge(default_config)
	
	# Clear existing data
	WorldState.factions.clear()
	WorldState.gang_members.clear()
	
	# Create factions
	for i in range(config.faction_count):
		var faction = _create_faction()
		WorldState.register_faction(faction)
		
		# Create commander
		var commander = GangMember.create_random(faction.id, GangMember.ROLE_COMMANDER)
		WorldState.register_gang_member(commander)
		faction.add_member(commander)
		
		var commander_node = GangMemberNode.new(commander)
		WorldState.register_gang_member_node(commander_node)
		add_child(commander_node)
		
		# Create regular members
		for j in range(config.members_per_faction - 1):
			var member = GangMember.create_random(faction.id)
			WorldState.register_gang_member(member)
			faction.add_member(member)
			
			# Create node for member
			var member_node = GangMemberNode.new(member)
			WorldState.register_gang_member_node(member_node)
			add_child(member_node)
		
		for t in range(config.territories_per_faction - 1):
			var territory = Territory.random_territory(faction.id)
			WorldState.register_territory(territory)
			faction.add_territory(territory)
			
		if faction.territory_ids.size() > 0:
			for territory_id in faction.territory_ids:
				var territory = WorldState.get_territory(territory_id)
				var business = Business.random_business(territory_id, faction.id)
				WorldState.register_business(business)
				territory.add_business(business.id)

func _create_faction() -> Faction:
	var faction = Faction.new()
	var names = ["Red Vipers", "Night Rats", "Iron Fangs"]
	faction.name = names[randi() % names.size()]
	faction.color = Color(randf(), randf(), randf())
	faction.base_location = Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
	return faction

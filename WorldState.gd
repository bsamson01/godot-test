extends Node

# Minimal WorldState - only for ECS compatibility
var current_tick: int = 0

# For visual nodes only (not part of ECS data)
var gang_member_nodes: Array[GangMemberNode] = []

# Stub methods for compatibility with old code
func get_gang_member_node(member_id: String) -> GangMemberNode:
	for mem_node in gang_member_nodes:
		if mem_node.member_id == member_id:
			return mem_node
	return null

func register_gang_member_node(node: GangMemberNode):
	gang_member_nodes.append(node)

func update_tick(tick: int):
	current_tick = tick

# Stub methods for old model compatibility
func get_gang_member(_member_id: String):
	# Return null - old system not used
	return null

func get_faction(_faction_id: String):
	# Return null - old system not used
	return null

func get_business(_business_id: String):
	# Return null - old system not used
	return null

func get_territory(_territory_id: String):
	# Return null - old system not used
	return null

func spawn_gang_member(_faction_id: String):
	# Return null - old system not used
	return null

func register_faction(_faction):
	# No-op - old system not used
	pass

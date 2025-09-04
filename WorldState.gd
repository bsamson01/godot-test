extends Node

# Minimal WorldState - only for ECS compatibility
var current_tick: int = 0

# For visual nodes only (not part of ECS data)
var gang_member_nodes: Array[GangMemberNode] = []

func get_gang_member_node(member_id: String) -> GangMemberNode:
	for mem_node in gang_member_nodes:
		if mem_node.member_id == member_id:
			return mem_node
	return null

func register_gang_member_node(node: GangMemberNode):
	gang_member_nodes.append(node)

func update_tick(tick: int):
	current_tick = tick

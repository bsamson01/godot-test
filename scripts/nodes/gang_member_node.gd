extends Node
class_name GangMemberNode

var member_id: String
var ai_brain: AIBrain

func _init(member: GangMember):
	member_id = member.id
	
	# Create appropriate AI brain
	if member.role == GangMember.ROLE_COMMANDER:
		ai_brain = CommanderAI.new(member_id)
	else:
		ai_brain = NormalMemberAI.new(member_id)
	
	add_child(ai_brain)
	add_to_group("gang_members")

func get_member() -> GangMember:
	return WorldState.get_gang_member(member_id)

func process_tick(current_tick: int):
	if ai_brain:
		ai_brain.process_tick(current_tick)

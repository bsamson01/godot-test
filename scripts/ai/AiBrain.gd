extends Node
class_name AIBrain

var member_id: String
var last_processed_tick: int = 0

func _init(member_id: String):
	self.member_id = member_id

func get_member() -> GangMember:
	return WorldState.get_gang_member(member_id)

func get_faction() -> Faction:
	var member = get_member()
	return member.get_faction() if member else null

# Override in subclasses
func process_tick(current_tick: int):
	last_processed_tick = current_tick

extends RefCounted
class_name NPC

var id: String
var name: String
var location: Vector3
var is_recruitable: bool = true
var recruitment_chance: float = 0.3
var spawn_day: int = 0
var last_recruitment_attempt: int = 0
var recruitment_cooldown: int = 5

func _init(npc_id: String = "", npc_name: String = ""):
	id = npc_id if npc_id != "" else _generate_id()
	name = npc_name if npc_name != "" else _generate_name()
	location = Vector3.ZERO
	spawn_day = 0

func _generate_id() -> String:
	return "npc_" + str(randi() % 1000000)

func _generate_name() -> String:
	var names = [
		"Shadow", "Blade", "Raven", "Ghost", "Viper", "Fang", "Storm", "Thunder",
		"Frost", "Ember", "Crystal", "Steel", "Iron", "Copper", "Silver", "Gold",
		"Phoenix", "Dragon", "Tiger", "Wolf", "Eagle", "Hawk", "Falcon", "Crow",
		"Fox", "Bear", "Lion", "Panther", "Jaguar", "Leopard", "Cheetah", "Lynx"
	]
	return names[randi() % names.size()]

func can_be_recruited(current_day: int) -> bool:
	if not is_recruitable:
		return false
	
	# Check cooldown
	if current_day - last_recruitment_attempt < recruitment_cooldown:
		return false
	
	return true

func attempt_recruitment(_recruiter_name: String, current_day: int) -> bool:
	if not can_be_recruited(current_day):
		return false
	
	last_recruitment_attempt = current_day
	
	# Roll for recruitment success
	var roll = randf()
	var success = roll < recruitment_chance
	
	return success

func get_display_name() -> String:
	return name if name != "" else "Unknown NPC"

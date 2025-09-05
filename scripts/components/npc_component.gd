extends Component
class_name NPCComponent

# NPC data
@export var npc_name: String = ""
@export var npc_id: String = ""
@export var location: Vector3 = Vector3.ZERO
@export var is_recruitable: bool = true
@export var recruitment_chance: float = 0.3  # 30% chance to accept recruitment
@export var spawn_day: int = 0
@export var last_recruitment_attempt: int = 0
@export var recruitment_cooldown: int = 5  # Days before can be recruited again

func get_component_name() -> String:
	return "NPCComponent"

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
	return npc_name if npc_name != "" else "Unknown NPC"

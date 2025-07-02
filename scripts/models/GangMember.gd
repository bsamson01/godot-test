# GangMember.gd
extends Resource
class_name GangMember

@export var id: String
@export var name: String
@export var role: String
@export var loyalty: float
@export var personality: String
@export var faction_id: String  # Reference by ID, not object

# Health system
@export var max_health: float = 100.0
var health: float = 100.0

# Runtime state (not exported - doesn't persist)
var current_order: Order = null
var state: String = "idle"  # idle, traveling, working, dead

const ROLE_COMMANDER = "Commander"
const ROLES = ["Sniper", "Enforcer", "Spy", "Hacker", "Lieutenant"]

func _init():
	id = _generate_id()
	health = max_health

func get_faction() -> Faction:
	return WorldState.get_faction(faction_id)

func is_idle() -> bool:
	return state == "idle" and current_order == null

func take_damage(amount: float) -> void:
	health = max(0, health - amount)
	if health <= 0:
		state = "dead"

func heal(amount: float) -> void:
	health = min(max_health, health + amount)

func get_health_percentage() -> float:
	return health / max_health if max_health > 0 else 0.0

func is_alive() -> bool:
	return health > 0 and state != "dead"

func assign_order(order: Order) -> bool:
	if not is_idle():
		return false
	
	current_order = order
	state = "traveling"
	return true

func _generate_id() -> String:
	return "member_" + str(randi())

static func create_random(faction_id: String, role: String = "") -> GangMember:
	var member = GangMember.new()
	member.faction_id = faction_id
	member.role = role if role != "" else ROLES[randi() % ROLES.size()]
	member.name = _get_random_name()
	member.loyalty = randf_range(70, 100)
	member.personality = ["Loyal", "Greedy", "Paranoid"][randi() % 3]
	member.max_health = randf_range(80, 120)  # Random health between 80-120
	member.health = member.max_health
	return member

static func _get_random_name() -> String:
	var names = ["Ghost", "Snake", "Viper", "Blaze", "Razor"]
	return names[randi() % names.size()]

# NPCComponent.gd - Component for NPCs that can be recruited
extends Component
class_name NPCComponent

@export var npc_id: String = ""
@export var npc_name: String = ""
@export var npc_type: String = "civilian"
@export var location: Vector3 = Vector3.ZERO
@export var recruitment_cost: float = 1000.0
@export var recruitment_chance: float = 0.6
@export var loyalty_requirement: float = 50.0

# Recruitment tracking
var last_recruitment_attempt: int = 0
var recruitment_cooldown: int = 24  # Hours
var is_recruited: bool = false
var recruited_by: String = ""
var spawn_day: int = 0  # Day when NPC was spawned

# NPC stats
var health: float = 100.0
var morale: float = 75.0
var skills: Dictionary = {}

# Wandering behavior
var last_wander_time: float = 0.0
var wander_cooldown: float = 3.0  # seconds between movements
var current_target: Vector3 = Vector3.ZERO
var is_wandering: bool = false
var wander_radius: float = 15.0  # how far from spawn they can wander
var spawn_position: Vector3 = Vector3.ZERO

func get_component_name() -> String:
	return "NPCComponent"

func _on_attached(_entity: Entity) -> void:
	# Generate random name if not set
	if npc_name.is_empty():
		npc_name = _generate_random_name()
	
	# Generate random skills
	_generate_skills()
	
	# Initialize wandering behavior
	spawn_position = location
	last_wander_time = Time.get_ticks_msec() / 1000.0
	
	# Add some randomness to wandering behavior
	wander_cooldown = randf_range(2.0, 6.0)  # 2-6 seconds between movements
	wander_radius = randf_range(10.0, 20.0)  # 10-20 unit wander radius
	
	# Subscribe to events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.ENTITY_KILLED, _on_entity_killed)

func _on_detached(_entity: Entity) -> void:
	# Unsubscribe from events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.ENTITY_KILLED, _on_entity_killed)

func can_be_recruited(current_day: int) -> bool:
	if is_recruited:
		return false
	
	# Check cooldown
	if current_day - last_recruitment_attempt < recruitment_cooldown:
		return false
	
	# Check if NPC is healthy enough
	if health < 50.0:
		return false
	
	return true

func attempt_recruitment(recruiter_id: String, current_day: int) -> bool:
	if not can_be_recruited(current_day):
		return false
	
	last_recruitment_attempt = current_day
	
	# Calculate success chance based on various factors
	var success_chance = recruitment_chance
	
	# Modify based on health
	success_chance *= (health / 100.0)
	
	# Modify based on morale
	success_chance *= (morale / 100.0)
	
	# Random roll
	var roll = randf()
	var success = roll <= success_chance
	
	if success:
		is_recruited = true
		recruited_by = recruiter_id
		
		Logger.info("NPC recruited successfully", "NPC", {
			"npc_name": npc_name,
			"recruiter": recruiter_id,
			"success_chance": success_chance,
			"roll": roll
		})
	else:
		Logger.info("NPC recruitment failed", "NPC", {
			"npc_name": npc_name,
			"recruiter": recruiter_id,
			"success_chance": success_chance,
			"roll": roll
		})
	
	return success

func _generate_random_name() -> String:
	var first_names = ["Alex", "Jordan", "Casey", "Morgan", "Taylor", "Riley", "Avery", "Quinn", "Blake", "Cameron"]
	var last_names = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"]
	
	return first_names[randi() % first_names.size()] + " " + last_names[randi() % last_names.size()]

func _generate_skills() -> void:
	# Generate random skills for the NPC
	skills = {
		"combat": randf_range(0.1, 0.8),
		"stealth": randf_range(0.1, 0.9),
		"intelligence": randf_range(0.2, 1.0),
		"loyalty": randf_range(0.3, 0.9),
		"charisma": randf_range(0.1, 0.8)
	}

func get_skill_value(skill_name: String) -> float:
	return skills.get(skill_name, 0.0)

func take_damage(amount: float) -> void:
	health = max(0, health - amount)
	
	if health <= 0:
		# NPC is dead
		_die()

func heal(amount: float) -> void:
	health = min(100, health + amount)

func modify_morale(amount: float) -> void:
	morale = clamp(morale + amount, 0, 100)

func _die() -> void:
	# Emit death event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.ENTITY_KILLED,
			{
				"entity_id": entity.id,
				"entity_type": "npc",
				"npc_name": npc_name
			}
		)

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	Validatable.validate_not_empty(npc_name, "npc_name", result)
	Validatable.validate_in_range(health, 0, 100, "health", result)
	Validatable.validate_in_range(morale, 0, 100, "morale", result)
	Validatable.validate_in_range(recruitment_chance, 0, 1, "recruitment_chance", result)
	Validatable.validate_positive(recruitment_cost, "recruitment_cost", result)
	
	return result

func get_stats() -> Dictionary:
	return {
		"name": npc_name,
		"type": npc_type,
		"health": health,
		"morale": morale,
		"is_recruited": is_recruited,
		"recruited_by": recruited_by,
		"skills": skills,
		"location": location
	}

func generate_wander_target() -> Vector3:
	# Generate a random target within the wander radius
	var angle = randf() * 2 * PI
	var distance = randf_range(5.0, wander_radius)
	
	var target = spawn_position + Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)
	
	# Ensure the target is within reasonable bounds (not too far from spawn)
	var distance_from_spawn = target.distance_to(spawn_position)
	if distance_from_spawn > wander_radius:
		target = spawn_position + (target - spawn_position).normalized() * wander_radius
	
	# Additional boundary checking - keep within reasonable world bounds
	var world_bounds = 100.0  # Adjust this based on your world size
	target.x = clamp(target.x, -world_bounds, world_bounds)
	target.z = clamp(target.z, -world_bounds, world_bounds)
	
	# Ensure target is not too close to spawn (avoid getting stuck)
	var min_distance = 3.0
	if target.distance_to(spawn_position) < min_distance:
		# Generate a new target in a different direction
		angle = randf() * 2 * PI
		target = spawn_position + Vector3(
			cos(angle) * min_distance,
			0,
			sin(angle) * min_distance
		)
	
	return target

func can_wander() -> bool:
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - last_wander_time) >= wander_cooldown

func start_wandering() -> void:
	if can_wander():
		current_target = generate_wander_target()
		is_wandering = true
		last_wander_time = Time.get_ticks_msec() / 1000.0
		
		# Occasionally vary the wander radius for more interesting movement
		if randf() < 0.1:  # 10% chance
			wander_radius = randf_range(8.0, 25.0)

# Event handlers
func _on_entity_killed(event: EventBus.Event) -> void:
	if event.data.get("entity_id") == entity.id:
		# This NPC was killed
		_die()

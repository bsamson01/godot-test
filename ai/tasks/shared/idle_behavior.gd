extends BTAction

@export var idle_radius: float = 5.0
@export var min_wait_time: float = 3.0
@export var max_wait_time: float = 8.0

var _state: String = "waiting"
var _timer: float = 0.0
var _wait_duration: float = 0.0

func _enter():
	_state = "waiting"
	_timer = 0.0
	_wait_duration = randf_range(min_wait_time, max_wait_time)
	
	if agent.has_method("set_status"):
		agent.set_status("Idle")

func _tick(delta: float) -> Status:
	_timer += delta
	
	match _state:
		"waiting":
			if _timer >= _wait_duration:
				# Pick a random nearby position
				var member = agent.get_member() if agent.has_method("get_member") else null
				if member:
					var faction = WorldState.get_faction(member.faction_id)
					if faction and faction.has("base_location"):
						# Wander near faction base
						var base_pos = faction.base_location
						var angle = randf() * TAU
						var distance = randf() * idle_radius
						var target_pos = base_pos + Vector3(
							cos(angle) * distance,
							0,
							sin(angle) * distance
						)
						blackboard.set_var("target_location", target_pos)
						_state = "moving"
						_timer = 0.0
						if agent.has_method("set_status"):
							agent.set_status("Wandering")
				else:
					# Just pick a random position nearby
					var current_pos = agent.global_transform.origin
					var angle = randf() * TAU
					var distance = randf() * idle_radius
					var target_pos = current_pos + Vector3(
						cos(angle) * distance,
						0,
						sin(angle) * distance
					)
					blackboard.set_var("target_location", target_pos)
					_state = "moving"
					_timer = 0.0
					
		"moving":
			# This state is handled by a separate move task
			# We just reset to waiting
			_state = "waiting"
			_timer = 0.0
			_wait_duration = randf_range(min_wait_time, max_wait_time)
			return SUCCESS
			
	return RUNNING

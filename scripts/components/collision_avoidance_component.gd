extends Node
class_name CollisionAvoidanceComponent

# Collision avoidance settings
@export var avoidance_radius: float = 2.0
@export var avoidance_strength: float = 3.0
@export var separation_radius: float = 1.5
@export var separation_strength: float = 2.0
@export var max_avoidance_force: float = 5.0

# Collision detection settings
@export var collision_detection_radius: float = 1.0
@export var stuck_detection_time: float = 1.0
@export var bypass_strength: float = 4.0
@export var bypass_radius: float = 2.5

# Cache for nearby characters
var nearby_characters: Array = []
var avoidance_force: Vector3 = Vector3.ZERO
var last_update_time: float = 0.0
var update_interval: float = 0.1  # Update every 100ms

# Collision and stuck detection
var is_stuck: bool = false
var stuck_start_time: float = 0.0
var last_position: Vector3 = Vector3.ZERO
var position_check_interval: float = 0.5
var last_position_check: float = 0.0
var bypass_direction: Vector3 = Vector3.ZERO
var bypass_target: Vector3 = Vector3.ZERO
var bypass_active: bool = false

# Recovery mechanism
var recovery_active: bool = false
var recovery_start_time: float = 0.0
var recovery_duration: float = 2.0
var original_direction: Vector3 = Vector3.ZERO

func _ready():
	# Load settings from game config if available
	if Engine.has_singleton("GameConfig"):
		var game_config = Engine.get_singleton("GameConfig")
		if game_config and game_config.has_method("get"):
			avoidance_radius = game_config.get("avoidance_radius")
			avoidance_strength = game_config.get("avoidance_strength")
			separation_radius = game_config.get("separation_radius")
			separation_strength = game_config.get("separation_strength")
			max_avoidance_force = game_config.get("max_avoidance_force")

func update_avoidance_force(current_position: Vector3, current_velocity: Vector3) -> Vector3:
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_update = current_time - last_update_time
	
	# Only update nearby characters periodically for performance
	if time_since_update >= update_interval:
		_update_nearby_characters(current_position)
		last_update_time = current_time
	
	# Check for stuck condition
	_check_stuck_condition(current_position, current_time)
	
	# Calculate avoidance forces
	var avoidance = _calculate_avoidance_force(current_position, current_velocity)
	var separation = _calculate_separation_force(current_position)
	var bypass = _calculate_bypass_force(current_position, current_velocity)
	var recovery = _calculate_recovery_force(current_position, current_velocity)
	
	# Combine forces
	avoidance_force = avoidance + separation + bypass + recovery
	
	# Limit the force magnitude
	if avoidance_force.length() > max_avoidance_force:
		avoidance_force = avoidance_force.normalized() * max_avoidance_force
	
	return avoidance_force

func _update_nearby_characters(current_position: Vector3):
	nearby_characters.clear()
	
	# Get all characters in the scene
	if not is_inside_tree():
		return
		
	var characters = get_tree().get_nodes_in_group("gang_members")
	for character in characters:
		if character == get_parent():
			continue  # Skip self
		
		# Check if this character should be considered for collision avoidance
		if not _should_avoid_character(character):
			continue
		
		var distance = current_position.distance_to(character.global_position)
		if distance <= avoidance_radius * 2:  # Check within double the avoidance radius
			nearby_characters.append({
				"node": character,
				"position": character.global_position,
				"distance": distance
			})

func _calculate_avoidance_force(current_position: Vector3, _current_velocity: Vector3) -> Vector3:
	var avoidance = Vector3.ZERO
	var count = 0
	
	for character_data in nearby_characters:
		var other_pos = character_data.position
		var distance = character_data.distance
		
		if distance < avoidance_radius and distance > 0:
			# Calculate direction away from the other character
			var away_direction = (current_position - other_pos).normalized()
			
			# Calculate force strength based on distance (closer = stronger force)
			var force_strength = (avoidance_radius - distance) / avoidance_radius
			force_strength *= avoidance_strength
			
			# Add to avoidance force
			avoidance += away_direction * force_strength
			count += 1
	
	# Average the force if we have multiple characters
	if count > 0:
		avoidance /= count
	
	return avoidance

func _calculate_separation_force(current_position: Vector3) -> Vector3:
	var separation = Vector3.ZERO
	var count = 0
	
	for character_data in nearby_characters:
		var other_pos = character_data.position
		var distance = character_data.distance
		
		if distance < separation_radius and distance > 0:
			# Calculate direction away from the other character
			var away_direction = (current_position - other_pos).normalized()
			
			# Calculate force strength (inverse square law for more natural separation)
			var force_strength = separation_strength / (distance * distance + 0.1)  # Add small value to prevent division by zero
			
			# Add to separation force
			separation += away_direction * force_strength
			count += 1
	
	# Average the force if we have multiple characters
	if count > 0:
		separation /= count
	
	return separation

func get_avoidance_force() -> Vector3:
	return avoidance_force

func set_avoidance_radius(radius: float):
	avoidance_radius = radius

func set_avoidance_strength(strength: float):
	avoidance_strength = strength

func set_separation_radius(radius: float):
	separation_radius = radius

func set_separation_strength(strength: float):
	separation_strength = strength

func _check_stuck_condition(current_position: Vector3, current_time: float):
	# Don't check for stuck condition if we're intentionally idle
	if _is_intentionally_idle():
		# Reset stuck state if we're intentionally idle
		if is_stuck or bypass_active or recovery_active:
			is_stuck = false
			bypass_active = false
			bypass_direction = Vector3.ZERO
			recovery_active = false
		return
	
	# Check if we should update position tracking
	if current_time - last_position_check >= position_check_interval:
		# Check if we've moved significantly
		if last_position != Vector3.ZERO:
			var distance_moved = current_position.distance_to(last_position)
			if distance_moved < 0.1:  # Very small movement threshold
				if not is_stuck:
					# Start stuck timer
					is_stuck = true
					stuck_start_time = current_time
					_initialize_bypass(current_position)
			else:
				# We're moving, check if we should start recovery
				if bypass_active and not recovery_active:
					_start_recovery(current_position, current_time)
				elif not bypass_active:
					# We're moving normally, reset stuck state
					is_stuck = false
					bypass_active = false
					bypass_direction = Vector3.ZERO
					recovery_active = false
		
		last_position = current_position
		last_position_check = current_time
	
	# Check if we've been stuck too long
	if is_stuck and current_time - stuck_start_time > stuck_detection_time:
		bypass_active = true
	
	# Check if recovery should end
	if recovery_active and current_time - recovery_start_time > recovery_duration:
		recovery_active = false
		bypass_active = false
		is_stuck = false

func _initialize_bypass(current_position: Vector3):
	# Find the best direction to bypass around obstacles
	var best_direction = Vector3.ZERO
	var best_score = -1.0
	
	# Try different directions around the character
	for i in range(8):  # 8 directions around the character
		var angle = i * PI / 4.0
		var test_direction = Vector3(cos(angle), 0, sin(angle))
		
		# Check if this direction is clear
		var score = _evaluate_bypass_direction(current_position, test_direction)
		if score > best_score:
			best_score = score
			best_direction = test_direction
	
	bypass_direction = best_direction
	bypass_target = current_position + bypass_direction * bypass_radius

func _evaluate_bypass_direction(current_position: Vector3, direction: Vector3) -> float:
	var score = 1.0  # Base score
	
	# Check for nearby characters in this direction
	for character_data in nearby_characters:
		var other_pos = character_data.position
		var to_other = (other_pos - current_position).normalized()
		var dot_product = direction.dot(to_other)
		
		# Penalize directions that go towards other characters
		if dot_product > 0.5:  # Direction is towards another character
			score -= 0.5
		elif dot_product < -0.5:  # Direction is away from other characters
			score += 0.3
	
	# Prefer directions that are perpendicular to current movement
	# This helps with the "facing each other" problem
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("get") and parent_node.get("base_velocity"):
		var base_velocity = parent_node.get("base_velocity")
		if base_velocity.length() > 0.1:
			var perpendicular_dot = abs(direction.dot(base_velocity.normalized()))
			if perpendicular_dot < 0.3:  # More perpendicular is better
				score += 0.4
	
	return score

func _calculate_bypass_force(current_position: Vector3, _current_velocity: Vector3) -> Vector3:
	if not bypass_active or bypass_direction == Vector3.ZERO:
		return Vector3.ZERO
	
	# Calculate force towards bypass target
	var to_target = (bypass_target - current_position).normalized()
	var distance_to_target = current_position.distance_to(bypass_target)
	
	# If we're close to the bypass target, deactivate bypass
	if distance_to_target < 0.5:
		bypass_active = false
		return Vector3.ZERO
	
	# Calculate bypass force
	var bypass_force = to_target * bypass_strength
	
	# Reduce force as we get closer to target
	var force_multiplier = min(1.0, distance_to_target / bypass_radius)
	bypass_force *= force_multiplier
	
	return bypass_force

func _start_recovery(_current_position: Vector3, current_time: float):
	# Store the original movement direction for recovery
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("get") and parent_node.get("base_velocity"):
		original_direction = parent_node.get("base_velocity").normalized()
	
	recovery_active = true
	recovery_start_time = current_time
	bypass_active = false  # Stop bypassing, start recovering

func _calculate_recovery_force(_current_position: Vector3, _current_velocity: Vector3) -> Vector3:
	if not recovery_active or original_direction == Vector3.ZERO:
		return Vector3.ZERO
	
	# Calculate force to get back on the original path
	# This helps gang members return to their intended route after bypassing
	var recovery_force = original_direction * bypass_strength * 0.5  # Weaker than bypass force
	
	# Gradually reduce recovery force over time
	var recovery_progress = (Time.get_ticks_msec() / 1000.0 - recovery_start_time) / recovery_duration
	var force_multiplier = 1.0 - recovery_progress
	recovery_force *= force_multiplier
	
	return recovery_force

func _should_avoid_character(character: Node) -> bool:
	# Don't avoid characters that are idle or not moving
	# Check if the character has a gang member component with state information
	if character.has_method("get") and character.get("member_id"):
		# This is a visual character node, check if it has a corresponding ECS entity
		var member_id = character.get("member_id")
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					# Only avoid characters that are actively moving (not idle)
					return member_comp.current_state != GangMemberComponent.MemberState.IDLE
	
	# Fallback: check if character is moving by looking at velocity
	if character.has_method("get") and character.get("base_velocity"):
		var base_velocity = character.get("base_velocity")
		return base_velocity.length() > 0.1  # Only avoid if moving
	
	# Default: avoid all characters if we can't determine their state
	return true

func _is_intentionally_idle() -> bool:
	# Check if this character is intentionally idle (not stuck)
	var parent_node = get_parent()
	if not parent_node:
		return false
	
	# Check if we have a member_id and can check the ECS state
	if parent_node.has_method("get") and parent_node.get("member_id"):
		var member_id = parent_node.get("member_id")
		if Engine.has_singleton("EntityManager"):
			var entity_manager = Engine.get_singleton("EntityManager")
			var member_entity = entity_manager.get_entity(member_id)
			if member_entity:
				var member_comp = member_entity.get_component("GangMemberComponent")
				if member_comp:
					# We're intentionally idle if we're in IDLE state
					return member_comp.current_state == GangMemberComponent.MemberState.IDLE
	
	# Fallback: check if we have no base velocity (not moving)
	if parent_node.has_method("get") and parent_node.get("base_velocity"):
		var base_velocity = parent_node.get("base_velocity")
		return base_velocity.length() < 0.1
	
	return false

extends Node
class_name CollisionAvoidanceComponent

# Collision avoidance settings
@export var avoidance_radius: float = 2.0
@export var avoidance_strength: float = 3.0
@export var separation_radius: float = 1.5
@export var separation_strength: float = 2.0
@export var max_avoidance_force: float = 5.0

# Cache for nearby characters
var nearby_characters: Array = []
var avoidance_force: Vector3 = Vector3.ZERO
var last_update_time: float = 0.0
var update_interval: float = 0.1  # Update every 100ms

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
	
	# Calculate avoidance forces
	var avoidance = _calculate_avoidance_force(current_position, current_velocity)
	var separation = _calculate_separation_force(current_position)
	
	# Combine forces
	avoidance_force = avoidance + separation
	
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

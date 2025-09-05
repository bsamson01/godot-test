extends Node3D

# Test script to demonstrate collision avoidance
# This creates multiple characters and makes them move around to test collision avoidance

var characters: Array = []
var test_positions: Array = []

func _ready():
	# Create test positions in a circle
	var center = Vector3(0, 0, 0)
	var radius = 10.0
	var num_positions = 8
	
	for i in range(num_positions):
		var angle = (i * 2 * PI) / num_positions
		var pos = center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		test_positions.append(pos)
	
	# Create characters
	_create_test_characters()

func _create_test_characters():
	# Load the character scene
	var character_scene = preload("res://scenes/game_character.tscn")
	
	# Create 6 characters for testing
	for i in range(6):
		var character = character_scene.instantiate()
		add_child(character)
		characters.append(character)
		
		# Position characters in a circle
		var angle = (i * 2 * PI) / 6
		var radius = 5.0
		var pos = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		character.global_position = pos
		
		# Set a random target position
		_set_random_target(character)

func _set_random_target(character):
	if character.has_method("updateTargetLocation"):
		var random_pos = test_positions[randi() % test_positions.size()]
		character.updateTargetLocation(random_pos)

func _process(_delta):
	# Every 3 seconds, give characters new random targets
	if int(Time.get_time_dict_from_system().second) % 3 == 0:
		for character in characters:
			_set_random_target(character)

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space key
		# Give all characters new random targets
		for character in characters:
			_set_random_target(character)
		print("Gave all characters new random targets!")

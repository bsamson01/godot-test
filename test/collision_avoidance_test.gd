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
	
	# Create a specific test for stuck situation - two characters facing each other
	_create_stuck_test_scenario()

func _set_random_target(character):
	if character.has_method("updateTargetLocation"):
		var random_pos = test_positions[randi() % test_positions.size()]
		character.updateTargetLocation(random_pos)

func _process(_delta):
	# Every 3 seconds, give characters new random targets
	if int(Time.get_time_dict_from_system().second) % 3 == 0:
		for character in characters:
			_set_random_target(character)
	
	# Debug: Print collision avoidance status for first few characters
	if characters.size() > 0:
		for i in range(min(2, characters.size())):
			var character = characters[i]
			if character.has_method("get") and character.get("avoidance_component"):
				var avoidance_comp = character.get("avoidance_component")
				if avoidance_comp.has_method("get") and avoidance_comp.get("is_stuck"):
					print("Character %d: Stuck=%s, Bypass=%s, Recovery=%s" % [
						i, 
						avoidance_comp.get("is_stuck"),
						avoidance_comp.get("bypass_active"),
						avoidance_comp.get("recovery_active")
					])

func _create_stuck_test_scenario():
	# Create two characters that will face each other and get stuck
	var character_scene = preload("res://scenes/game_character.tscn")
	
	# Character 1 - positioned at origin
	var char1 = character_scene.instantiate()
	add_child(char1)
	characters.append(char1)
	char1.global_position = Vector3(0, 0, 0)
	char1.updateTargetLocation(Vector3(5, 0, 0))  # Move right
	
	# Character 2 - positioned to the right, moving left
	var char2 = character_scene.instantiate()
	add_child(char2)
	characters.append(char2)
	char2.global_position = Vector3(2, 0, 0)  # Close to char1
	char2.updateTargetLocation(Vector3(-5, 0, 0))  # Move left (towards char1)
	
	print("Created stuck test scenario: Two characters facing each other!")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space key
		# Give all characters new random targets
		for character in characters:
			_set_random_target(character)
		print("Gave all characters new random targets!")
	elif event.is_action_pressed("ui_select"):  # Enter key
		# Create stuck test scenario
		_create_stuck_test_scenario()
		print("Created new stuck test scenario!")

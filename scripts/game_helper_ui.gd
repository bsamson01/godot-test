extends Control
class_name GameHelperUI

# UI Elements
@onready var time_label: Label
@onready var day_label: Label
@onready var time_of_day_label: Label
@onready var tick_label: Label

# Game Manager reference
var game_manager: GameManager

# Time display data
var current_tick: int = 0
var current_day: int = 0
var time_of_day: String = "Day"
var game_time: float = 0.0

func _ready():
	# Create UI elements
	_setup_ui()
	
	# Get game manager reference - try multiple paths
	# Since world.tscn has main.gd as root, GameManager should be a child of root
	game_manager = get_node_or_null("../GameManager")
	if not game_manager:
		game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		game_manager = get_node_or_null("/root/Main/GameManager")
	if not game_manager:
		# Search for GameManager in the scene tree
		game_manager = _find_game_manager()
	
	# Connect to game events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.TICK_PROCESSED, _on_tick_processed)
		event_bus.subscribe(EventBus.EventType.DAY_STARTED, _on_day_started)
	
	# Debug: Check if we found the game manager
	if game_manager:
		print("GameHelperUI: Found GameManager at: ", game_manager.get_path())
		print("GameHelperUI: GameManager current_tick: ", game_manager.current_tick)
	else:
		print("GameHelperUI: GameManager not found!")
		print("GameHelperUI: Scene tree structure:")
		_print_scene_tree(get_tree().root, 0)
	
	# Start a timer to update time display as fallback
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update every 0.1 seconds
	timer.timeout.connect(_fallback_update)
	add_child(timer)
	timer.start()
	
	# Also try to find GameManager again after a delay
	await get_tree().create_timer(1.0).timeout
	if not game_manager:
		game_manager = _find_game_manager()
		if game_manager:
			print("GameHelperUI: Found GameManager on retry at: ", game_manager.get_path())
	
	# Try one more time after 2 seconds
	await get_tree().create_timer(2.0).timeout
	if not game_manager:
		game_manager = _find_game_manager()
		if game_manager:
			print("GameHelperUI: Found GameManager on second retry at: ", game_manager.get_path())
		else:
			print("GameHelperUI: Still no GameManager found after all attempts")

func _setup_ui():
	# Create main container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	main_container.position = Vector2(20, 20)
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Create time display panel
	var time_panel = Panel.new()
	time_panel.custom_minimum_size = Vector2(320, 140)
	time_panel.add_theme_stylebox_override("panel", _create_panel_style())
	main_container.add_child(time_panel)
	
	var time_container = VBoxContainer.new()
	time_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	time_container.add_theme_constant_override("separation", 8)
	time_container.add_theme_constant_override("margin_left", 10)
	time_container.add_theme_constant_override("margin_right", 10)
	time_container.add_theme_constant_override("margin_top", 10)
	time_container.add_theme_constant_override("margin_bottom", 10)
	time_panel.add_child(time_container)
	
	# Title
	var title_label = Label.new()
	title_label.text = "GAME TIME"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.YELLOW)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_container.add_child(title_label)
	
	# Day display
	day_label = Label.new()
	day_label.text = "Day: 1"
	day_label.add_theme_font_size_override("font_size", 24)
	day_label.add_theme_color_override("font_color", Color.WHITE)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_container.add_child(day_label)
	
	# Time of day display
	time_of_day_label = Label.new()
	time_of_day_label.text = "Time: Day"
	time_of_day_label.add_theme_font_size_override("font_size", 18)
	time_of_day_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	time_of_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_container.add_child(time_of_day_label)
	
	# Current time display
	time_label = Label.new()
	time_label.text = "Hour: 0"
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_container.add_child(time_label)
	
	# Tick display
	tick_label = Label.new()
	tick_label.text = "Tick: 0"
	tick_label.add_theme_font_size_override("font_size", 12)
	tick_label.add_theme_color_override("font_color", Color.GRAY)
	tick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_container.add_child(tick_label)
	
	
	# Set initial values for testing
	_update_time_display()

func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.8)
	return style

func _on_tick_processed(event: EventBus.Event):
	# Update time data from event
	current_tick = event.data.get("tick", 0)
	time_of_day = event.data.get("time_of_day", "Day")
	
	# Calculate current day
	current_day = int(current_tick / 24) + 1
	
	# Debug: Print every 10 ticks
	if current_tick % 10 == 0:
		print("GameHelperUI: Tick processed - Day: %d, Hour: %d, Time: %s" % [current_day, current_tick % 24, time_of_day])
	
	# Update UI
	_update_time_display()

func _on_day_started(event: EventBus.Event):
	current_day = int(event.data.get("day", 0)) + 1
	_update_time_display()

func _update_time_display():
	# Update day display
	day_label.text = "Day: %d" % current_day
	
	# Update time of day with color coding
	time_of_day_label.text = "Time: %s" % time_of_day
	if time_of_day == "Day":
		time_of_day_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	else:
		time_of_day_label.add_theme_color_override("font_color", Color.DARK_BLUE)
	
	# Update hour display
	var current_hour = current_tick % 24
	time_label.text = "Hour: %d" % current_hour
	
	# Update tick display
	tick_label.text = "Tick: %d" % current_tick

func get_formatted_time() -> String:
	var current_hour = current_tick % 24
	return "Day %d, Hour %d (%s)" % [current_day, current_hour, time_of_day]

func get_game_time_info() -> Dictionary:
	return {
		"day": current_day,
		"hour": current_tick % 24,
		"tick": current_tick,
		"time_of_day": time_of_day,
		"formatted": get_formatted_time()
	}

# Method to get current game time from anywhere
func get_current_game_time() -> Dictionary:
	if game_manager:
		return {
			"day": int(game_manager.current_tick / 24) + 1,
			"hour": game_manager.current_tick % 24,
			"tick": game_manager.current_tick,
			"time_of_day": "Day" if (game_manager.current_tick % 24) < 12 else "Night",
			"game_time": game_manager.game_time
		}
	return {}

# Method to check if it's a specific time of day
func is_day_time() -> bool:
	return time_of_day == "Day"

func is_night_time() -> bool:
	return time_of_day == "Night"

# Method to get time until next day/night transition
func get_time_until_transition() -> int:
	if is_day_time():
		return 12 - (current_tick % 24)
	else:
		return 24 - (current_tick % 24)

# Helper function to find GameManager in the scene tree
func _find_game_manager() -> GameManager:
	var root = get_tree().root
	return _search_for_game_manager(root)

func _search_for_game_manager(node: Node) -> GameManager:
	if node is GameManager:
		return node
	
	for child in node.get_children():
		var result = _search_for_game_manager(child)
		if result:
			return result
	
	return null

# Debug function to print scene tree
func _print_scene_tree(node: Node, depth: int):
	var indent = ""
	for i in range(depth):
		indent += "  "
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_print_scene_tree(child, depth + 1)


# Fallback update method in case events don't work
func _fallback_update():
	if game_manager:
		# Get time data directly from game manager
		var new_tick = game_manager.current_tick
		var new_time_of_day = "Day" if (new_tick % 24) < 12 else "Night"
		
		# Always update the display (for debugging)
		current_tick = new_tick
		time_of_day = new_time_of_day
		current_day = int(current_tick / 24) + 1
		_update_time_display()
		
		# Debug: Print every 10 ticks
		if current_tick % 10 == 0:
			print("GameHelperUI: Fallback update - Day: %d, Hour: %d, Time: %s" % [current_day, current_tick % 24, time_of_day])
	else:
		print("GameHelperUI: Fallback update called but no GameManager")

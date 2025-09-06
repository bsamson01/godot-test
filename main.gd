# Main.gd - Entry point using the new component-based architecture
extends Node

var game_manager: GameManager
var config: GameConfig

@onready var dashboard = $UI/UIContainer/FactionDashboard if has_node("UI/UIContainer/FactionDashboard") else null

func _ready():
	# Set up global error handling
	_setup_error_handling()
	
	# Load configuration
	config = GameConfig.get_default()
	
	# Optionally load from file
	var config_path = "user://game_coni.json"
	if FileAccess.file_exists(config_path):
		config.load_from_file(config_path)
	
	# Validate configuration
	var validation = config.validate()
	if not validation.is_valid:
		push_error("Invalid game configuration: " + validation.to_string())
		return
	
	# Create game manager first
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	add_child(game_manager)
	
	# Wait one frame for GameManager to be ready
	await get_tree().process_frame
	
	# Initialize the game world with factions, bases, and businesses
	var init_script = load("res://scripts/Init.gd").new()
	init_script.init_all({
		"faction_count": 1,  # Create 2 factions
		"members_per_faction": 3,  # 3 gang members per faction
		"territories_per_faction": 1,
		"businesses_per_territory": 1  # Create 1 business per territory
	}, game_manager)
	add_child(init_script)
	
	# Connect to game events for UI updates
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.TICK_PROCESSED, _on_tick_processed)
		event_bus.subscribe(EventBus.EventType.DAY_STARTED, _on_day_started)
	
	Logger.info("Game initialized with configuration:", "Main")
	Logger.info(config.get_summary(), "Main")

func _on_tick_processed(event: EventBus.Event):
	# Update UI if available
	if dashboard and dashboard.has_method("render_all"):
		dashboard.render_all()
	
	# Performance monitoring
	if event.data.get("tick", 0) % 100 == 0:
		_print_performance_stats()

func _on_day_started(event: EventBus.Event):
	# Day change notifications
	var day = event.data.get("day", 0)
	Logger.info("=== Day %d Started ===" % day, "Main")

func _print_performance_stats():
	if not game_manager:
		return
	
	var stats = game_manager.get_game_stats()
	Logger.debug("--- Performance Stats ---", "Main")
	Logger.debug("Entities: %d" % stats.entity_count, "Main")
	Logger.debug("Updates per frame: %d/%d" % [stats.performance.updates_per_frame, stats.performance.max_updates], "Main")
	Logger.debug("Event queue size: %d" % stats.event_stats.queue_size, "Main")
	Logger.debug("Events processed: %d" % stats.event_stats.events_processed, "Main")

func _input(event):
	# Debug controls
	if event.is_action_pressed("ui_cancel"):
		# Pause/unpause
		if game_manager:
			if game_manager.is_running:
				game_manager.pause_game()
				Logger.info("Game paused", "Main")
			else:
				game_manager.start_game()
				Logger.info("Game resumed", "Main")
	
	elif event.is_action_pressed("ui_select"):
		# Print detailed report
		_print_detailed_report()

func _print_detailed_report():
	if not game_manager:
		return
	
	Logger.info("=== DETAILED GAME REPORT ===", "Main")
	
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return
	
	# Faction reports
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	for faction_entity in factions:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if not faction_comp:
			continue
		
		Logger.info("Faction: %s" % faction_comp.faction_name, "Main")
		Logger.info("  Funds: %.1f | Supplies: %.1f" % [faction_comp.funds, faction_comp.supplies], "Main")
		Logger.info("  Members: %d | Territories: %d | Businesses: %d" % [
			faction_comp.get_members().size(),
			faction_comp.get_territories().size(),
			faction_comp.get_businesses().size()
		], "Main")
		
		# Commander AI status
		var commander_ais = faction_comp.get_members().filter(func(m):
			return m.has_component("CommanderAIComponent")
		)
		
		for commander in commander_ais:
			var ai_comp = commander.get_component("CommanderAIComponent")
			if ai_comp:
				var strategy = ai_comp.get_strategy_summary()
				Logger.info("  Commander AI: Goal=%s, Priority=%.1f, Orders=%d" % [
					strategy.current_goal,
					strategy.goal_priority,
					strategy.orders_in_queue
				], "Main")
		
		# Member status summary
		var states = {}
		for member_entity in faction_comp.get_members():
			var member_comp = member_entity.get_component("GangMemberComponent")
			if member_comp:
				var state = GangMemberComponent.MemberState.keys()[member_comp.current_state]
				states[state] = states.get(state, 0) + 1
		
		Logger.info("  Member States: " + str(states), "Main")
	
	# System stats
	var stats = game_manager.get_game_stats()
	Logger.info("System Performance:", "Main")
	Logger.info("  " + JSON.stringify(stats.entity_stats), "Main")
	Logger.info("  " + JSON.stringify(stats.event_stats), "Main")

func _setup_error_handling():
	# Set up custom error handling
	# Note: Godot doesn't have a global error signal, so we'll handle errors
	# through the Logger system and try-catch blocks where needed
	
	Logger.info("Error handling initialized", "ErrorHandler")
	
	# Test logging system
	_test_logging_system()

func _test_logging_system():
	# Test different log levels
	Logger.debug("This is a debug message", "Test")
	Logger.info("This is an info message", "Test")
	Logger.warning("This is a warning message", "Test")
	Logger.error("This is a test error message", "Test")
	Logger.critical("This is a critical message", "Test")
	
	# Test with data
	Logger.info("Test with data", "Test", {"test_value": 42, "test_array": [1, 2, 3]})
	
	# Log file paths
	Logger.info("Log files created:", "Test", {
		"game_log": Logger.get_log_file_path(),
		"error_log": Logger.get_error_log_file_path()
	})


func _exit_tree():
	# Save configuration on exit
	if config:
		config.save_to_file("user://game_config1.json")
	
	# Flush logs before exit
	Logger.flush_logs()

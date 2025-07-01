# Main.gd - Entry point using the new component-based architecture
extends Node

var game_manager: GameManager
var config: GameConfig

@onready var dashboard = $UI/UIContainer/FactionDashboard if has_node("UI/UIContainer/FactionDashboard") else null

func _ready():
	# Load configuration
	config = GameConfig.get_default()
	
	# Optionally load from file
	var config_path = "user://game_config.json"
	if FileAccess.file_exists(config_path):
		config.load_from_file(config_path)
	
	# Validate configuration
	var validation = config.validate()
	if not validation.is_valid:
		push_error("Invalid game configuration: " + validation.to_string())
		return
	
	# Create game manager
	game_manager = GameManager.new()
	game_manager.name = "GameManager"
	game_manager.config = config.duplicate()  # Use a copy of the config
	add_child(game_manager)
	
	# Connect to game events for UI updates
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.TICK_PROCESSED, _on_tick_processed)
		event_bus.subscribe(EventBus.EventType.DAY_STARTED, _on_day_started)
	
	print("Game initialized with configuration:")
	print(config.get_summary())

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
	print("\n=== Day %d Started ===" % day)

func _print_performance_stats():
	if not game_manager:
		return
	
	var stats = game_manager.get_game_stats()
	print("\n--- Performance Stats ---")
	print("Entities: %d" % stats.entity_count)
	print("Updates per frame: %d/%d" % [stats.performance.updates_per_frame, stats.performance.max_updates])
	print("Event queue size: %d" % stats.event_stats.queue_size)
	print("Events processed: %d" % stats.event_stats.events_processed)

func _input(event):
	# Debug controls
	if event.is_action_pressed("ui_cancel"):
		# Pause/unpause
		if game_manager:
			if game_manager.is_running:
				game_manager.pause_game()
				print("Game paused")
			else:
				game_manager.start_game()
				print("Game resumed")
	
	elif event.is_action_pressed("ui_select"):
		# Print detailed report
		_print_detailed_report()

func _print_detailed_report():
	if not game_manager:
		return
	
	print("\n=== DETAILED GAME REPORT ===")
	
	var entity_manager = Engine.get_singleton("EntityManager")
	if not entity_manager:
		return
	
	# Faction reports
	var factions = entity_manager.get_entities_with_component("FactionComponent")
	for faction_entity in factions:
		var faction_comp = faction_entity.get_component("FactionComponent")
		if not faction_comp:
			continue
		
		print("\nFaction: %s" % faction_comp.faction_name)
		print("  Funds: %.1f | Supplies: %.1f" % [faction_comp.funds, faction_comp.supplies])
		print("  Members: %d | Territories: %d | Businesses: %d" % [
			faction_comp.get_members().size(),
			faction_comp.get_territories().size(),
			faction_comp.get_businesses().size()
		])
		
		# Commander AI status
		var commander_ais = faction_comp.get_members().filter(func(m):
			return m.has_component("CommanderAIComponent")
		)
		
		for commander in commander_ais:
			var ai_comp = commander.get_component("CommanderAIComponent")
			if ai_comp:
				var strategy = ai_comp.get_strategy_summary()
				print("  Commander AI: Goal=%s, Priority=%.1f, Orders=%d" % [
					strategy.current_goal,
					strategy.goal_priority,
					strategy.orders_in_queue
				])
		
		# Member status summary
		var states = {}
		for member_entity in faction_comp.get_members():
			var member_comp = member_entity.get_component("GangMemberComponent")
			if member_comp:
				var state = GangMemberComponent.MemberState.keys()[member_comp.current_state]
				states[state] = states.get(state, 0) + 1
		
		print("  Member States:", states)
	
	# System stats
	var stats = game_manager.get_game_stats()
	print("\nSystem Performance:")
	print("  " + JSON.stringify(stats.entity_stats))
	print("  " + JSON.stringify(stats.event_stats))

func _exit_tree():
	# Save configuration on exit
	if config:
		config.save_to_file("user://game_config.json")

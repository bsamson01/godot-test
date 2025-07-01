# Updated Main.gd - Compatible with refactored architecture
extends Node

@onready var clock = $Clock

var ticks_per_day = 24
@onready var initializer = preload("res://scripts/Init.gd").new()
@onready var dashboard = $UI/UIContainer/FactionDashboard

func _ready():
	# Initialize the game world
	initializer.init_all()
	clock.start()

func _on_tick(time_data: Dictionary):
	if initializer == null:
		push_warning("Initializer not set — skipping tick logic.")
		return

	var tick = time_data["tick"]
	var time_of_day = time_data["time_of_day"]
	var is_new_day = tick % 24 == 0
	var tick_in_day = tick % 24
	var hour = tick_in_day
	var hour_str = "%02d:00" % hour

	# Update WorldState with current tick
	WorldState.update_tick(tick)

	# Process business income
	_process_business_income(time_of_day)
	
	_process_faction_processes()
	
	# Process all gang member AI
	_process_gang_member_ai(tick)

	# Daily reports
	if is_new_day:
		_print_daily_reports()
		
	dashboard.render_all()

func _process_faction_processes():
	for faction in WorldState.get_all_factions():
		if faction == null:
			continue
		
		faction.use_supplies()
	
func _process_business_income(time_of_day: String):
	for business in WorldState.get_all_businesses():
		if business == null:
			continue
			
		var territory = business.get_territory()
		var owner_faction = business.get_owner_faction()
		
		if not territory or not owner_faction:
			continue
			
		# Calculate territory safety (placeholder logic)
		var is_safe = randf() > 0.3
		
		# Calculate and apply income
		var income = business.calculate_income(time_of_day, is_safe)
		business.current_income += income
		owner_faction.add_income(income, business.id)

func _process_gang_member_ai(tick: int):
	# Process through WorldState's registered nodes
	for gang_member_node in WorldState.gang_member_nodes:
		if gang_member_node == null:
			continue
			
		# Get the member data to check if they're alive
		var member = gang_member_node.get_member()
		if not member or member.state == "dead":
			continue

		gang_member_node.process_tick(tick)

func _print_daily_reports():
	print("--- DAILY INCOME REPORT ---")
	for faction in WorldState.get_all_factions():
		if faction == null:
			continue
			
		var daily_total := 0.0
		for entry in faction.income_log:
			daily_total += entry["amount"]
		
		print("%s earned => %.1f" % [faction.name, daily_total])
		
		# Clear the log for next day
		faction.income_log.clear()
		
		# Print member status
		print("  Members: %d" % faction.get_members().size())
		for member in faction.get_members():
			print("    %s (%s): %s" % [member.name, member.role, member.state])
		print("---")

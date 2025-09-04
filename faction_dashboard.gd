# faction_dashboard.gd - UI Dashboard for faction management
extends Control

@onready var faction_list = $ScrollContainer/FactionList

var factions: Array = []

func _ready():
	print("Faction Dashboard initialized")
	# Connect to game events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.TICK_PROCESSED, _on_tick_processed)

func _on_tick_processed(event: EventBus.Event):
	# Update UI every 10 ticks to avoid performance issues
	if event.data.get("tick", 0) % 10 == 0:
		update_display()

func update_display():
	# Clear existing display
	for child in faction_list.get_children():
		child.queue_free()
	
	# Get factions from both systems for compatibility
	var all_factions = []
	
	# Try new ECS system first
	if Engine.has_singleton("EntityManager"):
		var entity_manager = Engine.get_singleton("EntityManager")
		var faction_entities = entity_manager.get_entities_with_component("FactionComponent")
		for faction_entity in faction_entities:
			var faction_comp = faction_entity.get_component("FactionComponent")
			if faction_comp:
				all_factions.append({
					"name": faction_comp.faction_name,
					"funds": faction_comp.funds,
					"supplies": faction_comp.supplies,
					"members": faction_comp.get_members().size(),
					"color": faction_comp.color
				})
	
	# Fallback to old system if no ECS factions found
	if all_factions.is_empty():
		all_factions = WorldState.get_all_factions()
		for faction in all_factions:
			all_factions.append({
				"name": faction.name,
				"funds": faction.funds,
				"supplies": faction.supplies,
				"members": faction.get_members().size(),
				"color": faction.color
			})
	
	# Create UI elements for each faction
	for faction_data in all_factions:
		_create_faction_panel(faction_data)

func _create_faction_panel(faction_data: Dictionary):
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 100)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	# Faction name
	var name_label = Label.new()
	name_label.text = faction_data.get("name", "Unknown Faction")
	name_label.add_theme_color_override("font_color", faction_data.get("color", Color.WHITE))
	vbox.add_child(name_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "Funds: %.1f | Supplies: %.1f | Members: %d" % [
		faction_data.get("funds", 0),
		faction_data.get("supplies", 0),
		faction_data.get("members", 0)
	]
	vbox.add_child(stats_label)
	
	faction_list.add_child(panel)

func render_all():
	update_display()

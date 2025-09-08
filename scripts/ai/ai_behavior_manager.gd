# AIBehaviorManager.gd - Manages AI behavior trees and integrates with ECS
extends Node
class_name AIBehaviorManager

# Behavior tree instances by entity ID
var behavior_trees: Dictionary = {} # entity_id -> BTPlayer

# AI state tracking
var ai_states: Dictionary = {} # entity_id -> Dictionary

# Performance settings
var max_ai_updates_per_frame: int = 10
var ai_update_budget: float = 0.016  # 16ms per frame

func _ready():
	# Subscribe to entity events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.ENTITY_CREATED, _on_entity_created)
		event_bus.subscribe(EventBus.EventType.ENTITY_DESTROYED, _on_entity_destroyed)

func _process(delta: float):
	_update_ai_behavior_trees(delta)

func _update_ai_behavior_trees(delta: float):
	var start_time = Time.get_ticks_usec()
	var updates_this_frame = 0
	
	for entity_id in behavior_trees:
		if updates_this_frame >= max_ai_updates_per_frame:
			break
		
		var bt_player = behavior_trees[entity_id]
		if bt_player and is_instance_valid(bt_player):
			# Update the behavior tree
			bt_player.update(delta)
			updates_this_frame += 1
		
		# Check frame budget
		var elapsed = (Time.get_ticks_usec() - start_time) / 1000000.0
		if elapsed > ai_update_budget:
			break

func create_behavior_tree_for_entity(entity: Entity, behavior_tree_resource: Resource) -> BTPlayer:
	if not entity:
		Logger.error("Cannot create behavior tree for null entity", "AIBehaviorManager")
		return null
	
	# Create BTPlayer
	var bt_player = BTPlayer.new()
	bt_player.behavior_tree = behavior_tree_resource
	
	# Create blackboard
	var blackboard = Blackboard.new()
	bt_player.blackboard = blackboard
	
	# Set up blackboard variables
	_setup_blackboard_for_entity(blackboard, entity)
	
	# Store reference
	behavior_trees[entity.id] = bt_player
	
	# Add to entity for easy access
	entity.set_meta("bt_player", bt_player)
	
	Logger.info("Behavior tree created for entity", "AIBehaviorManager", {
		"entity_id": entity.id,
		"entity_type": entity.entity_type
	})
	
	return bt_player

func remove_behavior_tree_for_entity(entity_id: String) -> void:
	if behavior_trees.has(entity_id):
		var bt_player = behavior_trees[entity_id]
		if bt_player and is_instance_valid(bt_player):
			bt_player.queue_free()
		behavior_trees.erase(entity_id)
		ai_states.erase(entity_id)
		
		Logger.info("Behavior tree removed for entity", "AIBehaviorManager", {
			"entity_id": entity_id
		})

func _setup_blackboard_for_entity(blackboard: Blackboard, entity: Entity) -> void:
	# Set up common blackboard variables
	blackboard.set_var("entity_id", entity.id)
	blackboard.set_var("entity_type", entity.entity_type)
	
	# Set up entity-specific variables
	var member_comp = entity.get_component("GangMemberComponent")
	if member_comp:
		blackboard.set_var("member_name", member_comp.member_name)
		blackboard.set_var("member_role", member_comp.role)
		blackboard.set_var("member_loyalty", member_comp.loyalty)
		blackboard.set_var("member_state", member_comp.current_state)
		blackboard.set_var("faction_id", member_comp.faction_id)
		blackboard.set_var("has_order", member_comp.current_order != null)
		
		# Set up order variables
		if member_comp.current_order:
			var order_comp = member_comp.current_order.get_component("OrderComponent")
			if order_comp:
				blackboard.set_var("current_order", member_comp.current_order)
				blackboard.set_var("order_type", order_comp.get_order_type())
				blackboard.set_var("order_status", order_comp.get_status())
				blackboard.set_var("target_npc_id", order_comp.target_id)
	
	# Set up AI state
	ai_states[entity.id] = {
		"last_update": Time.get_ticks_msec() / 1000.0,
		"current_goal": "",
		"goal_priority": 0.0,
		"is_thinking": false
	}

func update_blackboard_for_entity(entity: Entity) -> void:
	var bt_player = behavior_trees.get(entity.id)
	if not bt_player or not bt_player.blackboard:
		return
	
	var blackboard = bt_player.blackboard
	
	# Update member-specific variables
	var member_comp = entity.get_component("GangMemberComponent")
	if member_comp:
		blackboard.set_var("member_state", member_comp.current_state)
		blackboard.set_var("member_loyalty", member_comp.loyalty)
		blackboard.set_var("has_order", member_comp.current_order != null)
		
		# Update order variables
		if member_comp.current_order:
			var order_comp = member_comp.current_order.get_component("OrderComponent")
			if order_comp:
				blackboard.set_var("current_order", member_comp.current_order)
				blackboard.set_var("order_type", order_comp.get_order_type())
				blackboard.set_var("order_status", order_comp.get_status())
				blackboard.set_var("target_npc_id", order_comp.target_id)
		else:
			blackboard.set_var("current_order", null)
			blackboard.set_var("order_type", -1)
			blackboard.set_var("order_status", -1)
			blackboard.set_var("target_npc_id", "")
	
	# Update AI state
	if ai_states.has(entity.id):
		var ai_state = ai_states[entity.id]
		ai_state.last_update = Time.get_ticks_msec() / 1000.0

func get_ai_state(entity_id: String) -> Dictionary:
	return ai_states.get(entity_id, {})

func set_ai_goal(entity_id: String, goal: String, priority: float = 0.0) -> void:
	if ai_states.has(entity_id):
		ai_states[entity_id].current_goal = goal
		ai_states[entity_id].goal_priority = priority
		
		# Update blackboard
		var bt_player = behavior_trees.get(entity_id)
		if bt_player and bt_player.blackboard:
			bt_player.blackboard.set_var("current_goal", goal)
			bt_player.blackboard.set_var("goal_priority", priority)

func is_entity_thinking(entity_id: String) -> bool:
	var ai_state = ai_states.get(entity_id, {})
	return ai_state.get("is_thinking", false)

func set_entity_thinking(entity_id: String, thinking: bool) -> void:
	if ai_states.has(entity_id):
		ai_states[entity_id].is_thinking = thinking

# Event handlers
func _on_entity_created(event: EventBus.Event) -> void:
	var entity_id = event.data.get("entity_id")
	if not entity_id:
		Logger.warning("Entity created event missing entity_id", "AIBehaviorManager")
		return
	
	var entity = Engine.get_singleton("EntityManager").get_entity(entity_id)
	if not entity:
		return
	
	# Check if entity needs a behavior tree
	var member_comp = entity.get_component("GangMemberComponent")
	if member_comp:
		# Create behavior tree for gang member
		var behavior_tree_resource = load("res://ai/behaviors/master_ai_behavior.tres")
		if behavior_tree_resource:
			create_behavior_tree_for_entity(entity, behavior_tree_resource)
		else:
			Logger.warning("Could not load master AI behavior tree", "AIBehaviorManager")

func _on_entity_destroyed(event: EventBus.Event) -> void:
	var entity_id = event.data.get("entity_id")
	if not entity_id:
		Logger.warning("Entity destroyed event missing entity_id", "AIBehaviorManager")
		return
	
	remove_behavior_tree_for_entity(entity_id)

func get_stats() -> Dictionary:
	return {
		"active_behavior_trees": behavior_trees.size(),
		"ai_states_tracked": ai_states.size(),
		"max_updates_per_frame": max_ai_updates_per_frame,
		"update_budget_ms": ai_update_budget * 1000.0
	}

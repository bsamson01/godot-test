# AIComponent.gd - Base AI component for decision making
extends Component
class_name AIComponent

@export var decision_interval: float = 2.0  # Seconds between decisions
@export var ai_type: String = "base"
@export var enabled: bool = true

# Decision tracking
var last_decision_time: float = 0.0
var decisions_made: int = 0
var current_goal: String = ""
var goal_priority: float = 0.0

# Performance throttling
var think_budget: float = 0.016  # Max time per frame (16ms)
var decisions_per_update: int = 1

# Cache for expensive calculations
var cached_state: Dictionary = {}
var cache_valid_until: float = 0.0

func get_component_name() -> String:
	return "AIComponent"

func _on_attached(entity: Entity) -> void:
	# Subscribe to AI-relevant events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.AI_STATE_CHANGED, _on_ai_state_changed)

func _on_detached(entity: Entity) -> void:
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.AI_STATE_CHANGED, _on_ai_state_changed)

func update(delta: float) -> void:
	if not enabled or not is_enabled:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check if it's time to make a decision
	if current_time - last_decision_time >= decision_interval:
		var start_time = Time.get_ticks_usec()
		
		# Update cached state if needed
		if current_time > cache_valid_until:
			_update_cached_state()
		
		# Make decision
		_think()
		
		last_decision_time = current_time
		decisions_made += 1
		
		# Track performance
		var elapsed = (Time.get_ticks_usec() - start_time) / 1000000.0
		if elapsed > think_budget:
			Logger.warning("AI think time exceeded budget", "AI", {
				"ai_type": ai_type,
				"elapsed": elapsed,
				"budget": think_budget
			})

func _think() -> void:
	# Get current world state
	var world_state = _gather_world_state()
	
	# Evaluate possible goals
	var goals = _evaluate_goals(world_state)
	
	# Select best goal
	var best_goal = _select_goal(goals)
	
	if best_goal and best_goal.name != current_goal:
		_set_goal(best_goal)
	
	# Execute current goal
	if current_goal:
		_execute_goal(world_state)

func _gather_world_state() -> Dictionary:
	# Override in subclasses to gather relevant state
	return cached_state

func _update_cached_state() -> void:
	# Override in subclasses to update cached data
	cached_state.clear()
	cache_valid_until = Time.get_ticks_msec() / 1000.0 + 5.0  # Cache for 5 seconds

func _evaluate_goals(world_state: Dictionary) -> Array[Dictionary]:
	# Override in subclasses to evaluate possible goals
	return []

func _select_goal(goals: Array[Dictionary]) -> Dictionary:
	# Select highest priority goal
	var best_goal = null
	var best_priority = -1.0
	
	for goal in goals:
		if goal.priority > best_priority:
			best_priority = goal.priority
			best_goal = goal
	
	return best_goal

func _set_goal(goal: Dictionary) -> void:
	var old_goal = current_goal
	current_goal = goal.name
	goal_priority = goal.priority
	
	Logger.debug("AI goal changed", "AI", {
		"ai_type": ai_type,
		"old_goal": old_goal,
		"new_goal": current_goal,
		"priority": goal_priority
	})
	
	# Emit decision event
	if Engine.has_singleton("EventBus"):
		Engine.get_singleton("EventBus").emit_event(
			EventBus.EventType.AI_DECISION_MADE,
			{
				"entity_id": entity.id,
				"ai_type": ai_type,
				"goal": current_goal,
				"priority": goal_priority
			}
		)

func _execute_goal(world_state: Dictionary) -> void:
	# Override in subclasses to execute the current goal
	pass

func set_decision_interval(interval: float) -> void:
	decision_interval = max(0.1, interval)  # Minimum 0.1 seconds

func force_think() -> void:
	# Force an immediate decision
	_think()
	last_decision_time = Time.get_ticks_msec() / 1000.0

func _on_ai_state_changed(event: EventBus.Event) -> void:
	if event.data.get("entity_id") == entity.id:
		# Invalidate cache when state changes
		cache_valid_until = 0.0

# EventBus.gd - Central event system for decoupled communication
extends Node
class_name EventBus

# Event types
enum EventType {
	# Entity events
	ENTITY_CREATED,
	ENTITY_DESTROYED,
	ENTITY_STATE_CHANGED,
	
	# Faction events
	FACTION_FUNDS_CHANGED,
	FACTION_SUPPLIES_CHANGED,
	FACTION_MEMBER_ADDED,
	FACTION_MEMBER_REMOVED,
	FACTION_TERRITORY_GAINED,
	FACTION_TERRITORY_LOST,
	
	# Combat events
	COMBAT_STARTED,
	COMBAT_ENDED,
	DAMAGE_DEALT,
	ENTITY_KILLED,
	
	# Order events
	ORDER_CREATED,
	ORDER_ASSIGNED,
	ORDER_COMPLETED,
	ORDER_FAILED,
	ORDER_CANCELLED,
	
	# Business events
	BUSINESS_INCOME_GENERATED,
	BUSINESS_CAPTURED,
	BUSINESS_DESTROYED,
	
	# AI events
	AI_DECISION_MADE,
	AI_STATE_CHANGED,
	
	# Time events
	DAY_STARTED,
	NIGHT_STARTED,
	TICK_PROCESSED
}

class Event:
	var type: EventType
	var data: Dictionary
	var priority: int = 0
	var timestamp: float
	var sender: Object = null
	
	func _init(type: EventType, data: Dictionary = {}, priority: int = 0):
		self.type = type
		self.data = data
		self.priority = priority
		self.timestamp = Time.get_ticks_msec() / 1000.0

# Event queue with priority
var event_queue: Array[Event] = []
var immediate_queue: Array[Event] = []
var processing_events: bool = false

# Subscribers
var subscribers: Dictionary = {} # EventType -> Array[Callable]
var type_filters: Dictionary = {} # EventType -> Array[Callable] for filtering

# Performance settings
var max_events_per_frame: int = 100
var event_history_size: int = 1000
var event_history: Array[Event] = []

# Stats
var events_processed: int = 0
var events_dropped: int = 0

func _ready():
	set_process(true)

func _process(_delta: float):
	_process_events()

func subscribe(event_type: EventType, callback: Callable) -> void:
	if not subscribers.has(event_type):
		subscribers[event_type] = []
	
	if not subscribers[event_type].has(callback):
		subscribers[event_type].append(callback)

func unsubscribe(event_type: EventType, callback: Callable) -> void:
	if subscribers.has(event_type):
		subscribers[event_type].erase(callback)
		if subscribers[event_type].is_empty():
			subscribers.erase(event_type)

func emit_event(event_type: EventType, data: Dictionary = {}, priority: int = 0, sender: Object = null) -> void:
	var event = Event.new(event_type, data, priority)
	event.sender = sender
	
	# Apply filters
	if type_filters.has(event_type):
		for filter in type_filters[event_type]:
			if not filter.call(event):
				events_dropped += 1
				return
	
	# Add to appropriate queue
	if priority >= 100:  # Immediate processing
		immediate_queue.append(event)
	else:
		event_queue.append(event)
		# Sort by priority (higher first)
		event_queue.sort_custom(func(a, b): return a.priority > b.priority)

func emit_event_deferred(event_type: EventType, data: Dictionary = {}, priority: int = 0, sender: Object = null) -> void:
	call_deferred("emit_event", event_type, data, priority, sender)

func add_filter(event_type: EventType, filter: Callable) -> void:
	if not type_filters.has(event_type):
		type_filters[event_type] = []
	type_filters[event_type].append(filter)

func remove_filter(event_type: EventType, filter: Callable) -> void:
	if type_filters.has(event_type):
		type_filters[event_type].erase(filter)

func _process_events() -> void:
	if processing_events:
		return
	
	processing_events = true
	var events_this_frame = 0
	
	# Process immediate events first
	while immediate_queue.size() > 0 and events_this_frame < max_events_per_frame:
		var event = immediate_queue.pop_front()
		_dispatch_event(event)
		events_this_frame += 1
	
	# Process regular queue
	while event_queue.size() > 0 and events_this_frame < max_events_per_frame:
		var event = event_queue.pop_front()
		_dispatch_event(event)
		events_this_frame += 1
	
	processing_events = false

func _dispatch_event(event: Event) -> void:
	# Add to history
	event_history.append(event)
	if event_history.size() > event_history_size:
		event_history.pop_front()
	
	# Dispatch to subscribers
	if subscribers.has(event.type):
		for callback in subscribers[event.type]:
			if callback.is_valid():
				callback.call(event)
			else:
				# Clean up invalid callbacks
				subscribers[event.type].erase(callback)
	
	events_processed += 1

func get_event_history(event_type: EventType = -1, limit: int = 100) -> Array[Event]:
	if event_type == -1:
		return event_history.slice(-limit)
	
	var filtered: Array[Event] = []
	for event in event_history:
		if event.type == event_type:
			filtered.append(event)
			if filtered.size() >= limit:
				break
	return filtered

func clear_queue() -> void:
	event_queue.clear()
	immediate_queue.clear()

func get_stats() -> Dictionary:
	return {
		"events_processed": events_processed,
		"events_dropped": events_dropped,
		"queue_size": event_queue.size(),
		"immediate_queue_size": immediate_queue.size(),
		"subscribers": subscribers.size(),
		"history_size": event_history.size()
	}

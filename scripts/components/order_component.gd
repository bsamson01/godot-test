# OrderComponent.gd - Component for order data and execution
extends Component
class_name OrderComponent

# Use the unified Order class
var order: Order

# Additional component-specific data
@export var issued_by: String = ""  # Entity ID of issuer
@export var target_id: String = ""
@export var parameters: Dictionary = {}

func get_component_name() -> String:
	return "OrderComponent"

func _on_attached(_entity: Entity) -> void:
	# Create order if not already created
	if not order:
		order = Order.new()
		order.data = parameters
		order.target_id = target_id
		order.issued_tick = int(Time.get_ticks_msec() / 1000.0)
	
	# Subscribe to relevant events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.subscribe(EventBus.EventType.ORDER_ASSIGNED, _on_order_assigned)
		event_bus.subscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)

func _on_detached(_entity: Entity) -> void:
	# Unsubscribe from events
	if Engine.has_singleton("EventBus"):
		var event_bus = Engine.get_singleton("EventBus")
		event_bus.unsubscribe(EventBus.EventType.ORDER_ASSIGNED, _on_order_assigned)
		event_bus.unsubscribe(EventBus.EventType.ORDER_COMPLETED, _on_order_completed)

# Delegate to Order class
func get_total_time() -> float:
	return order.get_total_time()

func can_be_executed_by(faction_comp) -> bool:
	return order.can_be_executed_by(faction_comp)

func execute(executor_entity: Entity) -> bool:
	return order.execute(executor_entity)

func complete(executor_entity: Entity) -> Dictionary:
	return order.complete(executor_entity)

# Getters for compatibility
func get_order_type() -> Order.OrderType:
	return order.order_type

func get_status() -> Order.OrderStatus:
	return order.status

func get_priority() -> int:
	return order.priority

func get_travel_time() -> float:
	return order.travel_time

func get_work_time() -> float:
	return order.work_time

func get_return_time() -> float:
	return order.return_time

func get_required_funds() -> float:
	return order.required_funds

func get_required_supplies() -> float:
	return order.required_supplies

func get_success_chance() -> float:
	return order.success_chance

func get_failure_reason() -> String:
	return order.failure_reason

func validate() -> Validatable.ValidationResult:
	var result = Validatable.ValidationResult.new()
	
	if not order:
		result.add_error("Order is null")
		return result
	
	# Validate order properties
	Validatable.validate_positive(order.travel_time, "travel_time", result)
	Validatable.validate_positive(order.work_time, "work_time", result)
	Validatable.validate_positive(order.return_time, "return_time", result)
	Validatable.validate_in_range(order.priority, 0, 100, "priority", result)
	Validatable.validate_in_range(order.success_chance, 0, 1, "success_chance", result)
	
	return result

func get_display_name() -> String:
	return order.name()

func get_description() -> String:
	return order.name()  # Use the order's name as description

# Event handlers
func _on_order_assigned(event: EventBus.Event) -> void:
	if event.data.get("order_id") == entity.id:
		order.assigned_to = event.data.get("member_id", "")
		order.status = Order.OrderStatus.IN_PROGRESS

func _on_order_completed(event: EventBus.Event) -> void:
	if event.data.get("order_id") == entity.id:
		# Order completion is handled by the member component
		pass

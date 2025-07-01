# Entity.gd - Base class for all game entities with component support
extends Resource
class_name Entity

signal entity_created(entity: Entity)
signal entity_destroyed(entity: Entity)
signal component_added(entity: Entity, component: Component)
signal component_removed(entity: Entity, component: Component)

@export var id: String
@export var entity_type: String = ""
@export var created_at: int = 0
@export var is_active: bool = true

var components: Dictionary = {} # component_name -> Component
var _is_destroyed: bool = false

func _init():
	id = _generate_id()
	created_at = Time.get_ticks_msec()

func add_component(component: Component) -> void:
	if _is_destroyed:
		push_error("Cannot add component to destroyed entity: " + id)
		return
	
	var component_name = component.get_component_name()
	if components.has(component_name):
		push_warning("Component already exists: " + component_name)
		return
	
	components[component_name] = component
	component.entity = self
	component._on_attached(self)
	emit_signal("component_added", self, component)

func remove_component(component_name: String) -> void:
	if _is_destroyed:
		return
		
	if not components.has(component_name):
		return
	
	var component = components[component_name]
	component._on_detached(self)
	component.entity = null
	components.erase(component_name)
	emit_signal("component_removed", self, component)

func get_component(component_name: String) -> Component:
	return components.get(component_name, null)

func has_component(component_name: String) -> bool:
	return components.has(component_name)

func destroy() -> void:
	if _is_destroyed:
		return
	
	_is_destroyed = true
	is_active = false
	
	# Cleanup all components
	for component_name in components.keys():
		remove_component(component_name)
	
	emit_signal("entity_destroyed", self)

func _generate_id() -> String:
	return entity_type + "_" + str(Time.get_ticks_usec())

func is_destroyed() -> bool:
	return _is_destroyed
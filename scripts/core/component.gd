# Component.gd - Base class for all entity components
extends Resource
class_name Component

var entity: Entity = null
var is_enabled: bool = true

# Override in derived classes
func get_component_name() -> String:
	return "Component"

# Called when component is attached to an entity
func _on_attached(entity: Entity) -> void:
	pass

# Called when component is detached from an entity
func _on_detached(entity: Entity) -> void:
	pass

# Called every frame if component is enabled
func update(delta: float) -> void:
	pass

# Called for fixed timestep updates
func fixed_update(delta: float) -> void:
	pass

func set_enabled(enabled: bool) -> void:
	is_enabled = enabled

func get_entity() -> Entity:
	return entity
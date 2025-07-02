# EntityManager.gd - Manages all entities with proper lifecycle and cleanup
extends Node
class_name EntityManager

signal entity_registered(entity: Entity)
signal entity_unregistered(entity: Entity)

# Entity storage with multiple access patterns
var entities: Dictionary = {} # id -> Entity
var entities_by_type: Dictionary = {} # type -> Array[Entity]
var entities_by_component: Dictionary = {} # component_name -> Array[Entity]

# Object pooling
var entity_pools: Dictionary = {} # entity_type -> Array[Entity]
var max_pool_size: int = 50

# Cleanup tracking
var entities_to_destroy: Array[Entity] = []
var cleanup_interval: float = 5.0
var _cleanup_timer: float = 0.0

# Performance monitoring
var entity_count: int = 0
var max_entities: int = 10000

func _ready():
	set_process(true)

func _process(delta: float):
	_cleanup_timer += delta
	if _cleanup_timer >= cleanup_interval:
		_cleanup_timer = 0.0
		_perform_cleanup()

func register_entity(entity: Entity) -> void:
	if not entity or entity.is_destroyed():
		push_error("Cannot register null or destroyed entity")
		return
	
	if entities.has(entity.id):
		push_warning("Entity already registered: " + entity.id)
		return
	
	if entity_count >= max_entities:
		push_error("Maximum entity limit reached: " + str(max_entities))
		return
	
	# Add to main registry
	entities[entity.id] = entity
	entity_count += 1
	
	# Add to type registry
	if not entities_by_type.has(entity.entity_type):
		entities_by_type[entity.entity_type] = []
	entities_by_type[entity.entity_type].append(entity)
	
	# Connect to entity signals
	entity.entity_destroyed.connect(_on_entity_destroyed)
	entity.component_added.connect(_on_component_added)
	entity.component_removed.connect(_on_component_removed)
	
	# Register existing components
	for component_name in entity.components:
		_register_entity_component(entity, component_name)
	
	emit_signal("entity_registered", entity)

func unregister_entity(entity: Entity) -> void:
	if not entity or not entities.has(entity.id):
		return
	
	# Remove from registries
	entities.erase(entity.id)
	entity_count -= 1
	
	if entities_by_type.has(entity.entity_type):
		entities_by_type[entity.entity_type].erase(entity)
	
	# Remove from component registries
	for component_name in entity.components:
		_unregister_entity_component(entity, component_name)
	
	# Disconnect signals
	if entity.entity_destroyed.is_connected(_on_entity_destroyed):
		entity.entity_destroyed.disconnect(_on_entity_destroyed)
	if entity.component_added.is_connected(_on_component_added):
		entity.component_added.disconnect(_on_component_added)
	if entity.component_removed.is_connected(_on_component_removed):
		entity.component_removed.disconnect(_on_component_removed)
	
	emit_signal("entity_unregistered", entity)

func get_entity(id: String) -> Entity:
	return entities.get(id, null)

func get_entities_by_type(type: String) -> Array[Entity]:
	return entities_by_type.get(type, [])

func get_entities_with_component(component_name: String) -> Array[Entity]:
	return entities_by_component.get(component_name, [])

func get_entities_with_components(component_names: Array[String]) -> Array[Entity]:
	var result: Array[Entity] = []
	for entity in entities.values():
		var has_all = true
		for component_name in component_names:
			if not entity.has_component(component_name):
				has_all = false
				break
		if has_all:
			result.append(entity)
	return result

func mark_for_destruction(entity: Entity) -> void:
	if not entity or entity.is_destroyed():
		return
	entities_to_destroy.append(entity)

func create_entity(entity_type: String) -> Entity:
	# Try to get from pool first
	if entity_pools.has(entity_type) and entity_pools[entity_type].size() > 0:
		var entity = entity_pools[entity_type].pop_back()
		entity.is_active = true
		register_entity(entity)
		return entity
	
	# Create new entity
	var entity = Entity.new()
	entity.entity_type = entity_type
	register_entity(entity)
	return entity

func return_to_pool(entity: Entity) -> void:
	if not entity or entity.is_destroyed():
		return
	
	unregister_entity(entity)
	
	# Reset entity state
	entity.is_active = false
	for component_name in entity.components.keys():
		entity.remove_component(component_name)
	
	# Add to pool
	if not entity_pools.has(entity.entity_type):
		entity_pools[entity.entity_type] = []
	
	if entity_pools[entity.entity_type].size() < max_pool_size:
		entity_pools[entity.entity_type].append(entity)

func _perform_cleanup() -> void:
	# Destroy marked entities
	for entity in entities_to_destroy:
		if entity and not entity.is_destroyed():
			entity.destroy()
			unregister_entity(entity)
	entities_to_destroy.clear()
	
	# Clean up empty type arrays
	for type in entities_by_type.keys():
		if entities_by_type[type].is_empty():
			entities_by_type.erase(type)
	
	# Clean up empty component arrays
	for component in entities_by_component.keys():
		if entities_by_component[component].is_empty():
			entities_by_component.erase(component)

func _on_entity_destroyed(entity: Entity) -> void:
	unregister_entity(entity)

func _on_component_added(entity: Entity, component: Component) -> void:
	_register_entity_component(entity, component.get_component_name())

func _on_component_removed(entity: Entity, component: Component) -> void:
	_unregister_entity_component(entity, component.get_component_name())

func _register_entity_component(entity: Entity, component_name: String) -> void:
	if not entities_by_component.has(component_name):
		entities_by_component[component_name] = []
	if not entities_by_component[component_name].has(entity):
		entities_by_component[component_name].append(entity)

func _unregister_entity_component(entity: Entity, component_name: String) -> void:
	if entities_by_component.has(component_name):
		entities_by_component[component_name].erase(entity)

func get_stats() -> Dictionary:
	return {
		"total_entities": entity_count,
		"entities_by_type": entities_by_type.keys(),
		"pooled_entities": entity_pools.size(),
		"pending_destruction": entities_to_destroy.size()
	}

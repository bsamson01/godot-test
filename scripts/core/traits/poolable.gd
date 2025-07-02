# Poolable.gd - Trait for objects that can be pooled
extends RefCounted
class_name Poolable

# Interface methods that poolable objects should implement
static func reset_object(obj: Object) -> void:
	if obj.has_method("reset"):
		obj.reset()
	elif obj.has_method("_reset"):
		obj._reset()

static func prepare_for_pool(obj: Object) -> void:
	if obj.has_method("prepare_for_pool"):
		obj.prepare_for_pool()
	elif obj.has_method("_prepare_for_pool"):
		obj._prepare_for_pool()

static func activate_from_pool(obj: Object) -> void:
	if obj.has_method("activate_from_pool"):
		obj.activate_from_pool()
	elif obj.has_method("_activate_from_pool"):
		obj._activate_from_pool()

# Object pool implementation
class ObjectPool:
	var pool_type: String
	var objects: Array = []
	var max_size: int
	var create_func: Callable
	
	func _init(type: String, max_size: int, create_func: Callable):
		self.pool_type = type
		self.max_size = max_size
		self.create_func = create_func
	
	func get_object() -> Object:
		if objects.size() > 0:
			var obj = objects.pop_back()
			Poolable.activate_from_pool(obj)
			return obj
		else:
			return create_func.call()
	
	func return_object(obj: Object) -> void:
		if objects.size() < max_size:
			Poolable.prepare_for_pool(obj)
			Poolable.reset_object(obj)
			objects.append(obj)
		elif obj.has_method("queue_free"):
			obj.queue_free()
	
	func clear() -> void:
		for obj in objects:
			if obj.has_method("queue_free"):
				obj.queue_free()
		objects.clear()
	
	func get_stats() -> Dictionary:
		return {
			"type": pool_type,
			"active": max_size - objects.size(),
			"pooled": objects.size(),
			"max_size": max_size
		}

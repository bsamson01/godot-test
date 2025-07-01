# Identifiable.gd - Trait for entities that need unique identification
extends RefCounted
class_name Identifiable

# Static methods for ID generation and validation
static func generate_id(prefix: String = "") -> String:
	var timestamp = Time.get_ticks_usec()
	var random_part = randi() % 10000
	if prefix.is_empty():
		return "%d_%d" % [timestamp, random_part]
	return "%s_%d_%d" % [prefix, timestamp, random_part]

static func validate_id(id: String) -> bool:
	return id != null and not id.is_empty()

static func extract_prefix(id: String) -> String:
	var parts = id.split("_")
	if parts.size() >= 3:
		return parts[0]
	return ""

static func extract_timestamp(id: String) -> int:
	var parts = id.split("_")
	if parts.size() >= 2:
		return int(parts[parts.size() - 2])
	return 0
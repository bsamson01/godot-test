# Validatable.gd - Trait for data validation and integrity
extends RefCounted
class_name Validatable

# Validation result class
class ValidationResult:
	var is_valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	func add_error(message: String) -> void:
		errors.append(message)
		is_valid = false
	
	func add_warning(message: String) -> void:
		warnings.append(message)
	
	func merge(other: ValidationResult) -> void:
		is_valid = is_valid and other.is_valid
		errors.append_array(other.errors)
		warnings.append_array(other.warnings)
	
	func to_string() -> String:
		if is_valid:
			return "Valid"
		return "Invalid: " + ", ".join(errors)

# Common validation methods
static func validate_not_null(value, field_name: String, result: ValidationResult) -> void:
	if value == null:
		result.add_error("%s cannot be null" % field_name)

static func validate_not_empty(value: String, field_name: String, result: ValidationResult) -> void:
	if value == null or value.is_empty():
		result.add_error("%s cannot be empty" % field_name)

static func validate_positive(value: float, field_name: String, result: ValidationResult) -> void:
	if value < 0:
		result.add_error("%s must be positive (got %f)" % [field_name, value])

static func validate_in_range(value: float, min_val: float, max_val: float, field_name: String, result: ValidationResult) -> void:
	if value < min_val or value > max_val:
		result.add_error("%s must be between %f and %f (got %f)" % [field_name, min_val, max_val, value])

static func validate_reference_exists(id: String, getter: Callable, type_name: String, result: ValidationResult) -> void:
	if id.is_empty():
		return  # Empty reference is allowed
	
	var obj = getter.call(id)
	if obj == null:
		result.add_error("Referenced %s with id '%s' does not exist" % [type_name, id])

static func validate_array_references(ids: Array[String], getter: Callable, type_name: String, result: ValidationResult) -> void:
	for id in ids:
		validate_reference_exists(id, getter, type_name, result)

static func validate_unique_elements(array: Array, field_name: String, result: ValidationResult) -> void:
	var seen = {}
	for element in array:
		if seen.has(element):
			result.add_error("%s contains duplicate element: %s" % [field_name, str(element)])
		seen[element] = true

# Entity validation helper
static func validate_entity(entity: Entity) -> ValidationResult:
	var result = ValidationResult.new()
	
	validate_not_empty(entity.id, "entity.id", result)
	validate_not_empty(entity.entity_type, "entity.entity_type", result)
	
	if entity.is_destroyed() and entity.is_active:
		result.add_error("Destroyed entity cannot be active")
	
	return result

# Validate object method exists and is callable
static func validate_interface(obj: Object, method_names: Array[String]) -> ValidationResult:
	var result = ValidationResult.new()
	
	for method_name in method_names:
		if not obj.has_method(method_name):
			result.add_error("Object %s missing required method: %s" % [obj.get_class(), method_name])
	
	return result
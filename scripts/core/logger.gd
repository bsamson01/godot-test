# Logger.gd - Comprehensive logging system
extends Node
class_name Logger

enum LogLevel {
	DEBUG = 0,
	INFO = 1,
	WARNING = 2,
	ERROR = 3,
	CRITICAL = 4
}

# Configuration
var current_log_level: LogLevel = LogLevel.INFO
var max_log_entries: int = 10000
var enable_file_logging: bool = false
var log_file_path: String = "user://game_log.txt"

# Log storage
var log_entries: Array[Dictionary] = []
var log_file: FileAccess

# Performance tracking
var log_counts: Dictionary = {
	LogLevel.DEBUG: 0,
	LogLevel.INFO: 0,
	LogLevel.WARNING: 0,
	LogLevel.ERROR: 0,
	LogLevel.CRITICAL: 0
}

# Singleton instance
static var instance: Logger

func _init():
	if instance == null:
		instance = self
		if enable_file_logging:
			_open_log_file()

func _ready():
	set_process(false)  # We don't need _process

func _exit_tree():
	if log_file:
		log_file.close()

static func debug(message: String, category: String = "General", data: Dictionary = {}) -> void:
	if instance:
		instance._log(LogLevel.DEBUG, message, category, data)

static func info(message: String, category: String = "General", data: Dictionary = {}) -> void:
	if instance:
		instance._log(LogLevel.INFO, message, category, data)

static func warning(message: String, category: String = "General", data: Dictionary = {}) -> void:
	if instance:
		instance._log(LogLevel.WARNING, message, category, data)

static func error(message: String, category: String = "General", data: Dictionary = {}) -> void:
	if instance:
		instance._log(LogLevel.ERROR, message, category, data)

static func critical(message: String, category: String = "General", data: Dictionary = {}) -> void:
	if instance:
		instance._log(LogLevel.CRITICAL, message, category, data)

func _log(level: LogLevel, message: String, category: String, data: Dictionary) -> void:
	if level < current_log_level:
		return
	
	var entry = {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"level": level,
		"category": category,
		"message": message,
		"data": data,
		"stack_trace": get_stack() if level >= LogLevel.ERROR else []
	}
	
	# Add to memory log
	log_entries.append(entry)
	if log_entries.size() > max_log_entries:
		log_entries.pop_front()
	
	# Update counts
	log_counts[level] += 1
	
	# Format and output
	var formatted = _format_log_entry(entry)
	
	# Console output
	match level:
		LogLevel.DEBUG:
			print(formatted)
		LogLevel.INFO:
			print(formatted)
		LogLevel.WARNING:
			push_warning(formatted)
		LogLevel.ERROR:
			push_error(formatted)
		LogLevel.CRITICAL:
			push_error("[CRITICAL] " + formatted)
	
	# File output
	if enable_file_logging and log_file:
		log_file.store_line(formatted)
		log_file.flush()

func _format_log_entry(entry: Dictionary) -> String:
	var level_names = {
		LogLevel.DEBUG: "DEBUG",
		LogLevel.INFO: "INFO",
		LogLevel.WARNING: "WARN",
		LogLevel.ERROR: "ERROR",
		LogLevel.CRITICAL: "CRIT"
	}
	
	var timestamp = Time.get_datetime_string_from_system()
	var level_str = level_names.get(entry.level, "UNKNOWN")
	var formatted = "[%s] [%s] [%s] %s" % [timestamp, level_str, entry.category, entry.message]
	
	if not entry.data.is_empty():
		formatted += " | Data: " + JSON.stringify(entry.data)
	
	return formatted

func _open_log_file() -> void:
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if log_file == null:
		push_error("Failed to open log file: " + log_file_path)
		enable_file_logging = false

func set_log_level(level: LogLevel) -> void:
	current_log_level = level

func get_logs(level: LogLevel = -1, category: String = "", limit: int = 100) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	
	for i in range(log_entries.size() - 1, -1, -1):
		var entry = log_entries[i]
		
		if level != -1 and entry.level != level:
			continue
		
		if not category.is_empty() and entry.category != category:
			continue
		
		filtered.append(entry)
		
		if filtered.size() >= limit:
			break
	
	return filtered

func get_error_summary() -> Dictionary:
	var errors = get_logs(LogLevel.ERROR, "", 50)
	var critical = get_logs(LogLevel.CRITICAL, "", 50)
	
	var summary = {
		"total_errors": log_counts[LogLevel.ERROR],
		"total_critical": log_counts[LogLevel.CRITICAL],
		"recent_errors": errors,
		"recent_critical": critical,
		"error_categories": {}
	}
	
	# Count errors by category
	for entry in errors + critical:
		var cat = entry.category
		if not summary.error_categories.has(cat):
			summary.error_categories[cat] = 0
		summary.error_categories[cat] += 1
	
	return summary

func clear_logs() -> void:
	log_entries.clear()
	for level in log_counts:
		log_counts[level] = 0

# Convenience function for logging exceptions
static func log_exception(exception: String, category: String = "Exception") -> void:
	error(exception, category, {"stack": get_stack()})

# Performance logging helpers
static func start_timer(operation: String) -> int:
	var start_time = Time.get_ticks_usec()
	debug("Starting operation: " + operation, "Performance", {"start_time": start_time})
	return start_time

static func end_timer(operation: String, start_time: int) -> void:
	var elapsed = Time.get_ticks_usec() - start_time
	var elapsed_ms = elapsed / 1000.0
	info("Operation completed: " + operation, "Performance", {
		"elapsed_us": elapsed,
		"elapsed_ms": elapsed_ms
	})
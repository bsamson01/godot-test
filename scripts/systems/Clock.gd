extends Node
class_name Clock

signal tick(time_data: Dictionary)

@export var ticks_per_day: int = 24
@export var tick_interval: float = 1.0  # seconds between ticks

var current_tick: int = 0
var is_running: bool = false
var time_of_day: String = "Day"

func start():
	current_tick = 0
	is_running = true
	_call_tick()

func stop():
	is_running = false

func _call_tick():
	if not is_running:
		return

	# Advance tick
	current_tick += 1

	# Determine time of day
	var tick_in_day = current_tick % ticks_per_day
	if tick_in_day < ticks_per_day * 0.25 or tick_in_day > ticks_per_day * 0.85:
		time_of_day = "Night"
	else:
		time_of_day = "Day"

	# Emit tick signal
	var time_data = {
		"tick": current_tick,
		"tick_in_day": tick_in_day,
		"time_of_day": time_of_day
	}
	emit_signal("tick", time_data)

	# Schedule next tick
	await get_tree().create_timer(tick_interval).timeout
	_call_tick()

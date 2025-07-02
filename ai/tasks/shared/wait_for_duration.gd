extends BTAction

@export var duration: float = 1.0
@export var random_variance: float = 0.0

var _wait_timer: float = 0.0
var _target_duration: float = 0.0

func _enter():
	_wait_timer = 0.0
	_target_duration = duration
	if random_variance > 0:
		_target_duration += randf_range(-random_variance, random_variance)

func _tick(delta: float) -> Status:
	_wait_timer += delta
	
	if _wait_timer >= _target_duration:
		return SUCCESS
		
	return RUNNING

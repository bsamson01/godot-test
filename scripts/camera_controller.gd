extends Camera3D
class_name CameraController

# Camera movement settings
@export var movement_speed: float = 10.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 50.0

# Internal variables
var current_zoom: float = 15.0
var target_position: Vector3 = Vector3.ZERO
var is_panning: bool = false
var last_mouse_position: Vector2

# Input actions
var move_forward: String = "camera_forward"
var move_backward: String = "camera_backward"
var move_left: String = "camera_left"
var move_right: String = "camera_right"
var zoom_in: String = "camera_zoom_in"
var zoom_out: String = "camera_zoom_out"

func _ready():
	# Set initial camera position - locked top-down view
	global_position = Vector3(0, 20, 0)  # High above the ground
	rotation_degrees = Vector3(-90, 0, 0)  # Looking straight down
	target_position = Vector3.ZERO
	_update_camera_transform()

func _input(event):
	# Handle mouse panning (right mouse button)
	if event is InputEventMouseMotion and is_panning:
		var mouse_delta = event.relative
		# Convert mouse movement to world movement
		var pan_speed = current_zoom * 0.01
		target_position.x -= mouse_delta.x * pan_speed
		target_position.z += mouse_delta.y * pan_speed
		_update_camera_transform()
	
	# Handle mouse button for panning
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_panning = event.pressed
			if event.pressed:
				last_mouse_position = get_viewport().get_mouse_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()

func _process(delta):
	# Handle keyboard movement
	_handle_keyboard_movement(delta)
	
	# Handle zoom with keyboard
	if Input.is_action_pressed(zoom_in):
		_zoom_in()
	if Input.is_action_pressed(zoom_out):
		_zoom_out()

func _handle_keyboard_movement(delta):
	var movement = Vector3.ZERO
	
	# Get movement input (only horizontal movement for top-down view)
	if Input.is_action_pressed(move_forward):
		movement += Vector3(0, 0, -1)  # Move north
	if Input.is_action_pressed(move_backward):
		movement += Vector3(0, 0, 1)   # Move south
	if Input.is_action_pressed(move_left):
		movement += Vector3(-1, 0, 0)  # Move west
	if Input.is_action_pressed(move_right):
		movement += Vector3(1, 0, 0)   # Move east
	
	# Apply movement
	if movement.length() > 0:
		movement = movement.normalized() * movement_speed * delta
		target_position += movement
		_update_camera_transform()

func _zoom_in():
	current_zoom = max(current_zoom - zoom_speed, min_zoom)
	_update_camera_transform()

func _zoom_out():
	current_zoom = min(current_zoom + zoom_speed, max_zoom)
	_update_camera_transform()

func _update_camera_transform():
	# For top-down view, camera is always directly above the target position
	global_position = target_position + Vector3(0, current_zoom, 0)
	# Keep camera looking straight down
	rotation_degrees = Vector3(-90, 0, 0)

func set_target_position(pos: Vector3):
	target_position = pos
	_update_camera_transform()

func get_target_position() -> Vector3:
	return target_position

func set_zoom(zoom: float):
	current_zoom = clamp(zoom, min_zoom, max_zoom)
	_update_camera_transform()

func get_zoom() -> float:
	return current_zoom

func reset_camera():
	"""Reset camera to default position"""
	target_position = Vector3.ZERO
	current_zoom = 15.0
	_update_camera_transform()

func focus_on_position(pos: Vector3, zoom: float = 10.0):
	"""Focus camera on a specific position"""
	target_position = pos
	current_zoom = clamp(zoom, min_zoom, max_zoom)
	_update_camera_transform()

# Public methods for external control
func move_camera(direction: Vector3, speed_multiplier: float = 1.0):
	"""Move camera in a specific direction"""
	target_position += direction * movement_speed * speed_multiplier * get_process_delta_time()
	_update_camera_transform()

func pan_camera(delta_x: float, delta_z: float):
	"""Pan camera by specific amounts"""
	target_position.x += delta_x
	target_position.z += delta_z
	_update_camera_transform()

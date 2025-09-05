extends Control
class_name CameraHelpUI

@onready var help_label: Label
var show_help: bool = true

func _ready():
	# Create help label
	help_label = Label.new()
	help_label.text = """Top-Down Camera Controls:
WASD / Arrow Keys - Pan camera
Mouse Wheel - Zoom in/out
Right Mouse + Drag - Pan camera
Tab - Toggle this help panel

Game Info:
2 Factions: Red Vipers vs Blue Shadows
3 Members per faction with collision avoidance
Space - Give characters new targets (test scene)"""
	
	help_label.position = Vector2(10, 10)
	help_label.add_theme_color_override("font_color", Color.WHITE)
	help_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	help_label.add_theme_constant_override("shadow_offset_x", 1)
	help_label.add_theme_constant_override("shadow_offset_y", 1)
	
	add_child(help_label)
	
	# Make it semi-transparent
	modulate = Color(1, 1, 1, 0.8)

func _input(event):
	if event.is_action_pressed("ui_accept") or event.keycode == KEY_TAB:
		show_help = !show_help
		visible = show_help

func toggle_help():
	show_help = !show_help
	visible = show_help

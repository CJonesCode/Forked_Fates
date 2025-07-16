extends Control

## Main menu controller
## Handles navigation to different game modes and settings

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $VBoxContainer/TitleLabel

func _ready() -> void:
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Set title
	title_label.text = "FORKED FATES"
	
	print("Main menu loaded")

func _on_start_button_pressed() -> void:
	print("Starting game...")
	# Transition to map view
	EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")
	GameManager.change_state(GameManager.GameState.MAP_VIEW)

func _on_quit_button_pressed() -> void:
	print("Quitting game...")
	get_tree().quit() 
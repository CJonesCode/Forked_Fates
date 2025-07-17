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
	
	Logger.system("Main menu loaded", "MainMenu")

func _on_start_button_pressed() -> void:
	Logger.game_flow("Starting game", "MainMenu")
	# Transition to map view
	EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")
	GameManager.change_state(GameManager.GameState.MAP_VIEW)

func _on_quit_button_pressed() -> void:
	Logger.system("Quitting game", "MainMenu")
	get_tree().quit() 
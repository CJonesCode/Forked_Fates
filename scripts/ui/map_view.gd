extends Control

## Map view controller
## Displays the current map and handles node selection

@onready var map_container: Control = $MapContainer
@onready var back_button: Button = $UIContainer/BackButton
@onready var test_minigame_button: Button = $UIContainer/TestMinigameButton

func _ready() -> void:
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	test_minigame_button.pressed.connect(_on_test_minigame_button_pressed)
	
	# TODO: Load and display actual map
	_setup_placeholder_ui()
	
	print("Map view loaded")

func _setup_placeholder_ui() -> void:
	# Temporary placeholder until map system is implemented
	var placeholder_label = Label.new()
	placeholder_label.text = "MAP VIEW\n(Map system coming soon...)\n\nFor now, use Test Minigame button"
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_container.add_child(placeholder_label)

func _on_back_button_pressed() -> void:
	print("Returning to main menu...")
	EventBus.request_scene_transition("res://scenes/ui/main_menu.tscn")
	GameManager.change_state(GameManager.GameState.MENU)

func _on_test_minigame_button_pressed() -> void:
	print("Starting test minigame...")
	GameManager.start_minigame("sudden_death") 
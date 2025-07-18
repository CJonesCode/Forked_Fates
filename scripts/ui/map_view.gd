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
	
	Logger.system("Map view loaded", "MapView")

func _setup_placeholder_ui() -> void:
	# Temporary placeholder until map system is implemented using UIFactory
	var label_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
	label_config.element_name = "PlaceholderLabel"
	label_config.text = "MAP VIEW\n(Map system coming soon...)\n\nFor now, use Test Minigame button"
	label_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_config.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var placeholder_label: Node = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, label_config)
	if placeholder_label and placeholder_label is Control:
		map_container.add_child(placeholder_label as Control)
	else:
		Logger.error("Failed to create placeholder label through UIFactory", "MapView")

func _on_back_button_pressed() -> void:
	Logger.game_flow("Returning to main menu", "MapView")
	EventBus.request_scene_transition("res://scenes/ui/main_menu.tscn")
	GameManager.transition_to_menu()

func _on_test_minigame_button_pressed() -> void:
	Logger.game_flow("Starting test minigame", "MapView")
	GameManager.start_minigame("sudden_death") 
extends Control

## Main menu controller
## Handles navigation to different game modes and settings

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var multiplayer_button: Button = $VBoxContainer/MultiplayerButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $VBoxContainer/TitleLabel

func _ready() -> void:
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Set title
	title_label.text = "FORKED FATES"
	
	Logger.system("Main menu loaded", "MainMenu")

func _on_start_button_pressed() -> void:
	Logger.game_flow("Starting local game", "MainMenu")
	
	# Use GameManager's proper local initialization
	GameManager.start_local()
	
	# Transition to map view (now handled by GameManager)
	EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")

func _on_multiplayer_button_pressed() -> void:
	Logger.game_flow("Opening direct connect interface", "MainMenu")
	
	# Use integrated UIFactory + UIManager approach
	var direct_connect_scene: PackedScene = UIFactory.get_screen_scene("direct_connect")
	if direct_connect_scene:
		var screen: Control = await UIManager.push_screen(direct_connect_scene, "direct_connect")
		if not screen:
			Logger.error("Failed to push direct connect screen", "MainMenu")
	else:
		Logger.error("Failed to load direct connect screen scene", "MainMenu")

func _on_quit_button_pressed() -> void:
	Logger.system("Quitting game", "MainMenu")
	get_tree().quit() 
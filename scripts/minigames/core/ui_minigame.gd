class_name UIMinigame
extends BaseMinigame

## Base class for UI-based minigames
## Pure UI interaction without physics systems
## Example: Simon Says, memory games, trivia, button mashers

# UI-specific configuration
@export var show_timer: bool = true
@export var allow_pause: bool = true
@export var ui_theme: Theme = null

# UI components
@onready var game_ui: Control = $GameUI
@onready var player_ui_container: Container = $GameUI/PlayerUIContainer
@onready var game_timer_label: Label = $GameUI/TimerLabel
@onready var instruction_label: Label = $GameUI/InstructionLabel

# UI minigame signals
signal ui_input_received(player_id: int, input_data: Dictionary)
signal timer_updated(time_remaining: float)
signal instruction_changed(new_instruction: String)

# Game state
var game_timer: float = 0.0
var max_time: float = 60.0
var player_ui_components: Dictionary = {}  # player_id -> UI component

func _ready() -> void:
	super()
	minigame_name = "UI Minigame"
	minigame_type = "ui"
	minigame_description = "Pure UI interaction without physics systems"
	tags = ["ui", "interactive"]
	
	# Default tutorial content for UI minigames
	tutorial_objective = "Follow the instructions and react quickly!"
	tutorial_controls = {
		"Interact": "Mouse Click / Enter",
		"Navigate": "Arrow Keys / Tab"
	}
	tutorial_tips = [
		"Pay attention to visual cues",
		"React quickly when prompted",
		"Read instructions carefully"
	]

## Initialize UI minigame
func _on_initialize(minigame_context: MinigameContext) -> void:
	Logger.system("Initializing UIMinigame", "UIMinigame")
	
	# Disable physics systems we don't need
	context.disable_system("player_spawner")
	context.disable_system("item_spawner")
	context.disable_system("physics")
	
	# Setup UI theme
	if ui_theme:
		game_ui.theme = ui_theme
	
	# Create UI components for each player
	_setup_player_ui_components()
	
	# Setup timer display
	if show_timer and game_timer_label:
		game_timer_label.visible = true
		max_time = context.get_config("max_time", 60.0)
		game_timer = max_time
	
	# Hook for subclass UI setup
	_on_ui_initialize()

## Start UI minigame
func _on_start() -> void:
	Logger.game_flow("Starting UIMinigame", "UIMinigame")
	
	# Start timer if enabled
	if show_timer:
		_start_timer()
	
	# Enable UI interactions
	_enable_ui_interactions()
	
	# Show initial instructions
	_show_initial_instructions()
	
	# Hook for subclass start logic
	_on_ui_start()

## End UI minigame
func _on_end(result: MinigameResult) -> void:
	Logger.game_flow("Ending UIMinigame", "UIMinigame")
	
	# Disable UI interactions
	_disable_ui_interactions()
	
	# Cleanup UI components
	_cleanup_ui_components()
	
	# Hook for subclass cleanup
	_on_ui_end(result)

## Process timer and UI updates
func _process(delta: float) -> void:
	if not is_active or is_paused:
		return
	
	# Update timer
	if show_timer and game_timer > 0:
		game_timer -= delta
		_update_timer_display()
		timer_updated.emit(game_timer)
		
		# Check for timeout
		if game_timer <= 0:
			_on_timeout()

## Setup UI components for each player
func _setup_player_ui_components() -> void:
	if not player_ui_container:
		Logger.warning("No PlayerUIContainer found for UI components", "UIMinigame")
		return
	
	for player_data in context.participating_players:
		var player_ui: Control = _create_player_ui_component(player_data)
		if player_ui:
			player_ui_container.add_child(player_ui)
			player_ui_components[player_data.player_id] = player_ui
			Logger.system("Created UI component for player: " + player_data.player_name, "UIMinigame")

## Create UI component for a specific player (override in subclasses)
func _create_player_ui_component(player_data: PlayerData) -> Control:
	# Default implementation creates a simple label using UIFactory
	var label_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
	label_config.element_name = "Player" + str(player_data.player_id) + "Label"
	label_config.text = player_data.player_name
	
	var player_label: Node = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, label_config)
	if player_label and player_label is Control:
		return player_label as Control
	else:
		Logger.error("Failed to create player UI component through UIFactory", "UIMinigame")
		return null

## Enable UI interactions
func _enable_ui_interactions() -> void:
	for player_id in player_ui_components.keys():
		var ui_component: Control = player_ui_components[player_id]
		if ui_component.has_method("enable_interaction"):
			ui_component.enable_interaction()

## Disable UI interactions
func _disable_ui_interactions() -> void:
	for player_id in player_ui_components.keys():
		var ui_component: Control = player_ui_components[player_id]
		if ui_component.has_method("disable_interaction"):
			ui_component.disable_interaction()

## Show initial game instructions
func _show_initial_instructions() -> void:
	if instruction_label:
		var instructions: String = _get_initial_instructions()
		instruction_label.text = instructions
		instruction_changed.emit(instructions)

## Update instruction text
func update_instructions(new_instruction: String) -> void:
	if instruction_label:
		instruction_label.text = new_instruction
		instruction_changed.emit(new_instruction)

## Start the game timer
func _start_timer() -> void:
	if game_timer_label:
		game_timer_label.visible = true

## Update timer display
func _update_timer_display() -> void:
	if game_timer_label:
		var minutes: int = int(game_timer) / 60
		var seconds: int = int(game_timer) % 60
		game_timer_label.text = "%02d:%02d" % [minutes, seconds]

## Handle timeout condition
func _on_timeout() -> void:
	Logger.game_flow("UIMinigame timed out", "UIMinigame")
	
	var result: MinigameResult = MinigameResult.create_timeout_result(
		context.get_player_ids(),
		minigame_name,
		0.0
	)
	
	# Hook for subclass timeout handling
	_on_ui_timeout(result)
	
	end_minigame(result)

## Handle UI input from players
func handle_player_input(player_id: int, input_data: Dictionary) -> void:
	if not is_active or is_paused:
		return
	
	Logger.system("UI input from player " + str(player_id) + ": " + str(input_data), "UIMinigame")
	ui_input_received.emit(player_id, input_data)
	
	# Hook for subclass input handling
	_on_ui_input(player_id, input_data)

## Get player UI component
func get_player_ui(player_id: int) -> Control:
	return player_ui_components.get(player_id, null)

## Update player score display (if applicable)
func update_player_score(player_id: int, score: int) -> void:
	var ui_component: Control = get_player_ui(player_id)
	if ui_component and ui_component.has_method("update_score"):
		ui_component.update_score(score)

## Cleanup UI components
func _cleanup_ui_components() -> void:
	for ui_component in player_ui_components.values():
		if ui_component and is_instance_valid(ui_component):
			ui_component.queue_free()
	player_ui_components.clear()

## Pause UI-specific elements
func _on_pause() -> void:
	super()
	_disable_ui_interactions()

## Resume UI-specific elements
func _on_resume() -> void:
	super()
	_enable_ui_interactions()

# Virtual methods for subclasses to implement UI-specific logic

## Called during UI initialization after basic setup
func _on_ui_initialize() -> void:
	pass

## Called when UI minigame starts
func _on_ui_start() -> void:
	pass

## Called when UI minigame ends
func _on_ui_end(result: MinigameResult) -> void:
	pass

## Called when timer times out
func _on_ui_timeout(result: MinigameResult) -> void:
	pass

## Called when UI input is received from a player
func _on_ui_input(player_id: int, input_data: Dictionary) -> void:
	pass

## Get initial instructions text (override in subclasses)
func _get_initial_instructions() -> String:
	return "UI Minigame - Follow the instructions!" 
class_name InputComponent
extends BaseComponent

## Input processing and mapping component
## Handles input configuration and translates input to game actions

# Input signals
signal movement_input_changed(movement: Vector2)
signal jump_input_pressed()
signal use_input_pressed()
signal drop_input_pressed()

# Input configuration
@export var player_id: int = 0
@export var input_config: InputConfig

# Input state
var current_movement: Vector2 = Vector2.ZERO
var input_enabled: bool = true

# Cached input states for better performance
var _move_left_pressed: bool = false
var _move_right_pressed: bool = false

func _initialize_component() -> void:
	# Try to get player_id from parent's player_data if available
	if player.player_data and player_id == 0:
		player_id = player.player_data.player_id
		Logger.debug("InputComponent inherited player_id " + str(player_id) + " from BasePlayer", "InputComponent")
	
	# Initialize input config if not set
	if not input_config:
		_setup_default_input_config()
	
	# Validate input configuration
	_validate_input_config()
	
	Logger.system("Input component initialized for player " + str(player_id) + " using " + input_config.get_device_name(), "InputComponent")

func _process(_delta: float) -> void:
	if not input_enabled or not input_config:
		return
	
	_gather_input()
	_process_input_actions()

## Gather input from the input system
func _gather_input() -> void:
	# Reset movement vector
	var new_movement: Vector2 = Vector2.ZERO
	
	# Cache input states for performance (with safety checks)
	_move_left_pressed = InputMap.has_action(input_config.move_left_action) and Input.is_action_pressed(input_config.move_left_action)
	_move_right_pressed = InputMap.has_action(input_config.move_right_action) and Input.is_action_pressed(input_config.move_right_action)
	
	# Gather movement input
	if _move_left_pressed:
		new_movement.x -= 1.0
	if _move_right_pressed:
		new_movement.x += 1.0
	
	# Normalize input vector
	if new_movement.length() > 1.0:
		new_movement = new_movement.normalized()
	
	# Emit movement change if different
	if new_movement != current_movement:
		current_movement = new_movement
		movement_input_changed.emit(current_movement)

## Process button press actions
func _process_input_actions() -> void:
	# Handle jump input
	if InputMap.has_action(input_config.jump_action) and Input.is_action_just_pressed(input_config.jump_action):
		jump_input_pressed.emit()
	
	# Handle use input
	if InputMap.has_action(input_config.use_action) and Input.is_action_just_pressed(input_config.use_action):
		use_input_pressed.emit()
	
	# Handle drop input
	if InputMap.has_action(input_config.drop_action) and Input.is_action_just_pressed(input_config.drop_action):
		drop_input_pressed.emit()

## Setup input configuration for specific player
func setup_for_player(p_id: int, config: InputConfig = null) -> void:
	player_id = p_id
	
	if config:
		input_config = config
	else:
		_setup_default_input_config()
	
	_validate_input_config()
	
	Logger.system("Player " + str(player_id) + " input configured with " + input_config.get_device_name(), "InputComponent")
	Logger.debug("Actions: " + input_config.move_left_action + ", " + input_config.move_right_action + ", " + input_config.jump_action + ", " + input_config.use_action + ", " + input_config.drop_action, "InputComponent")

## Setup default input configuration based on player ID
func _setup_default_input_config() -> void:
	var default_configs: Array[InputConfig] = InputConfig.create_default_configs()
	
	if player_id >= 0 and player_id < default_configs.size():
		input_config = default_configs[player_id]
	else:
		# Fallback to first config if player_id is out of range
		input_config = default_configs[0]
		Logger.warning("Player ID " + str(player_id) + " out of range, using default config", "InputComponent")

## Validate that all required input actions exist in the Input Map
func _validate_input_config() -> void:
	if not input_config:
		Logger.error("No input config for player " + str(player_id), "InputComponent")
		return
	
	var missing_actions: Array[String] = []
	
	# Check required actions
	if not InputMap.has_action(input_config.move_left_action):
		missing_actions.append(input_config.move_left_action)
	if not InputMap.has_action(input_config.move_right_action):
		missing_actions.append(input_config.move_right_action)
	if not InputMap.has_action(input_config.jump_action):
		missing_actions.append(input_config.jump_action)
	if not InputMap.has_action(input_config.use_action):
		missing_actions.append(input_config.use_action)
	if not InputMap.has_action(input_config.drop_action):
		missing_actions.append(input_config.drop_action)
	
	# Report missing actions
	if missing_actions.size() > 0:
		Logger.warning("Player " + str(player_id) + " missing input actions: " + str(missing_actions), "InputComponent")
		Logger.warning("These inputs will not work until added to Input Map", "InputComponent")
	else:
		Logger.debug("Player " + str(player_id) + " all input actions found", "InputComponent")

## Enable or disable input processing
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		# Clear current movement when disabled
		current_movement = Vector2.ZERO
		movement_input_changed.emit(current_movement)

## Check if input is currently enabled
func is_input_enabled() -> bool:
	return input_enabled

## Get current movement input
func get_movement_input() -> Vector2:
	return current_movement

## Check if a specific action is currently pressed
func is_action_pressed(action_name: String) -> bool:
	if not input_enabled or not InputMap.has_action(action_name):
		return false
	return Input.is_action_pressed(action_name)

## Check if a specific action was just pressed
func is_action_just_pressed(action_name: String) -> bool:
	if not input_enabled or not InputMap.has_action(action_name):
		return false
	return Input.is_action_just_pressed(action_name)

## Get input strength for analog inputs (0.0 to 1.0)
func get_action_strength(action_name: String) -> float:
	if not input_enabled or not InputMap.has_action(action_name):
		return 0.0
	return Input.get_action_strength(action_name)

## Override input programmatically (for AI or testing)
func set_virtual_input(movement: Vector2, jump: bool = false, use: bool = false, drop: bool = false) -> void:
	# Emit movement change
	if movement != current_movement:
		current_movement = movement
		movement_input_changed.emit(current_movement)
	
	# Emit action signals
	if jump:
		jump_input_pressed.emit()
	if use:
		use_input_pressed.emit()
	if drop:
		drop_input_pressed.emit() 
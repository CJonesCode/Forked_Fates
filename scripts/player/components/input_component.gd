class_name InputComponent
extends BaseComponent

## Input processing and mapping component
## Handles input configuration and translates input to game actions
## Momentum-based weapon controls

# Input signals - momentum-based throwing
signal movement_input_changed(movement: Vector2)
signal jump_input_pressed()
signal fire_input_pressed()       # Fire held weapon
signal throw_input_pressed()      # Throw/drop (momentum-based force)
signal pickup_input_pressed()     # Pick up nearby weapon

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
	
	# Check left movement
	if InputMap.has_action(input_config.move_left_action) and Input.is_action_pressed(input_config.move_left_action):
		new_movement.x -= 1.0
	
	# Check right movement
	if InputMap.has_action(input_config.move_right_action) and Input.is_action_pressed(input_config.move_right_action):
		new_movement.x += 1.0
	
	# Normalize input vector
	if new_movement.length() > 1.0:
		new_movement = new_movement.normalized()
	
	# Emit movement change if different
	if new_movement != current_movement:
		current_movement = new_movement
		movement_input_changed.emit(current_movement)

## Process button press actions - momentum-based throwing
func _process_input_actions() -> void:
	# Handle jump input
	if InputMap.has_action(input_config.jump_action) and Input.is_action_just_pressed(input_config.jump_action):
		jump_input_pressed.emit()
	
	# Handle fire input (primary action - fire held weapon)
	if InputMap.has_action(input_config.fire_action) and Input.is_action_just_pressed(input_config.fire_action):
		fire_input_pressed.emit()
	
	# Handle throw input (momentum determines force)
	if InputMap.has_action(input_config.throw_action) and Input.is_action_just_pressed(input_config.throw_action):
		throw_input_pressed.emit()
	
	# Handle pickup input (acquisition action - pick up weapon)
	if InputMap.has_action(input_config.pickup_action) and Input.is_action_just_pressed(input_config.pickup_action):
		pickup_input_pressed.emit()

## Setup input configuration for specific player
func setup_for_player(p_id: int, config: InputConfig = null) -> void:
	player_id = p_id
	
	if config:
		input_config = config
	else:
		_setup_default_input_config()
	
	_validate_input_config()
	
	Logger.system("Player " + str(player_id) + " input configured with " + input_config.get_device_name(), "InputComponent")
	Logger.debug("Weapon Actions: fire=" + input_config.fire_action + ", throw=" + input_config.throw_action + ", pickup=" + input_config.pickup_action, "InputComponent")
	Logger.debug("Movement Actions: left=" + input_config.move_left_action + ", right=" + input_config.move_right_action + ", jump=" + input_config.jump_action, "InputComponent")

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
	
	# Check required movement actions
	if not InputMap.has_action(input_config.move_left_action):
		missing_actions.append(input_config.move_left_action)
	if not InputMap.has_action(input_config.move_right_action):
		missing_actions.append(input_config.move_right_action)
	if not InputMap.has_action(input_config.jump_action):
		missing_actions.append(input_config.jump_action)
	
	# Check momentum-based weapon actions
	if not InputMap.has_action(input_config.fire_action):
		missing_actions.append(input_config.fire_action)
	if not InputMap.has_action(input_config.throw_action):
		missing_actions.append(input_config.throw_action)
	if not InputMap.has_action(input_config.pickup_action):
		missing_actions.append(input_config.pickup_action)
	
	# If missing critical actions, log warnings
	if missing_actions.size() > 0:
		Logger.warning("Missing input actions for player " + str(player_id) + ": " + str(missing_actions), "InputComponent")
	else:
		Logger.debug("All weapon input actions validated for player " + str(player_id), "InputComponent")

## Enable/disable input processing
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		current_movement = Vector2.ZERO
		movement_input_changed.emit(current_movement)

## Check if specific action is pressed
func is_action_pressed(action_name: String) -> bool:
	if not input_enabled or not InputMap.has_action(action_name):
		return false
	return Input.is_action_pressed(action_name)

## Check if specific action was just pressed
func is_action_just_pressed(action_name: String) -> bool:
	if not input_enabled or not InputMap.has_action(action_name):
		return false
	return Input.is_action_just_pressed(action_name)

## Check if specific action was just released
func is_action_just_released(action_name: String) -> bool:
	if not input_enabled or not InputMap.has_action(action_name):
		return false
	return Input.is_action_just_released(action_name)

## Get current input state summary
func get_input_state() -> Dictionary:
	return {
		"movement": current_movement,
		"input_enabled": input_enabled,
		"player_id": player_id,
		"device": input_config.get_device_name() if input_config else "None"
	} 
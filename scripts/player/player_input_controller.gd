extends Node

## Player input controller
## Handles input using flexible InputConfig system and passes it to the BasePlayer

@export var player_id: int = 0
@export var input_config: InputConfig

var player: BasePlayer
var input_vector: Vector2 = Vector2.ZERO

# Cached input states for better performance
var _move_left_pressed: bool = false
var _move_right_pressed: bool = false

func _ready() -> void:
	# Get the parent BasePlayer
	player = get_parent() as BasePlayer
	if not player:
		Logger.error("PlayerInputController must be a child of BasePlayer", "PlayerInputController")
		return
	
	# Try to get player_id from parent's player_data if available
	if player.player_data and player_id == 0:
		player_id = player.player_data.player_id
		Logger.debug("InputController inherited player_id " + str(player_id) + " from BasePlayer", "PlayerInputController")
	
	# Initialize input config if not set
	if not input_config:
		_setup_default_input_config()
	
	Logger.system("Input controller initialized for player " + str(player_id) + " using " + input_config.get_device_name(), "PlayerInputController")

func _process(_delta: float) -> void:
	if not player or player.current_state == BasePlayer.PlayerState.DEAD or player.current_state == BasePlayer.PlayerState.RAGDOLLED:
		return
	
	_gather_input()
	_send_input_to_player()

func _gather_input() -> void:
	if not input_config:
		return
	
	# Reset input vector
	input_vector = Vector2.ZERO
	
	# Cache input states for performance (with safety checks)
	_move_left_pressed = InputMap.has_action(input_config.move_left_action) and Input.is_action_pressed(input_config.move_left_action)
	_move_right_pressed = InputMap.has_action(input_config.move_right_action) and Input.is_action_pressed(input_config.move_right_action)
	
	# Gather movement input
	if _move_left_pressed:
		input_vector.x -= 1.0
	if _move_right_pressed:
		input_vector.x += 1.0
	
	# Normalize input vector
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()

func _send_input_to_player() -> void:
	if not input_config:
		return
	
	# Get button press states (with safety checks)
	var jump_pressed = InputMap.has_action(input_config.jump_action) and Input.is_action_just_pressed(input_config.jump_action)
	var use_pressed = InputMap.has_action(input_config.use_action) and Input.is_action_just_pressed(input_config.use_action)
	
	# Send input to player
	player.set_input(input_vector, jump_pressed, use_pressed)
	
	# Handle item actions (with safety checks)
	if InputMap.has_action(input_config.use_action) and Input.is_action_just_pressed(input_config.use_action):
		# Try to use held item first
		if not player.use_held_item():
			# If no item or item couldn't be used, try to pick up nearest item
			player.try_pickup_nearest_item()
	
	if InputMap.has_action(input_config.drop_action) and Input.is_action_just_pressed(input_config.drop_action):
		player.drop_item()

## Setup input configuration for specific player
func setup_for_player(p_id: int, config: InputConfig = null) -> void:
	player_id = p_id
	
	if config:
		input_config = config
	else:
		_setup_default_input_config()
	
	Logger.system("Player " + str(player_id) + " input configured with " + input_config.get_device_name(), "PlayerInputController")
	Logger.debug("Actions: " + input_config.move_left_action + ", " + input_config.move_right_action + ", " + input_config.jump_action + ", " + input_config.use_action + ", " + input_config.drop_action, "PlayerInputController")

## Setup default input configuration based on player ID
func _setup_default_input_config() -> void:
	var default_configs = InputConfig.create_default_configs()
	
	if player_id >= 0 and player_id < default_configs.size():
		input_config = default_configs[player_id]
	else:
		# Fallback to first config if player_id is out of range
		input_config = default_configs[0]
		Logger.warning("Player ID " + str(player_id) + " out of range, using default config", "PlayerInputController")
	
	# Validate input actions exist
	_validate_input_config()

## Validate that all required input actions exist in the Input Map
func _validate_input_config() -> void:
	if not input_config:
		Logger.error("No input config for player " + str(player_id), "PlayerInputController")
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
		Logger.warning("Player " + str(player_id) + " missing input actions: " + str(missing_actions), "PlayerInputController")
		Logger.warning("These inputs will not work until added to Input Map", "PlayerInputController")
	else:
		Logger.debug("Player " + str(player_id) + " all input actions found", "PlayerInputController")

# Removed get_aim_direction() - weapons now handle their own aiming 

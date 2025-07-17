class_name MovementComponent
extends BaseComponent

## Movement and physics component
## Handles player movement, gravity, jumping, and collision

# Movement signals
signal started_moving()
signal stopped_moving()
signal jumped()
signal landed()
signal facing_changed(new_direction: int)

# Movement properties
@export var move_speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0
@export var movement_acceleration: float = 3.0

# Movement state
var input_vector: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var facing_direction: int = 1  # 1 for right, -1 for left
var was_on_floor: bool = false
var was_moving: bool = false

func _initialize_component() -> void:
	# Initialize from game config if available
	if player.game_config:
		move_speed = player.game_config.default_move_speed
		jump_velocity = player.game_config.default_jump_velocity
		gravity = player.game_config.default_gravity

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	_handle_movement_physics(delta)

## Handle physics and movement
func _handle_movement_physics(delta: float) -> void:
	# Handle gravity
	if not player.is_on_floor():
		player.velocity.y += gravity * delta
	
	# Check for landing
	if player.is_on_floor() and not was_on_floor:
		landed.emit()
		var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
		Logger.debug(player_name + " landed", "MovementComponent")
	was_on_floor = player.is_on_floor()
	
	# Handle jump
	if jump_pressed and player.is_on_floor():
		player.velocity.y = jump_velocity
		jump_pressed = false
		jumped.emit()
		var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
		Logger.debug(player_name + " jumped", "MovementComponent")
	
	# Handle horizontal movement
	if input_vector.x != 0:
		player.velocity.x = input_vector.x * move_speed
		
		# Check if we just started moving
		if not was_moving:
			started_moving.emit()
			was_moving = true
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, move_speed * delta * movement_acceleration)
		
		# Check if we just stopped moving
		if was_moving and abs(player.velocity.x) < 1.0:
			stopped_moving.emit()
			was_moving = false
	
	# Update facing direction
	_update_facing_direction()
	
	# Apply movement
	player.move_and_slide()

## Set input for movement
func set_input(movement: Vector2, jump: bool) -> void:
	input_vector = movement
	jump_pressed = jump

## Update facing direction based on movement
func _update_facing_direction() -> void:
	var old_facing: int = facing_direction
	
	if input_vector.x > 0:
		facing_direction = 1  # Right
		if player.sprite:
			player.sprite.scale.x = abs(player.sprite.scale.x)  # Face right
	elif input_vector.x < 0:
		facing_direction = -1  # Left
		if player.sprite:
			player.sprite.scale.x = -abs(player.sprite.scale.x)  # Face left
	
	# Emit facing change signal
	if old_facing != facing_direction:
		facing_changed.emit(facing_direction)
		var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
		Logger.debug(player_name + " facing changed: " + str(old_facing) + " -> " + str(facing_direction), "MovementComponent")

## Check if player is moving
func is_moving() -> bool:
	return abs(player.velocity.x) > 1.0 or not player.is_on_floor()

## Get current movement speed
func get_current_speed() -> float:
	return player.velocity.length()

## Stop all movement
func stop_movement() -> void:
	input_vector = Vector2.ZERO
	jump_pressed = false
	player.velocity = Vector2.ZERO

## Add impulse to the player (for knockback, etc.)
func add_impulse(impulse: Vector2) -> void:
	player.velocity += impulse
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.debug(player_name + " received impulse: " + str(impulse), "MovementComponent")

## Check if player is falling
func is_falling() -> bool:
	return player.velocity.y > 0 and not player.is_on_floor()

## Check if player is rising
func is_rising() -> bool:
	return player.velocity.y < 0

## Get facing direction as Vector2
func get_facing_vector() -> Vector2:
	return Vector2(facing_direction, 0) 
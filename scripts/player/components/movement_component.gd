class_name MovementComponent
extends BaseComponent

## Movement and physics component
## Handles player movement, gravity, jumping, and collision

# Movement signals
signal started_moving()
signal stopped_moving()
signal jumped()
signal landed()
signal player_hit_in_head(other_player: BasePlayer)  # New: any player hitting this player's head
signal facing_changed(new_direction: int)

# Movement properties
@export var move_speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0
@export var movement_acceleration: float = 3.0

# Head collision properties
@export var head_detection_radius: float = 5.0  # Half character width (character is ~20px wide)
@export var minimum_impact_velocity: float = 80.0  # Lower threshold for more responsive collisions

# Movement state
var input_vector: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var facing_direction: int = 1  # 1 for right, -1 for left
var was_on_floor: bool = false
var was_moving: bool = false

# Head collision detection
var head_area: Area2D = null
var head_collision: CollisionShape2D = null
var players_near_head: Array[BasePlayer] = []

func _initialize_component() -> void:
	# Initialize from game config if available
	if player.game_config:
		move_speed = player.game_config.default_move_speed
		jump_velocity = player.game_config.default_jump_velocity
		gravity = player.game_config.default_gravity
	
	# Create head collision detection area
	_create_head_collision_area()

func _cleanup_component() -> void:
	# Clean up head collision area
	if head_area:
		if head_area.body_entered.is_connected(_on_head_area_entered):
			head_area.body_entered.disconnect(_on_head_area_entered)
		if head_area.body_exited.is_connected(_on_head_area_exited):
			head_area.body_exited.disconnect(_on_head_area_exited)
		
		if head_collision:
			head_area.remove_child.call_deferred(head_collision)
			head_collision.queue_free()
			head_collision = null
		
		if head_area.get_parent():
			head_area.get_parent().remove_child.call_deferred(head_area)
		head_area.queue_free()
		head_area = null
	
	players_near_head.clear()

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	_handle_movement_physics(delta)
	# Removed _check_head_collisions() - now handled immediately in collision signals

## Create area for detecting collisions with this player's head
func _create_head_collision_area() -> void:
	# Create head collision detection area
	head_area = Area2D.new()
	head_area.name = "HeadCollisionArea"
	
	# Wait for player to be ready
	await player.get_tree().process_frame
	
	player.add_child(head_area)
	
	# Create collision shape - circular area around the head/upper body
	head_collision = CollisionShape2D.new()
	var head_shape = CircleShape2D.new()
	head_shape.radius = head_detection_radius
	head_collision.shape = head_shape
	# Position above the head - extends half the sphere's width above the model
	# TopCap top is at -17, so center at -17 - (radius/2) = -17 - 2.5 = -19.5
	head_collision.position = Vector2(0, -19.5)  # Extends above the player model
	head_area.add_child(head_collision)
	
	# Setup collision layers for player detection
	CollisionLayers.set_layer(head_area, CollisionLayers.Layer.NONE)
	CollisionLayers.set_mask(head_area, CollisionLayers.Mask.PLAYER_DETECTION)
	
	# Wait another frame for collision setup
	await player.get_tree().process_frame
	
	# Connect signals
	head_area.body_entered.connect(_on_head_area_entered)
	head_area.body_exited.connect(_on_head_area_exited)
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.debug("Created head collision detection area for " + player_name, "MovementComponent")

## Handle physics and movement
func _handle_movement_physics(delta: float) -> void:
	# Handle gravity
	if not player.is_on_floor():
		player.velocity.y += gravity * delta
	
	# Check for landing
	if player.is_on_floor() and not was_on_floor:
		landed.emit()
		var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
		Logger.debug(player_name + " landed on ground", "MovementComponent")
	
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

## Trigger ragdoll on this player when hit in the head
func _trigger_head_collision(other_player: BasePlayer) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	var other_name: String = other_player.player_data.player_name if other_player.player_data else "Unknown Player"
	
	Logger.combat("💥 HEAD COLLISION: " + other_name + " hit " + player_name + " in the head - triggering DRAMATIC ragdoll!", "MovementComponent")
	
	# Calculate impact direction for more realistic physics
	var impact_direction: Vector2 = player.global_position - other_player.global_position
	impact_direction = impact_direction.normalized()
	
	# Add velocity considerations for more dynamic impacts
	var relative_velocity: Vector2 = other_player.velocity - player.velocity
	if relative_velocity.length() > 50.0:
		impact_direction += relative_velocity.normalized() * 0.5  # Blend in velocity direction
	
	# Trigger DRAMATIC ragdoll on THIS player (the one who got hit in the head)
	var ragdoll_component: RagdollComponent = player.get_component(RagdollComponent)
	if ragdoll_component:
		ragdoll_component.enter_head_collision_ragdoll(impact_direction)
	
	# Emit signals immediately for proper synchronization
	player_hit_in_head.emit(other_player)
	EventBus.emit_player_landed_on_player(other_player.player_data.player_id, player.player_data.player_id)

## Head collision area signal handlers
func _on_head_area_entered(body: Node2D) -> void:
	if body is BasePlayer and body != player:
		var other_player: BasePlayer = body as BasePlayer
		if other_player not in players_near_head:
			players_near_head.append(other_player)
			
			# Check for collision immediately when entering head area
			_check_immediate_head_collision(other_player)

func _on_head_area_exited(body: Node2D) -> void:
	if body is BasePlayer:
		var other_player: BasePlayer = body as BasePlayer
		if other_player in players_near_head:
			players_near_head.erase(other_player)

## Check for immediate head collision when a player enters the head area
func _check_immediate_head_collision(other_player: BasePlayer) -> void:
	if not other_player or other_player == player:
		return
	
	# Check if other player is alive and not already ragdolled
	if other_player.current_state != BasePlayer.PlayerState.ALIVE:
		return
	
	# Head collisions always trigger ragdolls regardless of velocity for Mario Party-style chaos
	# This ensures players ragdoll when landing on each other, even when standing still
	
	# Trigger collision immediately
	_trigger_head_collision(other_player)

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
class_name RagdollComponent
extends BaseComponent

## Ragdoll physics and transitions component
## Handles ragdoll state, physics body creation, and recovery

# Ragdoll signals
signal ragdoll_entered()
signal ragdoll_exited()
signal ragdoll_impact(force: Vector2)

# Ragdoll properties
@export var ragdoll_force_threshold: float = 800.0
@export var ragdoll_recovery_time: float = 2.0
@export var ragdoll_gravity_scale: float = 1.0
@export var ragdoll_mass: float = 2.0
@export var ragdoll_linear_damp: float = 3.0
@export var ragdoll_angular_damp: float = 2.0

# Ragdoll state
var is_ragdolled: bool = false
var ragdoll_body: RigidBody2D = null
var ragdoll_timer: float = 0.0
var pre_ragdoll_position: Vector2 = Vector2.ZERO
var auto_recovery_enabled: bool = true

func _initialize_component() -> void:
	# Initialize from game config if available
	if player.game_config:
		ragdoll_force_threshold = player.game_config.ragdoll_force_threshold
		ragdoll_recovery_time = player.game_config.ragdoll_recovery_time
		ragdoll_gravity_scale = player.game_config.ragdoll_gravity_scale

func _physics_process(delta: float) -> void:
	if not is_ragdolled:
		_check_for_ragdoll_conditions()
	else:
		_handle_ragdoll_physics(delta)

## Check if conditions are met for entering ragdoll state
func _check_for_ragdoll_conditions() -> void:
	if player.velocity.length() > ragdoll_force_threshold:
		enter_ragdoll_state()

## Handle ragdoll physics updates
func _handle_ragdoll_physics(delta: float) -> void:
	ragdoll_timer += delta
	
	# Sync position AND rotation with ragdoll body
	if ragdoll_body:
		player.global_position = ragdoll_body.global_position
		player.rotation = ragdoll_body.rotation  # Sync rotation too!
	
	# Check for auto recovery
	if auto_recovery_enabled and ragdoll_timer >= ragdoll_recovery_time:
		exit_ragdoll_state()

## Enter ragdoll state
func enter_ragdoll_state(disable_auto_recovery: bool = false) -> void:
	if is_ragdolled:
		return
	
	is_ragdolled = true
	ragdoll_timer = 0.0
	auto_recovery_enabled = not disable_auto_recovery
	
	# Store position for recovery
	pre_ragdoll_position = player.global_position
	
	# Disable collision on original player to prevent self-collision with ragdoll body
	player.set_collision_layer_value(2, false)  # Disable PLAYERS layer (bit position 2)
	player.set_collision_mask_value(1, false)   # Disable ENVIRONMENT collision (bit position 1)
	player.set_collision_mask_value(2, false)   # Disable PLAYERS collision (bit position 2)
	
	# Disable player input and pickup
	var input_component: InputComponent = player.get_component(InputComponent)
	if input_component:
		input_component.set_input_enabled(false)
	
	# Handle items (if player has ItemComponent)
	var item_component: ItemComponent = player.get_component(ItemComponent)
	if item_component:
		item_component.set_pickup_enabled(false)
		# Force throw held item with dramatic velocity (inherits player velocity + ragdoll physics)
		var throw_velocity: Vector2 = player.velocity * 0.8
		throw_velocity.y -= 150.0  # Extra upward force for ragdoll throws
		throw_velocity.x += randf_range(-100.0, 100.0)  # Random horizontal spread for chaos
		item_component.force_throw_item(throw_velocity)
	
	# Create ragdoll physics body (deferred to avoid physics conflicts)
	call_deferred("_create_ragdoll_body")
	
	# Use transparency instead of hiding - half transparent for ragdoll
	player.modulate.a = 0.5
	
	ragdoll_entered.emit()
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "entered ragdoll state with half transparency", "RagdollComponent")

## Exit ragdoll state
func exit_ragdoll_state() -> void:
	if not is_ragdolled:
		return
	
	is_ragdolled = false
	
	# Restore position from ragdoll (but dampen velocity)
	if ragdoll_body:
		player.global_position = ragdoll_body.global_position
		player.velocity = ragdoll_body.linear_velocity * 0.3  # Dampen velocity on recovery
	
	# Restore collision on original player
	player.set_collision_layer_value(2, true)  # Restore PLAYERS layer (bit position 2)
	player.set_collision_mask_value(1, true)   # Restore ENVIRONMENT collision (bit position 1)
	player.set_collision_mask_value(2, true)   # Restore PLAYERS collision (bit position 2)
	
	# Re-enable player systems
	var input_component: InputComponent = player.get_component(InputComponent)
	if input_component:
		input_component.set_input_enabled(true)
	
	# Re-enable item pickup (if player has ItemComponent)
	var item_component: ItemComponent = player.get_component(ItemComponent)
	if item_component:
		item_component.set_pickup_enabled(true)
	
	# Clean up ragdoll body
	_remove_ragdoll_body()
	
	# Restore visual state - full transparency and no rotation
	player.modulate.a = 1.0
	player.rotation = 0.0
	
	ragdoll_exited.emit()
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "recovered from ragdoll with full transparency", "RagdollComponent")

## Create ragdoll physics body
func _create_ragdoll_body() -> void:
	if ragdoll_body:
		return
	
	# Create a RigidBody2D with tipping-friendly physics (physics only, no visuals)
	ragdoll_body = RigidBody2D.new()
	ragdoll_body.gravity_scale = ragdoll_gravity_scale
	ragdoll_body.mass = ragdoll_mass
	ragdoll_body.linear_damp = ragdoll_linear_damp
	ragdoll_body.angular_damp = ragdoll_angular_damp
	
	# Disable continuous collision detection to prevent bouncing
	ragdoll_body.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	ragdoll_body.can_sleep = true  # Allow sleeping to stabilize physics
	
	# Create physics material for reduced friction
	var physics_material: PhysicsMaterial = PhysicsMaterial.new()
	physics_material.bounce = 0.0  # No bouncing
	physics_material.friction = 0.8  # Reduced friction for easier sliding/tipping
	ragdoll_body.physics_material_override = physics_material
	
	# Set collision layers
	CollisionLayers.setup_ragdoll(ragdoll_body)
	
	# Store reference to owner player for damage detection
	ragdoll_body.set_meta("owner_player", player)
	
	# Copy collision shape from player
	var ragdoll_collision: CollisionShape2D = CollisionShape2D.new()
	ragdoll_collision.shape = player.collision_shape.shape
	# Offset collision shape upward to raise center of mass and encourage tipping
	ragdoll_collision.position.y = -5  # Move collision up for higher center of gravity
	ragdoll_body.add_child(ragdoll_collision)
	
	# No visual components needed - player remains visible with transparency
	# The original player sprite shows the ragdoll state visually
	
	# Add to scene
	player.get_parent().add_child(ragdoll_body)
	ragdoll_body.global_position = player.global_position
	ragdoll_body.rotation = player.rotation  # Sync initial rotation
	
	# Apply initial velocity with clamping to prevent excessive bouncing
	var clamped_velocity: Vector2 = player.velocity
	var max_ragdoll_velocity: float = 300.0
	if clamped_velocity.length() > max_ragdoll_velocity:
		clamped_velocity = clamped_velocity.normalized() * max_ragdoll_velocity
	
	# Reduce initial velocity to prevent amplification
	clamped_velocity *= 0.5
	ragdoll_body.linear_velocity = clamped_velocity
	
	# Wait one frame to ensure ragdoll body is properly in the scene
	await player.get_tree().process_frame
	
	# Apply tipping force for realistic physics
	_apply_tipping_force()
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.debug("Created physics-only ragdoll body for " + player_name, "RagdollComponent")

## Apply tipping force to ragdoll body
func _apply_tipping_force() -> void:
	if not ragdoll_body:
		return
	
	# Calculate tipping force based on movement and impacts - more dramatic base values!
	var base_tipping_force: Vector2 = Vector2(0, -120)  # Much stronger upward force for better chaos
	
	# Add directional tipping based on player movement
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	if movement_component and movement_component.input_vector.x != 0:
		base_tipping_force.x += movement_component.input_vector.x * 60.0  # Doubled for more dramatic effect
	
	# Add impact-based tipping if moving fast
	if player.velocity.length() > 200.0:
		base_tipping_force.x += randf_range(-100.0, 100.0)  # Doubled random horizontal force
		base_tipping_force.y -= randf_range(40.0, 80.0)   # Doubled upward force for impacts
	
	# Add some random chaos to all ragdolls for Mario Party style
	base_tipping_force.x += randf_range(-30.0, 30.0)  # Random horizontal chaos
	base_tipping_force.y -= randf_range(10.0, 30.0)   # Random extra upward force
	
	# Apply the force at the top of the sprite (20 pixels up from center)
	var top_offset: Vector2 = Vector2(0, -20)
	ragdoll_body.apply_impulse(base_tipping_force, top_offset)
	
	ragdoll_impact.emit(base_tipping_force)
	Logger.debug("Applied enhanced tipping force " + str(base_tipping_force) + " at offset " + str(top_offset), "RagdollComponent")

## Remove ragdoll physics body
func _remove_ragdoll_body() -> void:
	if not ragdoll_body:
		return
	
	ragdoll_body.queue_free()
	ragdoll_body = null

## Force enter ragdoll for death (doesn't auto-recover)
func enter_death_ragdoll() -> void:
	enter_ragdoll_state(true)  # Disable auto recovery
	
	# Make death ragdoll more transparent than regular ragdoll
	player.modulate.a = 0.3
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "entered death ragdoll state with low transparency", "RagdollComponent")

## Force enter ragdoll from head collision with dramatic force
func enter_head_collision_ragdoll(impact_direction: Vector2 = Vector2.ZERO) -> void:
	enter_ragdoll_state()  # Enable auto recovery for head collisions
	
	# Wait for ragdoll body to be created, then apply dramatic force
	await get_tree().process_frame
	await get_tree().process_frame
	
	if ragdoll_body:
		_apply_head_collision_force(impact_direction)
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.combat(player_name + " entered HEAD COLLISION ragdoll with dramatic force!", "RagdollComponent")

## Apply dramatic force for head collision ragdolls
func _apply_head_collision_force(impact_direction: Vector2) -> void:
	if not ragdoll_body:
		return
	
	# Much more dramatic force for head collisions - Mario Party style!
	var head_collision_force: Vector2 = Vector2(0, -200)  # Strong upward force
	
	# Add random horizontal chaos
	head_collision_force.x += randf_range(-150.0, 150.0)  # Random horizontal spin
	head_collision_force.y -= randf_range(50.0, 100.0)   # Extra random upward boost
	
	# If we have impact direction info, use it for more realistic physics
	if impact_direction.length() > 0:
		var normalized_impact: Vector2 = impact_direction.normalized()
		head_collision_force.x += normalized_impact.x * 100.0  # Push in impact direction
		head_collision_force.y -= abs(normalized_impact.y) * 75.0  # Extra upward force
	
	# Apply the force at multiple points for more dramatic spinning
	var top_offset: Vector2 = Vector2(0, -20)
	var side_offset: Vector2 = Vector2(randf_range(-15.0, 15.0), 0)
	
	# Main dramatic force at the top
	ragdoll_body.apply_impulse(head_collision_force, top_offset)
	
	# Additional spinning force at the side
	var spin_force: Vector2 = Vector2(randf_range(-75.0, 75.0), randf_range(-25.0, 25.0))
	ragdoll_body.apply_impulse(spin_force, side_offset)
	
	ragdoll_impact.emit(head_collision_force)
	Logger.combat("Applied DRAMATIC head collision force: " + str(head_collision_force) + " + spin: " + str(spin_force), "RagdollComponent")

## Cleanup ragdoll state completely
func cleanup_ragdoll_state() -> void:
	ragdoll_timer = 0.0
	pre_ragdoll_position = Vector2.ZERO
	auto_recovery_enabled = true
	
	# Clean up ragdoll body if it exists - proper cleanup to prevent RID leaks
	if ragdoll_body:
		# Remove meta reference to prevent circular references
		ragdoll_body.remove_meta("owner_player")
		
		# Disable physics to prevent further processing
		ragdoll_body.freeze = true
		ragdoll_body.set_gravity_scale(0)
		
		# Remove from parent to break scene tree references
		if ragdoll_body.get_parent():
			ragdoll_body.get_parent().remove_child(ragdoll_body)
		
		# Free the ragdoll body immediately
		ragdoll_body.queue_free()
		ragdoll_body = null
	
	# Restore collision on original player
	player.set_collision_layer_value(2, true)  # Restore PLAYERS layer (bit position 2)
	player.set_collision_mask_value(1, true)   # Restore ENVIRONMENT collision (bit position 1)
	player.set_collision_mask_value(2, true)   # Restore PLAYERS collision (bit position 2)
	
	# Re-enable systems
	var input_component: InputComponent = player.get_component(InputComponent)
	if input_component:
		input_component.set_input_enabled(true)
	
	# Re-enable item pickup (if player has ItemComponent)
	var item_component: ItemComponent = player.get_component(ItemComponent)
	if item_component:
		item_component.set_pickup_enabled(true)
	
	# Restore full transparency
	player.modulate.a = 1.0
	
	is_ragdolled = false

## Check if currently in ragdoll state
func is_in_ragdoll_state() -> bool:
	return is_ragdolled

## Set ragdoll force threshold
func set_force_threshold(threshold: float) -> void:
	ragdoll_force_threshold = threshold

## Set ragdoll recovery time
func set_recovery_time(time: float) -> void:
	ragdoll_recovery_time = time

## Get ragdoll body for external manipulation
func get_ragdoll_body() -> RigidBody2D:
	return ragdoll_body 

class_name Bullet
extends RigidBody2D

## Bullet projectile for ranged weapons with object pooling support
## Handles movement, collision, and damage dealing

@export var lifetime: float = 3.0
@export var damage: int = 1

# Components
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_audio: AudioStreamPlayer2D = $HitAudio

# State
var shooter: BasePlayer = null
var velocity_vector: Vector2 = Vector2.ZERO
var time_alive: float = 0.0
var has_hit: bool = false  # Prevent multiple hits and stack overflow
var hit_bodies: Array[Node] = []  # Track what we've already hit to prevent double-processing

# Pooling state
var is_pooled: bool = false
var scene_path: String = "res://scenes/items/bullet.tscn"

func _ready() -> void:
	# Setup physics
	gravity_scale = 0.0  # Bullets aren't affected by gravity
	contact_monitor = true
	max_contacts_reported = 10
	
	# Setup collision layers
	CollisionLayers.setup_projectile(self)
	
	# Connect collision signal only if not already connected (for pool reuse)
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)
	
	Logger.debug("Bullet created", "Bullet")

func _physics_process(delta: float) -> void:
	# Update lifetime
	time_alive += delta
	
	# Destroy bullet after lifetime
	if time_alive >= lifetime:
		_destroy_bullet()
		return
	
	# Apply velocity
	linear_velocity = velocity_vector

## Initialize bullet with velocity and damage
func initialize(velocity: Vector2, bullet_damage: int, firing_player: BasePlayer) -> void:
	velocity_vector = velocity
	damage = bullet_damage
	shooter = firing_player
	
	# Set rotation to match direction
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()
	
	# Set initial velocity
	linear_velocity = velocity_vector
	
	Logger.debug("Bullet initialized with velocity: " + str(velocity) + " damage: " + str(damage), "Bullet")

## Handle collision with other bodies (RigidBody2D contact monitoring)
func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	# Prevent multiple hits and stack overflow - use call_deferred to ensure single execution
	if has_hit:
		return
	
	# Mark as hit immediately and use call_deferred to prevent double execution
	has_hit = true
	call_deferred("_process_collision", body)

## Process collision on deferred call to prevent double hits
func _process_collision(body: Node) -> void:
	# Double-check we haven't already processed a hit
	if not has_hit:
		return
	
	# Check if we've already processed this body
	if body in hit_bodies:
		return
	
	# Add to hit bodies list to prevent double-processing
	hit_bodies.append(body)
	
	Logger.combat("Bullet hit: " + body.name, "Bullet")
	
	# Don't hit the shooter - just ignore and continue flying
	if body == shooter:
		# Keep shooter in hit_bodies to prevent future hits, but don't reset has_hit
		return
	
	# Disconnect signal to prevent any more collisions
	if body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.disconnect(_on_body_shape_entered)
	
	# Disable further collision detection immediately
	CollisionLayers.disable_all_collisions(self)
	
	var hit_player: BasePlayer = null
	
	# Check if hit a player directly
	if body is BasePlayer:
		hit_player = body as BasePlayer
	
	# Check if hit a ragdoll body (find the associated player)
	elif body is RigidBody2D and body.has_meta("owner_player"):
		# Get the player that owns this ragdoll
		hit_player = body.get_meta("owner_player") as BasePlayer
	
	# Deal damage to living players, but ALWAYS destroy bullet on player hit
	if hit_player:
		# Only report damage to living players, but bullets stop on all players
		if hit_player.current_state != BasePlayer.PlayerState.DEAD:
			# Report damage to minigame instead of applying directly
			var attacker_id = shooter.player_data.player_id if shooter and shooter.player_data else -1
			var hit_player_id = hit_player.player_data.player_id if hit_player.player_data else -1
			EventBus.report_player_damage(hit_player_id, attacker_id, damage, "Bullet")
			var hit_player_name: String = hit_player.player_data.player_name if hit_player.player_data else "Unknown Player"
			Logger.combat("Bullet reported " + str(damage) + " damage from Player " + str(attacker_id) + " to " + hit_player_name, "Bullet")
		else:
			Logger.debug("Bullet hit dead player - no damage but bullet destroyed", "Bullet")
	
	# Hit something, destroy bullet (always destroy on any collision)
	_hit_target(body)

## Handle hitting a target
func _hit_target(target: Node) -> void:
	# Stop all physics immediately (deferred to avoid callback conflicts)
	set_deferred("linear_velocity", Vector2.ZERO)
	set_deferred("freeze", true)
	
	# Play hit audio
	if hit_audio:
		hit_audio.play()
	
	# TODO: Add hit particle effects
	call_deferred("_destroy_bullet")

## Clean up and destroy bullet or return to pool
func _destroy_bullet() -> void:
	# Disable collision detection if not already disabled
	if not has_hit:
		CollisionLayers.disable_all_collisions(self)
	
	# Stop all physics to prevent further collisions
	linear_velocity = Vector2.ZERO
	freeze = true
	
	# Return to pool instead of destroying
	if is_pooled:
		Logger.debug("Bullet returned to pool", "Bullet")
		PoolManager.return_item(self, "bullet")
	else:
		Logger.debug("Bullet destroyed (not pooled)", "Bullet")
		queue_free()

## Cleanup bullet properly to prevent RID leaks
func _exit_tree() -> void:
	# Disconnect collision signal
	if body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.disconnect(_on_body_shape_entered)
	
	# Clear shooter reference to prevent circular references
	if shooter:
		shooter = null
	
	# Clear hit bodies array
	hit_bodies.clear()
	
	Logger.debug("Bullet cleanup completed", "Bullet")

# Object pooling interface implementation
## Reset object to initial state for reuse
func reset_for_pool() -> void:
	# Reset all state variables
	shooter = null
	velocity_vector = Vector2.ZERO
	time_alive = 0.0
	has_hit = false
	hit_bodies.clear()
	
	# Reset physics state completely
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = false
	rotation = 0.0
	
	# Ensure all collision signals are disconnected
	if body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.disconnect(_on_body_shape_entered)
	
	# Re-enable collision detection with fresh setup
	CollisionLayers.setup_projectile(self)
	
	# Ensure contact monitoring is enabled for collision detection
	contact_monitor = true
	max_contacts_reported = 10
	
	# Note: Signal will be reconnected in activate_from_pool() or _ready()
	
	Logger.debug("Bullet reset for pool reuse", "Bullet")

## Prepare object for use when retrieved from pool
func activate_from_pool() -> void:
	is_pooled = true
	
	# Ensure bullet is in proper state for use
	visible = true
	set_process(true)
	set_physics_process(true)
	
	# Double-check collision setup is correct
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)
	
	# Ensure collision layers are properly configured
	CollisionLayers.setup_projectile(self)
	
	Logger.debug("Bullet activated from pool", "Bullet")

## Prepare object for return to pool
func deactivate_for_pool() -> void:
	# Disable all collision detection immediately
	CollisionLayers.disable_all_collisions(self)
	
	# Disconnect collision signals to prevent further processing
	if body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.disconnect(_on_body_shape_entered)
	
	# Stop all physics
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = true
	
	# Reset visual state
	visible = false
	rotation = 0.0
	
	# Disable processing to save performance
	set_process(false)
	set_physics_process(false)
	
	# Only log during actual pool returns, not pre-warming
	if get_parent() != null:
		Logger.debug("Bullet deactivated for pool storage", "Bullet") 

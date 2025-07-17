class_name Bullet
extends RigidBody2D

## Bullet projectile for ranged weapons
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

func _ready() -> void:
	# Setup physics
	gravity_scale = 0.0  # Bullets aren't affected by gravity
	contact_monitor = true
	max_contacts_reported = 10
	
	# Setup collision layers
	CollisionLayers.setup_projectile(self)
	
	# Connect collision signal (RigidBody2D uses body_shape_entered)
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
	
	Logger.combat("Bullet hit: " + body.name, "Bullet")
	
	# Don't hit the shooter
	if body == shooter:
		has_hit = false  # Reset for other potential targets
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
			var attacker_id = shooter.player_data.player_id if shooter else -1
			EventBus.report_player_damage(hit_player.player_data.player_id, attacker_id, damage, "Bullet")
			Logger.combat("Bullet reported " + str(damage) + " damage from Player " + str(attacker_id) + " to " + hit_player.player_data.player_name, "Bullet")
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

## Clean up and destroy bullet
func _destroy_bullet() -> void:
	# Disable collision detection if not already disabled
	if not has_hit:
		CollisionLayers.disable_all_collisions(self)
	
	# Stop all physics to prevent further collisions (deferred)
	set_deferred("linear_velocity", Vector2.ZERO)
	set_deferred("freeze", true)
	
	Logger.debug("Bullet destroyed", "Bullet")
	queue_free() 

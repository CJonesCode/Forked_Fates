class_name ProjectileBullet
extends RigidBody2D

## Bullet projectile for projectile-style weapons with object pooling support
## Features collision detection, damage dealing, and optional ricochet mechanics

# Bullet properties
@export var speed: float = 800.0
@export var damage: int = 1
@export var lifetime: float = 5.0
@export var can_ricochet: bool = true
@export var max_ricochets: int = 2

# State
var velocity_vector: Vector2 = Vector2.ZERO
var shooter_id: int = -1  # ID instead of object reference
var is_pooled: bool = false
var lifetime_timer: float = 0.0
var ricochet_count: int = 0

# Projectile enhancements
var penetration_count: int = 0
var max_penetrations: int = 0

# Component references
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# Note: TrailParticles node doesn't exist in scene - skip for now
var trail_particles: CPUParticles2D = null

func _ready() -> void:
	# Setup physics
	gravity_scale = 0  # Bullets ignore gravity
	contact_monitor = true
	max_contacts_reported = 10
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY  # Prevent fast bullets from tunneling
	
	# Setup collision layers
	CollisionLayers.setup_bullet(self)
	
	# Connect collision signal safely - use body_shape_entered for RigidBody2D
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)
	
	# Start trail particles if available
	if trail_particles:
		trail_particles.emitting = true
	
	Logger.debug("Bullet ready with projectile mechanics", "Bullet")

func _physics_process(delta: float) -> void:
	# Move bullet
	if velocity_vector.length() > 0:
		linear_velocity = velocity_vector
	
	# Update lifetime
	lifetime_timer += delta
	if lifetime_timer >= lifetime:
		_destroy_bullet()
	
	# Rotate bullet to face movement direction for better visuals
	if velocity_vector.length() > 0:
		rotation = velocity_vector.angle()

## Initialize bullet with direction, position, and shooter ID
func initialize(direction: Vector2, spawn_position: Vector2, bullet_shooter_id: int) -> void:
	velocity_vector = direction * speed
	global_position = spawn_position
	shooter_id = bullet_shooter_id
	lifetime_timer = 0.0
	ricochet_count = 0
	penetration_count = 0
	
	# Set collision exclusions - don't hit shooter initially
	var shooter: BasePlayer = PlayerManager.get_player(shooter_id)
	if shooter:
		# Note: In Godot 4.x, we handle shooter exclusion via ID check in collision handler
		# No need for RID-based exclusion since we check shooter_id in _on_body_shape_entered
		Logger.debug("Bullet initialized with shooter exclusion for player ID: " + str(shooter_id), "Bullet")
	
	# Set damage from shooter's weapon if available
	var item_component: ItemComponent = shooter.item if shooter else null
	if item_component and item_component.get_held_weapon():
		var weapon: BaseWeapon = item_component.get_held_weapon()
		damage = weapon.base_damage
		
		# Check for ricochet vs destruction (projectile enhancement)
		if weapon.has_method("get_ricochet_enabled"):
			can_ricochet = weapon.get_ricochet_enabled()
		else:
			can_ricochet = true  # Default behavior
	
	Logger.debug("Bullet initialized: speed=" + str(speed) + ", damage=" + str(damage) + ", direction=" + str(direction), "Bullet")

## Handle collision with bodies
func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	Logger.debug("Bullet collision with: " + body.name + " (" + body.get_class() + ")", "Bullet")
	
	# Don't hit the shooter immediately
	if body is BasePlayer:
		var player: BasePlayer = body as BasePlayer
		if player.player_data and player.player_data.player_id == shooter_id:
			Logger.debug("Ignoring collision with shooter", "Bullet")
			return
	
	# Handle player hits
	if body is BasePlayer:
		_hit_player(body as BasePlayer)
		return
	
	# Handle environment/wall hits
	if body.is_in_group("walls") or body.is_in_group("environment"):
		_hit_environment(body)
		return
	
	# Handle other collisions (items, etc.)
	Logger.debug("Bullet hit other object: " + body.name, "Bullet")
	_destroy_bullet()

## Handle hitting a player
func _hit_player(player: BasePlayer) -> void:
	var shooter: BasePlayer = PlayerManager.get_player(shooter_id)
	if not player:
		_destroy_bullet()
		return
	
	# Report damage through universal damage system
	var player_data: PlayerData = player.get_player_data()
	var shooter_data: PlayerData = shooter.player_data if shooter else null
	if player_data and shooter_data:
		EventBus.report_player_damage(
			player_data.player_id,
			shooter_data.player_id,
			damage,
			"Bullet"
		)
		
		var player_name: String = player_data.player_name
		var shooter_name: String = shooter_data.player_name
		Logger.combat("Bullet from " + shooter_name + " hit " + player_name + " for " + str(damage) + " damage", "Bullet")
	
	# Check for penetration (enhanced projectile mechanic)
	if penetration_count < max_penetrations:
		penetration_count += 1
		Logger.debug("Bullet penetrated target (" + str(penetration_count) + "/" + str(max_penetrations) + ")", "Bullet")
		return  # Continue flying
	
	# Destroy bullet after hit
	_destroy_bullet()

## Handle hitting environment/walls
func _hit_environment(surface: Node) -> void:
	Logger.debug("Bullet hit environment: " + surface.name, "Bullet")
	
	# Check for ricochet
	if can_ricochet and ricochet_count < max_ricochets:
		_handle_ricochet(surface)
	else:
		_destroy_bullet()

## Check if bullet should ricochet off this surface (projectile enhancement)
func _should_ricochet(surface: Node) -> bool:
	# Simple ricochet logic - could be enhanced with surface materials
	if not can_ricochet or ricochet_count >= max_ricochets:
		return false
	
	# Could check surface properties here
	# For now, allow ricochet off walls and environment
	return surface.is_in_group("walls") or surface.is_in_group("environment")

## Handle bullet ricochet off surface (projectile enhancement)
func _handle_ricochet(surface: Node) -> void:
	ricochet_count += 1
	
	# Calculate surface normal (simplified - assumes horizontal/vertical surfaces)
	var surface_normal: Vector2
	var hit_point = global_position
	var surface_position = surface.global_position
	
	# Simple normal calculation based on relative position
	var relative_pos = hit_point - surface_position
	if abs(relative_pos.x) > abs(relative_pos.y):
		surface_normal = Vector2(sign(relative_pos.x), 0)  # Vertical surface
	else:
		surface_normal = Vector2(0, sign(relative_pos.y))  # Horizontal surface
	
	# Reflect velocity
	velocity_vector = velocity_vector.bounce(surface_normal)
	
	# Reduce speed on ricochet
	velocity_vector *= 0.8
	speed *= 0.8
	
	# Reduce lifetime slightly
	lifetime *= 0.9
	
	Logger.debug("Bullet ricocheted off " + surface.name + " (" + str(ricochet_count) + "/" + str(max_ricochets) + ")", "Bullet")

## Destroy bullet and return to pool if applicable
func _destroy_bullet() -> void:
	Logger.debug("Destroying bullet (pooled: " + str(is_pooled) + ")", "Bullet")
	
	# Stop trail particles
	if trail_particles:
		trail_particles.emitting = false
	
	# Return to pool or destroy (deferred to avoid physics callback issues)
	if is_pooled:
		call_deferred("_deferred_return_to_pool")
	else:
		queue_free()

## Deferred method to return bullet to pool (avoids physics callback issues)
func _deferred_return_to_pool() -> void:
	PoolManager.return_item(self, "bullet")

## Reset bullet for object pooling
func reset_for_pool() -> void:
	# Reset state
	velocity_vector = Vector2.ZERO
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	shooter_id = -1
	lifetime_timer = 0.0
	ricochet_count = 0
	penetration_count = 0
	
	# Reset position and rotation
	global_position = Vector2.ZERO
	rotation = 0.0
	
	# Reset physics
	freeze = false
	sleeping = false
	
	# Reset visibility
	visible = true
	modulate = Color.WHITE
	
	# Reset collision - crucial for pool reuse
	collision_layer = CollisionLayers.Layer.PROJECTILES
	collision_mask = CollisionLayers.Mask.PROJECTILE_TARGETS
	
	# Stop trail particles
	if trail_particles:
		trail_particles.emitting = false
		trail_particles.restart()
	
	Logger.debug("Bullet reset for pool reuse", "Bullet")

## Activate bullet from pool
func activate_from_pool() -> void:
	# Ensure collision is properly configured
	CollisionLayers.setup_bullet(self)
	
	# Start trail particles
	if trail_particles:
		trail_particles.emitting = true
	
	# Ensure signal is connected - use body_shape_entered for RigidBody2D
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)
	
	Logger.debug("Bullet activated from pool", "Bullet")

## Set enhanced properties for special bullets
func set_penetrating(max_pen: int) -> void:
	max_penetrations = max_pen
	Logger.debug("Bullet set to penetrating: " + str(max_pen) + " targets", "Bullet")

func set_ricochet_enabled(enabled: bool, max_bounces: int = 2) -> void:
	can_ricochet = enabled
	max_ricochets = max_bounces
	Logger.debug("Bullet ricochet: " + str(enabled) + " (max: " + str(max_bounces) + ")", "Bullet")

## Get bullet status for debugging
func get_bullet_status() -> Dictionary:
	return {
		"speed": speed,
		"damage": damage,
		"lifetime_remaining": lifetime - lifetime_timer,
		"ricochets_remaining": max_ricochets - ricochet_count,
		"penetrations_remaining": max_penetrations - penetration_count,
		"is_pooled": is_pooled,
		"shooter": get_shooter_name()
	}

## Get shooter player object (type-safe lookup)
func get_shooter() -> BasePlayer:
	if shooter_id == -1:
		return null
	return PlayerManager.get_player(shooter_id)

## Get shooter name for debugging
func get_shooter_name() -> String:
	var shooter: BasePlayer = get_shooter()
	if shooter and shooter.player_data:
		return shooter.player_data.player_name
	return "None" 

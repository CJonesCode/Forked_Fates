class_name BaseWeapon
extends RigidBody2D

## Base weapon class for all combat items in projectile style
## Handles pickup, use, throwing, and collision mechanics
## Designed for throwing-centric combat with all weapons becoming projectiles

# Weapon properties
@export var weapon_name: String = "Base Weapon"
@export var base_damage: int = 1
@export var fire_rate: float = 1.0
@export var ammo_capacity: int = -1  # -1 for infinite ammo
@export var can_be_picked_up: bool = true
@export var throw_damage_multiplier: float = 1.5

# Throwing and projectile properties
@export var max_throw_force: float = 600.0
@export var projectile_lifetime: float = 10.0
@export var can_ricochet: bool = false
@export var max_ricochets: int = 2

# Weapon state
var holder: BasePlayer = null
var is_held: bool = false
var is_thrown_projectile: bool = false
var ammo_current: int = 0
var thrown_by: BasePlayer = null
var throw_damage: int = 0
var ricochet_count: int = 0

# Component references
var original_collision_layer: int = 0
var original_collision_mask: int = 0

# Projectile style signals - clear weapon-focused naming
signal weapon_fired()
signal weapon_thrown(thrower: BasePlayer)
signal weapon_hit_target(target: Node, damage: int)
signal ammo_depleted()

func _ready() -> void:
	# Store original collision settings
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	# Set up for weapon state
	CollisionLayers.setup_weapon(self)
	
	# Initialize ammo if weapon has ammo capacity
	if ammo_capacity > 0:
		ammo_current = ammo_capacity
	
	# Connect to collision signals for thrown projectiles
	if not body_entered.is_connected(_on_body_shape_entered):
		body_entered.connect(_on_body_shape_entered)
	
	Logger.system("BaseWeapon " + weapon_name + " ready with projectile mechanics", "BaseWeapon")

func _physics_process(_delta: float) -> void:
	# Update position when held
	if is_held and holder:
		_update_held_position()
	
	# Handle thrown projectile physics
	if is_thrown_projectile:
		_handle_projectile_physics(_delta)

## Update position when held by player
func _update_held_position() -> void:
	if not holder or not is_held:
		return
	
	var weapon_component = holder.weapon  # Direct reference to avoid circular dependency
	if weapon_component and weapon_component.has_method("get_weapon_hold_position"):
		global_position = weapon_component.get_weapon_hold_position()
		
		# Rotate weapon based on player facing
		var movement_component: MovementComponent = holder.get_component(MovementComponent)
		if movement_component:
			var facing_dir: int = movement_component.facing_direction
			rotation = 0 if facing_dir > 0 else PI

## Handle projectile physics when thrown
func _handle_projectile_physics(_delta: float) -> void:
	# Projectile lifetime countdown
	projectile_lifetime -= _delta
	if projectile_lifetime <= 0:
		_destroy_projectile()

## Pick up this weapon (called by player)
func pickup_weapon(player: BasePlayer) -> bool:
	if not can_be_picked_up or is_held:
		return false
	
	Logger.pickup("Weapon " + weapon_name + " picked up by " + player.player_data.player_name, "BaseWeapon")
	
	# Attach to player
	holder = player
	is_held = true
	is_thrown_projectile = false
	can_be_picked_up = false
	
	# Disable physics when held
	freeze = true
	
	# Projectile style - no pickup disable time, immediate pickup allowed
	can_be_picked_up = false
	
	# Reset collision settings
	collision_layer = 0
	collision_mask = 0
	
	# Emit pickup signal
	weapon_hit_target.emit(player, 0)  # 0 damage for pickup
	
	return true

## Fire this weapon (implemented by subclasses)
func fire_weapon() -> bool:
	Logger.warning("fire_weapon() not implemented for " + weapon_name, "BaseWeapon")
	return false

## Throw this weapon as a projectile (projectile core mechanic)
func throw_weapon(direction: Vector2, force: float, thrower: BasePlayer) -> bool:
	if not is_held:
		return false
	
	Logger.combat("Throwing " + weapon_name + " with force " + str(force), "BaseWeapon")
	
	# Store thrower reference
	thrown_by = thrower
	throw_damage = int(base_damage * throw_damage_multiplier * (force / 400.0))
	
	# Release from holder
	holder = null
	is_held = false
	
	# Enable projectile mode
	_enable_projectile_mode()
	
	# Apply throwing physics
	freeze = false
	linear_velocity = direction.normalized() * min(force, max_throw_force)
	
	# Add some spin for visual effect
	angular_velocity = randf_range(-10, 10)
	
	# Set projectile lifetime
	projectile_lifetime = 10.0
	
	# Emit thrown signal
	weapon_thrown.emit(thrower)
	
	Logger.combat(weapon_name + " thrown by " + thrower.player_data.player_name + " dealing " + str(throw_damage) + " damage", "BaseWeapon")
	
	return true

## Check if weapon has ammo remaining
func has_ammo() -> bool:
	return ammo_capacity <= 0 or ammo_current > 0

## Use one ammo (if weapon uses ammo)
func consume_ammo() -> bool:
	if ammo_capacity <= 0:
		return true  # Infinite ammo
	
	if ammo_current > 0:
		ammo_current -= 1
		if ammo_current == 0:
			ammo_depleted.emit()
		return true
	
	return false

## Get current ammo status
func get_ammo_status() -> Dictionary:
	return {
		"current": ammo_current,
		"capacity": ammo_capacity,
		"infinite": ammo_capacity <= 0
	}

## Enable thrown weapon projectile mode (projectile core feature)
func _enable_projectile_mode() -> void:
	is_thrown_projectile = true
	can_be_picked_up = true  # Allow pickup after thrown
	ricochet_count = 0
	
	# Set collision layers for projectile
	CollisionLayers.setup_thrown_weapon(self)
	
	# Enable contact monitoring for collision detection
	contact_monitor = true
	max_contacts_reported = 10

## Disable projectile mode (when weapon settles)
func _disable_projectile_mode() -> void:
	is_thrown_projectile = false
	thrown_by = null
	throw_damage = 0
	
	# Reset collision settings
	CollisionLayers.setup_weapon(self)
	
	Logger.pickup(weapon_name + " settled and available for pickup", "BaseWeapon")

## Handle thrown weapon collision with targets (projectile damage system)
func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if not is_thrown_projectile or not thrown_by:
		return
	
	# Don't hit the thrower initially
	if body == thrown_by:
		return
	
	Logger.combat("Thrown " + weapon_name + " hit " + body.name, "BaseWeapon")
	
	if body is BasePlayer:
		var target_player: BasePlayer = body as BasePlayer
		
		# Apply damage to hit player
		if target_player.player_data:
			EventBus.report_player_damage(
				target_player.player_data.player_id,
				thrown_by.player_data.player_id,
				throw_damage,
				"Thrown " + weapon_name
			)
		
		weapon_hit_target.emit(target_player, throw_damage)
		
		Logger.combat("Thrown " + weapon_name + " dealt " + str(throw_damage) + " damage to " + target_player.player_data.player_name, "BaseWeapon")
		
		# Weapon stops after hitting player
		_disable_projectile_mode()
	
	elif body.is_in_group("walls") or body.is_in_group("environment"):
		# Handle wall/environment collision
		if can_ricochet and ricochet_count < max_ricochets:
			_handle_ricochet(body)
		else:
			_disable_projectile_mode()

## Handle weapon ricochet off surfaces
func _handle_ricochet(surface: Node) -> void:
	ricochet_count += 1
	
	# Simple ricochet physics - reverse velocity with some dampening
	linear_velocity = linear_velocity.bounce(Vector2.UP) * 0.7
	angular_velocity *= 0.8
	
	Logger.combat(weapon_name + " ricocheted off " + surface.name + " (" + str(ricochet_count) + "/" + str(max_ricochets) + ")", "BaseWeapon")

## Destroy projectile when lifetime expires
func _destroy_projectile() -> void:
	Logger.system("Projectile " + weapon_name + " lifetime expired", "BaseWeapon")
	_disable_projectile_mode()

## Reset weapon for object pooling (if used)
func reset_for_pool() -> void:
	holder = null
	is_held = false
	is_thrown_projectile = false
	thrown_by = null
	throw_damage = 0
	ricochet_count = 0
	can_be_picked_up = true
	
	# Reset physics
	freeze = false
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	
	# Reset ammo if applicable
	if ammo_capacity > 0:
		ammo_current = ammo_capacity
	
	# Reset collision settings
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	
	# Reset appearance
	rotation = 0.0
	modulate = Color.WHITE

## Get weapon information for UI display
func get_weapon_info() -> Dictionary:
	return {
		"name": weapon_name,
		"damage": base_damage,
		"ammo": get_ammo_status(),
		"is_held": is_held,
		"is_thrown": is_thrown_projectile,
		"can_pickup": can_be_picked_up
	} 
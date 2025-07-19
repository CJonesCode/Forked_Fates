class_name Pistol
extends BaseWeapon

## Projectile-style pistol weapon with ranged shooting mechanics
## Fires bullets with recoil and can be thrown as dangerous projectile

# Configuration-loaded bullet properties (replaces hard-coded @export values)
var bullet_speed: float = 800.0
var bullet_lifetime: float = 5.0
var bullets_per_shot: int = 1
var spread_angle: float = 0.0
var muzzle_flash_duration: float = 0.1

# Configuration-loaded recoil properties  
var recoil_force: float = 150.0
var recoil_recovery_time: float = 0.3

# Component references (optional - may not exist in scene)
var muzzle_position: Marker2D
var muzzle_flash: Sprite2D

# Shooting state
var muzzle_flash_timer: float = 0.0

func _ready() -> void:
	super()
	
	# Load configuration-driven properties (done in super() call)
	# ammo_current is set based on config ammo_capacity
	ammo_current = ammo_capacity
	
	# Get optional component references
	muzzle_position = get_node_or_null("MuzzlePosition")
	muzzle_flash = get_node_or_null("MuzzleFlash")
	
	# Hide muzzle flash initially if it exists
	if muzzle_flash:
		muzzle_flash.visible = false
	
	Logger.system("Pistol initialized with config-driven properties: damage=" + str(base_damage) + ", ammo=" + str(ammo_capacity), "Pistol")

func _physics_process(delta: float) -> void:
	super(delta)
	
	# Handle muzzle flash timing
	if muzzle_flash_timer > 0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0 and muzzle_flash:
			muzzle_flash.visible = false

## Shoot a bullet (core projectile mechanic)
func fire_weapon() -> bool:
	if not is_held or not holder:
		return false
	
	if not has_ammo():
		Logger.debug("Pistol out of ammo", "Pistol")
		return false
	
	if not consume_ammo():
		return false
	
	Logger.combat("Pistol fired by " + holder.player_data.player_name + " (Ammo: " + str(ammo_current) + "/" + str(ammo_capacity) + ")", "Pistol")
	
	# Calculate firing direction
	var fire_direction: Vector2 = _get_fire_direction()
	
	# Spawn bullets
	for i in range(bullets_per_shot):
		_spawn_bullet(fire_direction, i)
	
	# Show muzzle flash
	_show_muzzle_flash()
	
	# Apply recoil
	_apply_recoil(fire_direction)
	
	# Emit weapon fired signal
	weapon_fired.emit()
	
	Logger.combat("Pistol shot completed - remaining ammo: " + str(ammo_current), "Pistol")
	return true

## Calculate firing direction based on player facing
func _get_fire_direction() -> Vector2:
	if not holder:
		return Vector2.RIGHT
	
	var movement_component: MovementComponent = holder.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	
	return Vector2(facing_direction, 0)

## Spawn a bullet projectile
func _spawn_bullet(base_direction: Vector2, bullet_index: int) -> void:
	# Get bullet from pool
	var bullet: Node = PoolManager.get_bullet()
	var bullet_obj = bullet  # Use generic Node to avoid type issues
	bullet_obj.is_pooled = true
	
	# Calculate spread for this bullet
	var spread_offset: float = 0.0
	if bullets_per_shot > 1 and spread_angle > 0:
		var spread_step: float = spread_angle / (bullets_per_shot - 1)
		spread_offset = -spread_angle * 0.5 + (spread_step * bullet_index)
	
	# Apply spread to direction
	var fire_direction: Vector2 = base_direction.rotated(deg_to_rad(spread_offset))
	
	# Set bullet starting position (at muzzle)
	var spawn_position: Vector2 = global_position
	if muzzle_position:
		spawn_position = muzzle_position.global_position
	
	# Add bullet to scene
	get_tree().current_scene.add_child(bullet_obj)
	
	# Initialize bullet with holder's player ID
	var holder_id: int = -1
	if holder and holder.player_data:
		holder_id = holder.player_data.player_id
	bullet_obj.initialize(fire_direction, spawn_position, holder_id)
	
	Logger.debug("Bullet spawned with direction: " + str(fire_direction), "Pistol")

## Show muzzle flash effect
func _show_muzzle_flash() -> void:
	if muzzle_flash:
		muzzle_flash.visible = true
		muzzle_flash_timer = muzzle_flash_duration

## Apply recoil to player (projectile style - strong recoil)
func _apply_recoil(fire_direction: Vector2) -> void:
	if not holder:
		return
	
	# Apply recoil force opposite to firing direction
	var recoil_direction: Vector2 = -fire_direction
	var movement_component: MovementComponent = holder.get_component(MovementComponent)
	
	if movement_component:
		# Apply recoil to player velocity
		holder.velocity += recoil_direction * recoil_force
		Logger.debug("Applied recoil force: " + str(recoil_direction * recoil_force), "Pistol")

## Reset pistol for object pooling
func reset_for_pool() -> void:
	super()
	
	# Reset pistol-specific state
	ammo_current = ammo_capacity
	muzzle_flash_timer = 0.0
	
	if muzzle_flash:
		muzzle_flash.visible = false
	
	Logger.debug("Pistol reset for pooling", "Pistol")

## Get weapon status for UI (projectile style)
func get_weapon_info() -> Dictionary:
	var info = super.get_weapon_info()
	info["ammo_current"] = ammo_current
	info["ammo_capacity"] = ammo_capacity
	info["bullets_per_shot"] = bullets_per_shot
	info["can_fire"] = has_ammo()
	return info

## Override throw behavior for enhanced pistol projectiles
func throw_weapon(direction: Vector2, force: float, thrower_id: int) -> bool:
	var can_throw = super.throw_weapon(direction, force, thrower_id)
	
	if can_throw:
		# Projectile enhancement: Thrown pistols are especially dangerous when loaded
		if ammo_current > 0:
			Logger.combat("Loaded pistol thrown - extra dangerous!", "Pistol")
			# Bonus damage for loaded pistols (projectile style)
			throw_damage = int(throw_damage * 1.5)
	
	return can_throw

## Override to apply pistol-specific configuration properties
func _apply_weapon_config(config: ItemConfig) -> void:
	super._apply_weapon_config(config)
	
	# Apply pistol-specific properties from config
	bullet_speed = config.bullet_speed
	bullets_per_shot = config.bullets_per_shot
	spread_angle = config.spread_angle
	muzzle_flash_duration = config.muzzle_flash_duration
	recoil_force = config.recoil_force
	
	Logger.system("Applied pistol config: bullet_speed=" + str(bullet_speed) + ", recoil=" + str(recoil_force), "Pistol") 

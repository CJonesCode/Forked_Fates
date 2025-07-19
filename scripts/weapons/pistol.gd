class_name Pistol
extends BaseWeapon

## Projectile-style pistol weapon with ranged shooting mechanics
## Fires bullets with recoil and can be thrown as dangerous projectile

# Bullet properties
@export var bullet_speed: float = 800.0
@export var bullet_lifetime: float = 5.0
@export var bullets_per_shot: int = 1
@export var spread_angle: float = 0.0
@export var muzzle_flash_duration: float = 0.1

# Recoil properties  
@export var recoil_force: float = 150.0
@export var recoil_recovery_time: float = 0.3

# Component references
@onready var muzzle_position: Marker2D = $MuzzlePosition
@onready var muzzle_flash: Sprite2D = $MuzzleFlash

# Shooting state
var muzzle_flash_timer: float = 0.0

func _ready() -> void:
	super()
	
	# Set weapon properties (projectile naming)
	weapon_name = "Pistol"
	fire_rate = 1.5
	base_damage = 2  # Higher damage for projectile feel
	ammo_capacity = 6
	ammo_current = ammo_capacity
	
	# Throwing properties
	throw_damage_multiplier = 1.3
	can_ricochet = false
	
	# Hide muzzle flash initially
	if muzzle_flash:
		muzzle_flash.visible = false
	
	Logger.system("Pistol initialized with projectile mechanics", "Pistol")

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
	var bullet_obj: Bullet = bullet as Bullet
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
	
	# Initialize bullet
	bullet_obj.initialize(fire_direction, spawn_position, holder)
	
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
func throw_weapon(direction: Vector2, force: float, thrower: BasePlayer) -> bool:
	var can_throw = super.throw_weapon(direction, force, thrower)
	
	if can_throw:
		# Projectile enhancement: Thrown pistols are especially dangerous when loaded
		if ammo_current > 0:
			Logger.combat("Loaded pistol thrown - extra dangerous!", "Pistol")
			# Bonus damage for loaded pistols (projectile style)
			throw_damage = int(throw_damage * 1.5)
	
	return can_throw 

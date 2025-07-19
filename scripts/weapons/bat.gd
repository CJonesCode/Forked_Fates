class_name BatWeapon
extends BaseWeapon

## Projectile-style bat melee weapon with swing mechanics
## Features knockback attacks and spinning throw projectiles

# Configuration-loaded swing properties (replaces hard-coded @export values)
var swing_range: float = 80.0
var swing_angle: float = 120.0
var swing_duration: float = 0.3
var swing_recovery_time: float = 0.2

# Configuration-loaded knockback and damage properties
var knockback_force: float = 300.0
var swing_damage: int = 3

# Component references (optional - may not exist in scene)
var swing_area: Area2D
var swing_collision: CollisionShape2D
var swing_audio: AudioStreamPlayer2D

# Swing state
var is_swinging: bool = false
var swing_timer: float = 0.0
var swing_targets: Array[BasePlayer] = []

func _ready() -> void:
	super()
	
	# Get optional component references
	swing_area = get_node_or_null("SwingArea")
	swing_collision = get_node_or_null("SwingArea/CollisionShape2D") if swing_area else null
	swing_audio = get_node_or_null("SwingAudio")
	
	# Set weapon properties (projectile naming)
	item_name = "Bat"
	fire_rate = 1.2
	base_damage = 3  # Higher melee damage for projectile feel
	ammo_capacity = -1  # Infinite "ammo" for melee
	
	# Throwing properties - bats are excellent projectiles
	throw_damage_multiplier = 2.0
	can_ricochet = true
	max_ricochets = 1
	
	# Setup swing area if it exists
	if swing_area:
		# Make sure swing area doesn't trigger initially
		swing_area.set_deferred("monitoring", false)
		
		# Connect to area detection
		if not swing_area.body_entered.is_connected(_on_swing_area_entered):
			swing_area.body_entered.connect(_on_swing_area_entered)
		
		# Setup collision layer for swing attacks
		CollisionLayers.setup_melee_attack(swing_area)
	
	Logger.system("Bat initialized with melee mechanics", "Bat")

func _physics_process(delta: float) -> void:
	super(delta)
	
	# Handle swing timing
	if is_swinging:
		swing_timer += delta
		
		# Enable collision detection during swing
		if swing_timer > 0.1 and swing_timer < swing_duration - 0.1:
			if swing_area:
				swing_area.monitoring = true
		else:
			if swing_area:
				swing_area.monitoring = false
		
		# End swing
		if swing_timer >= swing_duration:
			_end_swing()

## Perform bat swing (projectile melee combat)
func fire_weapon() -> bool:
	if not is_held or not holder or is_swinging:
		return false
	
	Logger.combat("Bat swung by " + holder.player_data.player_name, "Bat")
	
	# Start swing
	is_swinging = true
	swing_timer = 0.0
	swing_targets.clear()
	
	# Play swing audio
	if swing_audio:
		swing_audio.play()
	
	# Start swing animation
	_animate_swing()
	
	# Emit weapon fired signal
	weapon_fired.emit()
	
	Logger.combat("Bat swing initiated", "Bat")
	return true

## Calculate swing direction based on player facing
func _get_swing_direction() -> Vector2:
	if not holder:
		return Vector2.RIGHT
	
	var movement_component: MovementComponent = holder.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	
	return Vector2(facing_direction, 0)

## Animate swing motion
func _animate_swing() -> void:
	if not is_held or not holder:
		return
	
	# Get swing direction
	var swing_direction: Vector2 = _get_swing_direction()
	
	# Create swing tween for visual feedback
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Swing rotation animation
	var start_rotation = 0.0
	var end_rotation = deg_to_rad(swing_angle) * swing_direction.x
	
	tween.tween_method(_update_swing_rotation, start_rotation, end_rotation, swing_duration * 0.6)
	tween.tween_method(_update_swing_rotation, end_rotation, start_rotation, swing_duration * 0.4)
	
	# Enhanced swing animation for projectile feel
	Logger.debug("Bat swing animation started", "Bat")

## Update swing rotation during animation
func _update_swing_rotation(angle: float) -> void:
	rotation = angle

## End the swing
func _end_swing() -> void:
	is_swinging = false
	swing_timer = 0.0
	
	# Disable swing collision
	if swing_area:
		swing_area.monitoring = false
	
	# Reset rotation
	rotation = 0.0
	
	Logger.debug("Bat swing completed", "Bat")

## Handle swing area collision with targets
func _on_swing_area_entered(body: Node2D) -> void:
	if not is_swinging or not holder:
		return
	
	# Don't hit the wielder
	if body == holder:
		return
	
	# Only hit players
	if not body is BasePlayer:
		return
	
	var target_player: BasePlayer = body as BasePlayer
	
	# Don't hit the same target multiple times in one swing
	if target_player in swing_targets:
		return
	
	swing_targets.append(target_player)
	
	Logger.combat("Bat hit " + target_player.player_data.player_name, "Bat")
	
	# Apply damage through damage system
	if target_player.player_data:
		EventBus.report_player_damage(
			target_player.player_data.player_id,
			holder.player_data.player_id,
			swing_damage,
			"Bat Swing"
		)
	
	# Apply knockback force to target (projectile physics)
	_apply_knockback(target_player)
	
	# Emit hit signal
	weapon_hit_target.emit(target_player, swing_damage)

## Apply knockback force to target (projectile physics)
func _apply_knockback(target: BasePlayer) -> void:
	if not target or not holder:
		return
	
	# Calculate knockback direction (away from wielder)
	var knockback_direction: Vector2 = (target.global_position - holder.global_position).normalized()
	
	# Apply knockback force (projectile style - strong knockback)
	target.velocity += knockback_direction * knockback_force
	
	# Add slight upward component for satisfying arc
	target.velocity.y -= knockback_force * 0.3
	
	Logger.combat("Applied " + str(knockback_force) + " knockback to " + target.player_data.player_name, "Bat")

## Reset bat for object pooling
func reset_for_pool() -> void:
	super()
	
	# Reset bat-specific state
	is_swinging = false
	swing_timer = 0.0
	swing_targets.clear()
	rotation = 0.0
	
	# Disable swing area
	if swing_area:
		swing_area.monitoring = false
	
	Logger.debug("Bat reset for pooling", "Bat")

## Get weapon status for UI (projectile style)
func get_weapon_info() -> Dictionary:
	var info = super.get_weapon_info()
	info["swing_damage"] = swing_damage
	info["knockback_force"] = knockback_force
	info["is_swinging"] = is_swinging
	info["swing_range"] = swing_range
	return info

## Override throw behavior for enhanced bat projectiles
func throw_weapon(direction: Vector2, force: float, thrower_id: int) -> bool:
	var can_throw = super.throw_weapon(direction, force, thrower_id)
	
	if can_throw:
		# Projectile enhancement: Thrown bats spin and deal massive damage
		Logger.combat("Bat thrown - spinning projectile mode!", "Bat")
		
		# Add spin to thrown bat for projectile visual effect
		angular_velocity = 20.0  # Fast spin for visual impact
		
		# Enhance damage for thrown bat projectiles
		throw_damage = int(base_damage * throw_damage_multiplier * 1.2)
	
	return can_throw

## Override to apply bat-specific configuration properties
func _apply_weapon_config(config: ItemConfig) -> void:
	super._apply_weapon_config(config)
	
	# Apply bat-specific properties from config
	swing_range = config.swing_range
	swing_damage = config.swing_damage
	knockback_force = config.knockback_force
	
	Logger.system("Applied bat config: swing_damage=" + str(swing_damage) + ", knockback=" + str(knockback_force), "Bat") 
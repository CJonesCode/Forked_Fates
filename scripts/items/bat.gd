class_name Bat
extends BaseItem

## Bat melee weapon with swing mechanics
## Features close-range combat and knockback effects

# Bat configuration
@export var damage: int = 2
@export var swing_range: float = 80.0
@export var knockback_force: float = 300.0
@export var swing_duration: float = 0.4

# Components
@onready var attack_area: Area2D = $AttackArea
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var swing_audio: AudioStreamPlayer2D = $SwingAudio

# State
var is_swinging: bool = false
var swing_timer: float = 0.0
var swing_targets: Array[BasePlayer] = []

func _ready() -> void:
	super()
	
	# Set item properties
	item_name = "Bat"
	item_description = "A sturdy melee weapon for close combat"
	use_cooldown = 0.8  # Swing rate
	
	# Setup attack area
	if attack_area:
		CollisionLayers.setup_attack_area(attack_area)
		# Check before connecting to prevent duplicate connections (standards compliance)
		if not attack_area.body_entered.is_connected(_on_attack_area_entered):
			attack_area.body_entered.connect(_on_attack_area_entered)
		if not attack_area.body_exited.is_connected(_on_attack_area_exited):
			attack_area.body_exited.connect(_on_attack_area_exited)
		
		# Disable attack area initially
		attack_area.monitoring = false
	
	Logger.item(item_name, "initialized", "Bat")

func _process(delta: float) -> void:
	if is_swinging:
		swing_timer += delta
		
		# End swing after duration
		if swing_timer >= swing_duration:
			_end_swing()

## Override use implementation for swinging
func _use_implementation() -> bool:
	if is_swinging:
		return false
	
	return _swing()

## Perform bat swing
func _swing() -> bool:
	if not holder or is_swinging:
		return false
	
	# Start swing
	is_swinging = true
	swing_timer = 0.0
	swing_targets.clear()
	
	# Enable attack area
	if attack_area:
		attack_area.monitoring = true
	
	# Play swing audio
	if swing_audio:
		swing_audio.play()
	
	# Apply swing animation/rotation
	_start_swing_animation()
	
	var holder_name: String = holder.player_data.player_name if holder.player_data else "Unknown Player"
	Logger.combat(holder_name + " swings the bat!", "Bat")
	return true

## End the swing
func _end_swing() -> void:
	is_swinging = false
	swing_timer = 0.0
	swing_targets.clear()
	
	# Disable attack area
	if attack_area:
		attack_area.monitoring = false
	
	# Reset visual state
	_end_swing_animation()

## Start swing animation
func _start_swing_animation() -> void:
	# TODO: Add visual swing animation
	# For now, just rotate the bat
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "rotation_degrees", -45, swing_duration * 0.3)
		tween.tween_property(sprite, "rotation_degrees", 45, swing_duration * 0.4)
		tween.tween_property(sprite, "rotation_degrees", 0, swing_duration * 0.3)

## End swing animation
func _end_swing_animation() -> void:
	# Reset rotation
	if sprite:
		sprite.rotation_degrees = 0

## Handle target entering attack range
func _on_attack_area_entered(body: Node2D) -> void:
	if not is_swinging or not holder:
		return
	
	# Check if it's a valid target
	if body is BasePlayer and body != holder:
		var target_player = body as BasePlayer
		
		# Don't hit dead players or targets already hit this swing
		if target_player.current_state == BasePlayer.PlayerState.DEAD or target_player in swing_targets:
			return
		
		# Add to hit targets
		swing_targets.append(target_player)
		
		# Report damage to minigame instead of applying directly
		var attacker_id = holder.player_data.player_id if holder.player_data else -1
		var target_id = target_player.player_data.player_id if target_player.player_data else -1
		EventBus.report_player_damage(target_id, attacker_id, damage, "Bat")
		
		# Apply knockback (this can stay direct since it's a physics effect)
		_apply_knockback(target_player)
		
		var target_player_name: String = target_player.player_data.player_name if target_player.player_data else "Unknown Player"
		Logger.combat("Bat reported " + str(damage) + " damage from Player " + str(attacker_id) + " to " + target_player_name, "Bat")

## Handle target leaving attack range
func _on_attack_area_exited(body: Node2D) -> void:
	# Target moved out of range
	pass

## Apply knockback force to target
func _apply_knockback(target: BasePlayer) -> void:
	if not target or not holder:
		return
	
	# Use weapon's aiming direction for consistent knockback
	var swing_direction = _get_aim_direction()
	
	# If no aiming direction, fall back to position-based calculation
	var knockback_direction: Vector2
	if swing_direction.length() > 0.1:
		knockback_direction = swing_direction
	else:
		knockback_direction = (target.global_position - holder.global_position).normalized()
	
	# Apply knockback force
	var knockback_velocity = knockback_direction * knockback_force
	target.velocity += knockback_velocity
	
	# Add some upward force for dramatic effect
	target.velocity.y -= knockback_force * 0.3
	
	var target_name: String = target.player_data.player_name if target.player_data else "Unknown Player"
	Logger.combat("Applied knockback to " + target_name, "Bat")

## Override base item aiming - bat uses player facing for swing direction
func _get_aim_direction() -> Vector2:
	if not holder:
		return Vector2.ZERO
	
	# Get facing direction from player's MovementComponent
	var movement_component: MovementComponent = holder.get_component(MovementComponent)
	var facing_direction: int = movement_component.facing_direction if movement_component else 1
	
	# Bat-specific aiming: follow player's facing direction for swing orientation
	return Vector2(facing_direction, 0)

## Get weapon status for UI
func get_weapon_status() -> Dictionary:
	return {
		"is_swinging": is_swinging,
		"swing_progress": swing_timer / swing_duration if is_swinging else 0.0,
		"damage": damage
	}

## Override item info to include weapon status
func get_item_info() -> Dictionary:
	var info = super.get_item_info()
	info["damage"] = damage
	info["is_swinging"] = is_swinging
	return info

## Cleanup bat properly to prevent RID leaks (required by standards)
func _exit_tree() -> void:
	# Disconnect attack area signals if connected
	if attack_area:
		if attack_area.body_entered.is_connected(_on_attack_area_entered):
			attack_area.body_entered.disconnect(_on_attack_area_entered)
		if attack_area.body_exited.is_connected(_on_attack_area_exited):
			attack_area.body_exited.disconnect(_on_attack_area_exited)
	
	# Clear swing targets and state
	swing_targets.clear()
	is_swinging = false
	
	# Clear holder reference
	if holder:
		holder = null
	
	# Clear audio references
	if swing_audio:
		swing_audio = null
	
	Logger.debug("Bat cleanup completed", "Bat") 
class_name Pistol
extends BaseItem

## Pistol weapon with ranged shooting mechanics
## Features ammo system and projectile firing

# Pistol configuration
@export var max_ammo: int = 6
@export var damage: int = 1
@export var bullet_speed: float = 800.0
@export var shoot_range: float = 500.0
@export var reload_time: float = 2.0
@export var recoil_force: float = 100.0

# Bullet scene
@export var bullet_scene: PackedScene

# State
var current_ammo: int
var is_reloading: bool = false
var reload_timer: float = 0.0

# Components for shooting
@onready var muzzle_point: Marker2D = $MuzzlePoint
@onready var shot_audio: AudioStreamPlayer2D = $ShotAudio

func _ready() -> void:
	super._ready()
	
	# Initialize default values from config if not overridden
	if bullet_speed == 800.0:  # Default value, use config
		bullet_speed = game_config.default_bullet_speed
	if use_cooldown == 0.5:  # BaseItem default, use weapon config
		use_cooldown = game_config.default_weapon_cooldown
	if recoil_force == 100.0:  # Default value, use config
		recoil_force = game_config.default_recoil_force
	
	# Set item properties
	item_name = "Pistol"
	item_description = "A reliable firearm with limited ammo"
	
	# Initialize ammo
	current_ammo = max_ammo
	
	# Load bullet scene if not set
	if not bullet_scene:
		bullet_scene = preload("res://scenes/items/bullet.tscn")
	
	print("Pistol initialized with ", current_ammo, " rounds")

func _process(delta: float) -> void:
	if is_reloading:
		reload_timer += delta
		if reload_timer >= reload_time:
			_finish_reload()

## Override use implementation for shooting
func _use_implementation() -> bool:
	if is_reloading:
		return false
	
	if current_ammo <= 0:
		_start_reload()
		return false
	
	return _shoot()

## Shoot a bullet
func _shoot() -> bool:
	if not holder or current_ammo <= 0:
		return false
	
	# Get shoot direction (based on player facing or mouse position)
	var shoot_direction = _get_shoot_direction()
	
	if shoot_direction == Vector2.ZERO:
		return false
	
	# Create bullet
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		
		# Add bullet to scene
		var scene_root = holder.get_tree().current_scene
		scene_root.add_child(bullet)
		
		# Position bullet at muzzle
		var muzzle_pos = global_position
		if muzzle_point:
			muzzle_pos = muzzle_point.global_position
		
		bullet.global_position = muzzle_pos
		
		# Set bullet properties
		if bullet.has_method("initialize"):
			bullet.initialize(shoot_direction * bullet_speed, damage, holder)
	
	# Consume ammo
	current_ammo -= 1
	
	# Play shot audio
	if shot_audio:
		shot_audio.play()
	
	# Apply recoil to player
	if holder:
		var recoil_velocity = -shoot_direction * recoil_force
		holder.velocity += recoil_velocity
	
	print(holder.player_data.player_name, " fired pistol! Ammo: ", current_ammo)
	
	# Auto-reload if empty
	if current_ammo <= 0:
		_start_reload()
	
	return true

## Override base item aiming - pistol follows player facing direction
func _get_aim_direction() -> Vector2:
	if not holder:
		return Vector2.ZERO
	
	# Pistol-specific aiming: simply follow player's facing direction
	return Vector2(holder.facing_direction, 0)

## Get shooting direction (uses weapon's aiming implementation)
func _get_shoot_direction() -> Vector2:
	return _get_aim_direction()

## Start reload process
func _start_reload() -> void:
	if is_reloading or current_ammo >= max_ammo:
		return
	
	is_reloading = true
	reload_timer = 0.0
	print(holder.player_data.player_name, " is reloading pistol...")

## Finish reload process
func _finish_reload() -> void:
	is_reloading = false
	reload_timer = 0.0
	current_ammo = max_ammo
	print(holder.player_data.player_name, " finished reloading pistol")

## Get weapon status for UI
func get_weapon_status() -> Dictionary:
	return {
		"ammo": current_ammo,
		"max_ammo": max_ammo,
		"is_reloading": is_reloading,
		"reload_progress": reload_timer / reload_time if is_reloading else 0.0
	}

## Override item info to include ammo status
func get_item_info() -> Dictionary:
	var info = super.get_item_info()
	info["ammo"] = current_ammo
	info["max_ammo"] = max_ammo
	info["is_reloading"] = is_reloading
	return info 
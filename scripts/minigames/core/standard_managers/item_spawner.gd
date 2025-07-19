class_name ItemSpawner
extends Node

## Standard manager for spawning and managing weapons in physics-based minigames
## Handles weapon creation, positioning, respawning, and cleanup
## Pure projectile weapon system - BaseWeapon only

# Configuration
@export var spawn_interval: float = 5.0
@export var max_items: int = 10
@export var auto_respawn: bool = true

# Projectile weapon scenes
var weapon_scenes: Dictionary = {
	"pistol": preload("res://scenes/weapons/pistol.tscn"),
	"bat": preload("res://scenes/weapons/bat.tscn")
}

# Spawn management
var spawn_points: Array[Vector2] = []
var spawned_weapons: Array[BaseWeapon] = []
var spawn_timer: float = 0.0
var is_spawning: bool = false

# Signals - projectile system style
signal weapon_spawned(weapon: BaseWeapon)
signal weapon_collected(weapon: BaseWeapon, player_id: int)
signal max_items_reached()

func _ready() -> void:
	Logger.system("ItemSpawner ready with projectile weapon system", "ItemSpawner")

## Setup spawn points from positions array
func setup_spawn_points(points: Array[Vector2]) -> void:
	spawn_points = points.duplicate()
	Logger.system("ItemSpawner configured with " + str(spawn_points.size()) + " spawn points", "ItemSpawner")

## Spawn initial weapons at start of minigame
func spawn_initial_items() -> void:
	Logger.game_flow("Spawning initial weapons", "ItemSpawner")
	Logger.system("DEBUG: Available weapon spawn points: " + str(spawn_points.size()), "ItemSpawner")
	Logger.system("DEBUG: Max weapons allowed: " + str(max_items), "ItemSpawner")
	Logger.system("DEBUG: Available weapon types: " + str(weapon_scenes.keys()), "ItemSpawner")
	
	var weapons_to_spawn = min(spawn_points.size(), max_items)
	Logger.system("DEBUG: Will spawn " + str(weapons_to_spawn) + " weapons", "ItemSpawner")
	
	for i in range(weapons_to_spawn):
		var weapon_type: String = _get_random_weapon_type()
		Logger.system("DEBUG: Spawning weapon " + str(i) + ": " + weapon_type + " at " + str(spawn_points[i]), "ItemSpawner")
		var spawn_result = spawn_weapon(weapon_type, spawn_points[i]) != null
		Logger.system("DEBUG: Spawn result: " + str(spawn_result), "ItemSpawner")
	
	Logger.system("DEBUG: Total spawned weapons: " + str(spawned_weapons.size()), "ItemSpawner")

## Process automatic respawning
func _process(delta: float) -> void:
	if not is_spawning or not auto_respawn:
		return
	
	spawn_timer -= delta
	if spawn_timer <= 0 and spawned_weapons.size() < max_items:
		_spawn_random_weapon()
		spawn_timer = spawn_interval

## Spawn a specific weapon at a position
func spawn_weapon(weapon_type: String, position: Vector2) -> BaseWeapon:
	if not weapon_scenes.has(weapon_type):
		Logger.warning("Unknown weapon type: " + weapon_type, "ItemSpawner")
		return null
	
	var weapon_scene: PackedScene = weapon_scenes[weapon_type]
	var weapon_instance: BaseWeapon = weapon_scene.instantiate()
	
	get_parent().add_child(weapon_instance)
	weapon_instance.global_position = position
	
	spawned_weapons.append(weapon_instance)
	
	Logger.system("Spawned weapon " + weapon_type + " at " + str(position), "ItemSpawner")
	weapon_spawned.emit(weapon_instance)
	
	if spawned_weapons.size() >= max_items:
		max_items_reached.emit()
	
	return weapon_instance

## Start automatic spawning
func start_spawning() -> void:
	is_spawning = true
	spawn_timer = spawn_interval
	Logger.system("Started automatic weapon spawning", "ItemSpawner")

## Stop automatic spawning
func stop_spawning() -> void:
	is_spawning = false
	Logger.system("Stopped automatic weapon spawning", "ItemSpawner")

## Cleanup all spawned weapons
func cleanup_items() -> void:
	Logger.system("Cleaning up all spawned weapons", "ItemSpawner")
	
	for weapon in spawned_weapons:
		if weapon and is_instance_valid(weapon):
			weapon.queue_free()
	spawned_weapons.clear()

## Get random weapon type
func _get_random_weapon_type() -> String:
	var types: Array = weapon_scenes.keys()
	return types[randi() % types.size()]

## Spawn random weapon at random position
func _spawn_random_weapon() -> void:
	if spawn_points.is_empty():
		return
	
	var weapon_type: String = _get_random_weapon_type()
	var position: Vector2 = spawn_points[randi() % spawn_points.size()]
	spawn_weapon(weapon_type, position)

## Set spawn rate modifier
func set_spawn_rate(rate_multiplier: float) -> void:
	spawn_interval = spawn_interval / rate_multiplier
	Logger.system("Weapon spawn rate modified by " + str(rate_multiplier) + "x", "ItemSpawner")

## Get spawning statistics
func get_spawn_statistics() -> Dictionary:
	return {
		"total_weapons": spawned_weapons.size(),
		"spawn_points_available": spawn_points.size(),
		"max_items_limit": max_items,
		"auto_respawn": auto_respawn
	}

## Get all spawned weapons
func get_spawned_weapons() -> Array[BaseWeapon]:
	return spawned_weapons.duplicate()

## Force spawn specific weapon for testing
func force_spawn_weapon(weapon_type: String, position: Vector2 = Vector2.ZERO) -> BaseWeapon:
	if position == Vector2.ZERO and not spawn_points.is_empty():
		position = spawn_points[0]
	
	Logger.system("Force spawning weapon: " + weapon_type + " at " + str(position), "ItemSpawner")
	return spawn_weapon(weapon_type, position) 
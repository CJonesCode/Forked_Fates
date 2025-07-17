class_name ItemSpawner
extends Node

## Standard manager for spawning and managing items in physics-based minigames
## Handles item creation, positioning, respawning, and cleanup

# Configuration
@export var spawn_interval: float = 5.0
@export var max_items: int = 10
@export var auto_respawn: bool = true

# Item scenes
var item_scenes: Dictionary = {
	"pistol": preload("res://scenes/items/pistol.tscn"),
	"bat": preload("res://scenes/items/bat.tscn")
}

# Spawn management
var spawn_points: Array[Vector2] = []
var spawned_items: Array[BaseItem] = []
var spawn_timer: float = 0.0
var is_spawning: bool = false

# Signals
signal item_spawned(item: BaseItem)
signal item_collected(item: BaseItem, player_id: int)
signal max_items_reached()

func _ready() -> void:
	Logger.system("ItemSpawner ready", "ItemSpawner")

## Setup spawn points from positions array
func setup_spawn_points(points: Array[Vector2]) -> void:
	spawn_points = points.duplicate()
	Logger.system("ItemSpawner configured with " + str(spawn_points.size()) + " spawn points", "ItemSpawner")

## Spawn initial items at start of minigame
func spawn_initial_items() -> void:
	Logger.game_flow("Spawning initial items", "ItemSpawner")
	Logger.system("DEBUG: Available item spawn points: " + str(spawn_points.size()), "ItemSpawner")
	Logger.system("DEBUG: Max items allowed: " + str(max_items), "ItemSpawner")
	Logger.system("DEBUG: Available item types: " + str(item_scenes.keys()), "ItemSpawner")
	
	var items_to_spawn = min(spawn_points.size(), max_items)
	Logger.system("DEBUG: Will spawn " + str(items_to_spawn) + " items", "ItemSpawner")
	
	for i in range(items_to_spawn):
		var item_type: String = _get_random_item_type()
		Logger.system("DEBUG: Spawning item " + str(i) + ": " + item_type + " at " + str(spawn_points[i]), "ItemSpawner")
		var spawn_result = spawn_item(item_type, spawn_points[i])
		Logger.system("DEBUG: Item spawn result: " + str(spawn_result != null), "ItemSpawner")
	
	Logger.system("DEBUG: Total spawned items: " + str(spawned_items.size()), "ItemSpawner")

## Process automatic respawning
func _process(delta: float) -> void:
	if not is_spawning or not auto_respawn:
		return
	
	spawn_timer -= delta
	if spawn_timer <= 0 and spawned_items.size() < max_items:
		_spawn_random_item()
		spawn_timer = spawn_interval

## Spawn a specific item at a position
func spawn_item(item_type: String, position: Vector2) -> BaseItem:
	if not item_scenes.has(item_type):
		Logger.warning("Unknown item type: " + item_type, "ItemSpawner")
		return null
	
	var item_scene: PackedScene = item_scenes[item_type]
	var item_instance: BaseItem = item_scene.instantiate()
	
	get_parent().add_child(item_instance)
	item_instance.global_position = position
	
	spawned_items.append(item_instance)
	
	Logger.system("Spawned " + item_type + " at " + str(position), "ItemSpawner")
	item_spawned.emit(item_instance)
	
	if spawned_items.size() >= max_items:
		max_items_reached.emit()
	
	return item_instance

## Start automatic spawning
func start_spawning() -> void:
	is_spawning = true
	spawn_timer = spawn_interval

## Stop automatic spawning
func stop_spawning() -> void:
	is_spawning = false

## Cleanup all spawned items
func cleanup_items() -> void:
	Logger.system("Cleaning up all spawned items", "ItemSpawner")
	
	for item in spawned_items:
		if item and is_instance_valid(item):
			item.queue_free()
	
	spawned_items.clear()

## Get random item type
func _get_random_item_type() -> String:
	var types: Array = item_scenes.keys()
	return types[randi() % types.size()]

## Spawn random item at random position
func _spawn_random_item() -> void:
	if spawn_points.is_empty():
		return
	
	var item_type: String = _get_random_item_type()
	var position: Vector2 = spawn_points[randi() % spawn_points.size()]
	spawn_item(item_type, position)

## Set spawn rate modifier
func set_spawn_rate(rate_multiplier: float) -> void:
	spawn_interval = spawn_interval / rate_multiplier
	Logger.system("Item spawn rate modified by " + str(rate_multiplier) + "x", "ItemSpawner") 
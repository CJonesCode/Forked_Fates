extends Node

## Global Pool Manager for Object Pooling
## Provides centralized access to object pools with pre-configured settings

# Global object pool instance
var object_pool: ObjectPool

# Pre-configured pool settings
var pool_configurations: Dictionary = {
	"res://scenes/items/bullet.tscn": {
		"max_size": 50,
		"initial_size": 10
	},
	"res://scenes/items/bat.tscn": {
		"max_size": 20,
		"initial_size": 5
	},
	"res://scenes/items/pistol.tscn": {
		"max_size": 20,
		"initial_size": 5
	}
}

func _ready() -> void:
	# Create object pool instance
	object_pool = ObjectPool.new()
	add_child(object_pool)
	
	# Pre-warm commonly used pools
	_initialize_pools()
	
	Logger.system("PoolManager initialized with " + str(pool_configurations.size()) + " pre-configured pools", "PoolManager")

## Initialize and pre-warm pools
func _initialize_pools() -> void:
	for scene_path in pool_configurations.keys():
		var config: Dictionary = pool_configurations[scene_path]
		var max_size: int = config.get("max_size", 100)
		var initial_size: int = config.get("initial_size", 10)
		
		# Configure pool settings
		object_pool.configure_pool(scene_path, max_size, initial_size)
		
		Logger.debug("Configured pool for " + scene_path + " (max: " + str(max_size) + ", initial: " + str(initial_size) + ")", "PoolManager")

## Get object from pool - convenience method
func get_pooled_object(scene_path: String) -> Node:
	return object_pool.get_object(scene_path)

## Return object to pool - convenience method
func return_pooled_object(object: Node, scene_path: String) -> bool:
	return object_pool.return_object(object, scene_path)

## Get bullet from pool
func get_bullet() -> Node:
	return get_pooled_object("res://scenes/items/bullet.tscn")

## Return bullet to pool
func return_bullet(bullet: Node) -> bool:
	return return_pooled_object(bullet, "res://scenes/items/bullet.tscn")

## Get bat from pool  
func get_bat() -> Node:
	return get_pooled_object("res://scenes/items/bat.tscn")

## Return bat to pool
func return_bat(bat: Node) -> bool:
	return return_pooled_object(bat, "res://scenes/items/bat.tscn")

## Get pistol from pool
func get_pistol() -> Node:
	return get_pooled_object("res://scenes/items/pistol.tscn")

## Return pistol to pool
func return_pistol(pistol: Node) -> bool:
	return return_pooled_object(pistol, "res://scenes/items/pistol.tscn")

## Add new pool configuration
func add_pool_configuration(scene_path: String, max_size: int, initial_size: int = 0) -> void:
	pool_configurations[scene_path] = {
		"max_size": max_size,
		"initial_size": initial_size
	}
	
	# Configure the pool immediately
	object_pool.configure_pool(scene_path, max_size, initial_size)
	Logger.system("Added pool configuration for: " + scene_path, "PoolManager")

## Get pool statistics for debugging
func get_pool_statistics() -> Dictionary:
	return object_pool.get_pool_stats()

## Clear all pools (useful for scene transitions)
func clear_all_pools() -> int:
	return object_pool.clear_all_pools()

## Pre-warm specific pool
func prewarm_pool(scene_path: String, count: int) -> void:
	object_pool.prewarm_pool(scene_path, count)

## Print pool statistics for debugging
func print_pool_stats() -> void:
	var stats: Dictionary = get_pool_statistics()
	Logger.system("=== Pool Statistics ===", "PoolManager")
	
	for scene_path in stats.keys():
		var scene_stats: Dictionary = stats[scene_path]
		Logger.system(scene_path + ":", "PoolManager")
		Logger.system("  Pool Size: " + str(scene_stats.pool_size) + "/" + str(scene_stats.max_size), "PoolManager")
		Logger.system("  Created: " + str(scene_stats.created), "PoolManager")
		Logger.system("  Retrieved: " + str(scene_stats.retrieved), "PoolManager")
		Logger.system("  Returned: " + str(scene_stats.returned), "PoolManager")
		Logger.system("  Destroyed: " + str(scene_stats.destroyed), "PoolManager")

## Handle scene cleanup
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		clear_all_pools() 

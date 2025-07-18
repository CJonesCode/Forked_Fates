extends Node

## Global Pool Manager for Object Pooling
## Provides centralized access to object pools with pre-configured settings

# Global object pool instance
var object_pool: ObjectPool

# Pre-configured pool settings by item ID
var pool_configurations: Dictionary = {
	"bullet": {
		"max_size": 50,
		"initial_size": 0  # No pre-warming - lazy loading
	},
	"bat": {
		"max_size": 20,
		"initial_size": 0  # No pre-warming - lazy loading
	},
	"pistol": {
		"max_size": 20,
		"initial_size": 0  # No pre-warming - lazy loading
	}
}

func _ready() -> void:
	# Create object pool instance
	object_pool = ObjectPool.new()
	add_child(object_pool)
	
	# Remove eager pool initialization - use lazy initialization instead
	# _initialize_pools()  # REMOVED: No longer pre-warm pools on startup
	
	Logger.system("PoolManager initialized with lazy pool configuration", "PoolManager")

## Initialize pools lazily - only when first accessed (scene path version)
func _ensure_pool_configured(scene_path: String) -> void:
	# This method handles raw scene paths for backward compatibility
	# For new code, prefer using get_item() with item IDs
	if not object_pool.pools.has(scene_path):
		# Configure with default settings if not in configurations
		var max_size: int = 100
		var initial_size: int = 0
		
		object_pool.configure_pool(scene_path, max_size, initial_size)
		Logger.debug("Lazily configured pool for scene path: " + scene_path, "PoolManager")

## Initialize pools lazily for item IDs - preferred method
func _ensure_item_pool_configured(item_id: String) -> String:
	var item_config: ItemConfig = ConfigManager.get_item_config(item_id)
	if not item_config:
		Logger.error("Cannot configure pool - item config not found: " + item_id, "PoolManager")
		return ""
	
	var scene_path: String = item_config.scene_path
	if not object_pool.pools.has(scene_path):
		# Get pool settings from configuration or use defaults
		var max_size: int = 100
		var initial_size: int = 0
		
		if pool_configurations.has(item_id):
			var config: Dictionary = pool_configurations[item_id]
			max_size = config.get("max_size", 100)
			initial_size = config.get("initial_size", 0)
		
		object_pool.configure_pool(scene_path, max_size, initial_size)
		Logger.debug("Lazily configured pool for item: " + item_id + " at " + scene_path, "PoolManager")
	
	return scene_path

## Initialize and pre-warm pools - DEPRECATED, kept for compatibility
func _initialize_pools() -> void:
	Logger.warning("_initialize_pools() called - this method is deprecated in favor of lazy initialization", "PoolManager")
	# This method is now a no-op to prevent eager initialization

## Get object from pool - convenience method
func get_pooled_object(scene_path: String) -> Node:
	# Ensure pool is configured before accessing it
	_ensure_pool_configured(scene_path)
	return object_pool.get_object(scene_path)

## Return object to pool - convenience method
func return_pooled_object(object: Node, scene_path: String) -> bool:
	# Ensure pool is configured before returning to it
	_ensure_pool_configured(scene_path)
	return object_pool.return_object(object, scene_path)

## Get item from pool using item ID (recommended approach)
func get_item(item_id: String) -> Node:
	var item_config: ItemConfig = ConfigManager.get_item_config(item_id)
	if not item_config:
		Logger.error("Item config not found for: " + item_id, "PoolManager")
		return null
	
	if not item_config.use_pooling:
		Logger.warning("Item " + item_id + " is not configured for pooling", "PoolManager")
		# Create directly instead of using pool
		return item_config.item_scene.instantiate()
	
	# Ensure pool is configured and get scene path
	var scene_path: String = _ensure_item_pool_configured(item_id)
	if scene_path.is_empty():
		return null
	
	return object_pool.get_object(scene_path)

## Return item to pool using item ID (recommended approach)
func return_item(item: Node, item_id: String) -> bool:
	var item_config: ItemConfig = ConfigManager.get_item_config(item_id)
	if not item_config:
		Logger.error("Item config not found for: " + item_id, "PoolManager")
		return false
	
	if not item_config.use_pooling:
		# If item doesn't use pooling, just free it
		item.queue_free()
		return true
	
	# Ensure pool is configured and get scene path
	var scene_path: String = _ensure_item_pool_configured(item_id)
	if scene_path.is_empty():
		item.queue_free()  # Fallback to freeing if can't return to pool
		return false
	
	return object_pool.return_object(item, scene_path)

## Add pool configuration for an item ID (recommended approach)
func add_item_pool_configuration(item_id: String, max_size: int, initial_size: int = 0) -> void:
	pool_configurations[item_id] = {
		"max_size": max_size,
		"initial_size": initial_size
	}
	
	Logger.system("Added lazy pool configuration for item: " + item_id, "PoolManager")

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

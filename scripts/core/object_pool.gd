class_name ObjectPool
extends Node

## Object Pool System for Performance Optimization
## Manages reusable objects to reduce garbage collection and improve performance

# Pool storage - organized by scene path
var pools: Dictionary = {}
var pool_stats: Dictionary = {}

# Pool configuration
var max_pool_size: int = 100
var initial_pool_size: int = 10
var cleanup_interval: float = 30.0

# Pool management
var cleanup_timer: Timer

# Object pool signals
signal object_created(scene_path: String, object: Node)
signal object_retrieved(scene_path: String, object: Node)
signal object_returned(scene_path: String, object: Node)
signal pool_cleaned(scene_path: String, removed_count: int)

# Poolable object interface
class PoolableObject:
	## Objects that can be pooled should implement these methods
	## Reset object to initial state for reuse
	func reset_for_pool() -> void:
		pass
	
	## Prepare object for use when retrieved from pool
	func activate_from_pool() -> void:
		pass
	
	## Prepare object for return to pool
	func deactivate_for_pool() -> void:
		pass

func _ready() -> void:
	# Setup cleanup timer
	cleanup_timer = Timer.new()
	cleanup_timer.wait_time = cleanup_interval
	cleanup_timer.timeout.connect(_cleanup_pools)
	cleanup_timer.autostart = true
	add_child(cleanup_timer)
	
	Logger.system("ObjectPool initialized with cleanup interval: " + str(cleanup_interval) + "s", "ObjectPool")

## Get object from pool or create new one
func get_object(scene_path: String) -> Node:
	# Initialize pool if it doesn't exist
	if not pools.has(scene_path):
		_initialize_pool(scene_path)
	
	var pool: Array[Node] = []
	pool.assign(pools[scene_path])
	var object: Node
	
	# Try to get from pool first
	if not pool.is_empty():
		object = pool.pop_back()
		
		# Update the actual pools dictionary with the modified array
		pools[scene_path] = pool
		
		_activate_pooled_object(object)
		object_retrieved.emit(scene_path, object)
		_update_stats(scene_path, "retrieved")
		Logger.debug("Retrieved object from pool: " + scene_path, "ObjectPool")
	else:
		# Create new object if pool is empty
		object = _create_new_object(scene_path)
		if object:
			object_created.emit(scene_path, object)
			_update_stats(scene_path, "created")
			Logger.debug("Created new object: " + scene_path, "ObjectPool")
	
	return object

## Return object to pool
func return_object(object: Node, scene_path: String) -> bool:
	if not object or not pools.has(scene_path):
		Logger.warning("Cannot return object - invalid object or pool", "ObjectPool")
		return false
	
	var pool: Array[Node] = []
	pool.assign(pools[scene_path])
	
	# Check pool size limit
	if pool.size() >= max_pool_size:
		Logger.debug("Pool full, destroying object: " + scene_path, "ObjectPool")
		object.queue_free()
		_update_stats(scene_path, "destroyed")
		return false
	
	# Prepare object for pool storage
	_deactivate_pooled_object(object)
	
	# Remove from scene tree but don't free
	if object.get_parent():
		object.get_parent().remove_child(object)
	
	# Add to pool
	pool.append(object)
	
	# Update the actual pools dictionary with the modified array
	pools[scene_path] = pool
	
	object_returned.emit(scene_path, object)
	_update_stats(scene_path, "returned")
	
	Logger.debug("Returned object to pool: " + scene_path + " (pool size: " + str(pool.size()) + ")", "ObjectPool")
	return true

## Pre-warm pool with initial objects
func prewarm_pool(scene_path: String, count: int = -1) -> void:
	var prewarm_count: int = count if count > 0 else initial_pool_size
	
	if not pools.has(scene_path):
		_initialize_pool(scene_path)
	
	var pool: Array[Node] = []
	pool.assign(pools[scene_path])
	var created_count: int = 0
	
	for i in range(prewarm_count):
		if pool.size() >= max_pool_size:
			break
		
		var object: Node = _create_new_object(scene_path)
		if object:
			_deactivate_pooled_object(object)
			# Remove from scene tree for pool storage
			if object.get_parent():
				object.get_parent().remove_child(object)
			pool.append(object)
			created_count += 1
	
	# Update the actual pools dictionary with the modified array
	pools[scene_path] = pool
	
	Logger.system("Pre-warmed pool for " + scene_path + " with " + str(created_count) + " objects", "ObjectPool")

## Clear all objects from a specific pool
func clear_pool(scene_path: String) -> int:
	if not pools.has(scene_path):
		return 0
	
	var pool: Array[Node] = []
	pool.assign(pools[scene_path])
	var count: int = pool.size()
	
	# Free all pooled objects immediately (not queue_free during shutdown)
	for object in pool:
		if is_instance_valid(object):
			# Force immediate cleanup for pooled objects
			if object.has_method("deactivate_for_pool"):
				object.deactivate_for_pool()
			
			# Remove from parent to break references
			if object.get_parent():
				object.get_parent().remove_child(object)
			
			# Free immediately instead of queue_free for shutdown cleanup
			object.free()
	
	pool.clear()
	Logger.debug("Cleared pool: " + scene_path + " (" + str(count) + " objects)", "ObjectPool")
	return count

## Clear all pools
func clear_all_pools() -> int:
	var total_cleared: int = 0
	
	for scene_path in pools.keys():
		total_cleared += clear_pool(scene_path)
	
	pools.clear()
	pool_stats.clear()
	Logger.system("Cleared all pools (" + str(total_cleared) + " objects)", "ObjectPool")
	return total_cleared

## Get pool statistics
func get_pool_stats() -> Dictionary:
	var stats: Dictionary = {}
	
	for scene_path in pools.keys():
		var pool: Array[Node] = []
		pool.assign(pools[scene_path])
		var scene_stats: Dictionary = pool_stats.get(scene_path, {})
		
		stats[scene_path] = {
			"pool_size": pool.size(),
			"max_size": max_pool_size,
			"created": scene_stats.get("created", 0),
			"retrieved": scene_stats.get("retrieved", 0),
			"returned": scene_stats.get("returned", 0),
			"destroyed": scene_stats.get("destroyed", 0)
		}
	
	return stats

## Set pool configuration
func configure_pool(scene_path: String, max_size: int, initial_size: int = 0) -> void:
	if not pools.has(scene_path):
		_initialize_pool(scene_path)
	
	# Update configuration (this affects future operations)
	# For scene-specific configuration, we'd need a more complex system
	
	# Pre-warm if initial size specified
	if initial_size > 0:
		prewarm_pool(scene_path, initial_size)

## Initialize pool for a scene path
func _initialize_pool(scene_path: String) -> void:
	pools[scene_path] = []
	pool_stats[scene_path] = {
		"created": 0,
		"retrieved": 0,
		"returned": 0,
		"destroyed": 0
	}
	Logger.debug("Initialized pool for: " + scene_path, "ObjectPool")

## Create new object from scene
func _create_new_object(scene_path: String) -> Node:
	var scene: PackedScene = load(scene_path)
	if not scene:
		Logger.error("Failed to load scene: " + scene_path, "ObjectPool")
		return null
	
	var object: Node = scene.instantiate()
	if not object:
		Logger.error("Failed to instantiate scene: " + scene_path, "ObjectPool")
		return null
	
	return object

## Activate object retrieved from pool
func _activate_pooled_object(object: Node) -> void:
	# Reset object state for reuse
	if object.has_method("reset_for_pool"):
		object.reset_for_pool()
	
	# Activate from pool
	if object.has_method("activate_from_pool"):
		object.activate_from_pool()
	
	# Ensure object is visible and active
	object.visible = true
	object.set_process(true)
	object.set_physics_process(true)

## Deactivate object for pool storage
func _deactivate_pooled_object(object: Node) -> void:
	# Prepare for pool storage
	if object.has_method("deactivate_for_pool"):
		object.deactivate_for_pool()
	
	# Disable processing to save performance
	object.set_process(false)
	object.set_physics_process(false)
	object.visible = false

## Update pool statistics
func _update_stats(scene_path: String, action: String) -> void:
	if not pool_stats.has(scene_path):
		pool_stats[scene_path] = {}
	
	var stats: Dictionary = pool_stats[scene_path]
	stats[action] = stats.get(action, 0) + 1

## Periodic cleanup of pools
func _cleanup_pools() -> void:
	var total_cleaned: int = 0
	
	for scene_path in pools.keys():
		var pool: Array[Node] = []
		pool.assign(pools[scene_path])
		var cleaned_count: int = 0
		
		# Remove invalid objects
		for i in range(pool.size() - 1, -1, -1):
			var object: Node = pool[i]
			if not is_instance_valid(object):
				pool.remove_at(i)
				cleaned_count += 1
		
		if cleaned_count > 0:
			total_cleaned += cleaned_count
			pool_cleaned.emit(scene_path, cleaned_count)
			Logger.debug("Cleaned " + str(cleaned_count) + " invalid objects from pool: " + scene_path, "ObjectPool")
	
	if total_cleaned > 0:
		Logger.system("Pool cleanup completed - removed " + str(total_cleaned) + " invalid objects", "ObjectPool")

func _exit_tree() -> void:
	clear_all_pools()
	Logger.debug("ObjectPool cleanup completed", "ObjectPool") 

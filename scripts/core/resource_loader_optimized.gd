class_name ResourceLoaderOptimized
extends Node

## Optimized Resource Loader for Better Performance
## Manages resource loading, caching, and lazy loading patterns

# Resource cache
var resource_cache: Dictionary = {}
var scene_cache: Dictionary = {}

# Loading configuration
var enable_caching: bool = true
var cache_limit: int = 100
var preload_critical_resources: bool = true

# Resource management signals
signal resource_loaded(path: String, resource: Resource)
signal resource_preloaded(path: String, resource: Resource)
signal cache_cleared(cleared_count: int)

# Critical resources that should be preloaded
var critical_resources: Array[String] = [
	"res://scenes/items/bullet.tscn",
	"res://scenes/items/bat.tscn",
	"res://scenes/items/pistol.tscn",
	"res://scenes/ui/player_hud.tscn",
	"res://scenes/player/base_player.tscn"
]

func _ready() -> void:
	# Don't preload critical resources on startup - wait until needed
	# if preload_critical_resources:
	#	_preload_critical_resources()
	
	Logger.system("ResourceLoaderOptimized initialized with lazy loading - critical resources will be loaded when requested", "ResourceLoader")

## Load resource with caching
func load_resource_cached(path: String) -> Resource:
	# Check cache first
	if enable_caching and resource_cache.has(path):
		Logger.debug("Resource loaded from cache: " + path, "ResourceLoader")
		return resource_cache[path]
	
	# Load resource
	var resource: Resource = load(path)
	if not resource:
		Logger.error("Failed to load resource: " + path, "ResourceLoader")
		return null
	
	# Cache if enabled and under limit
	if enable_caching and resource_cache.size() < cache_limit:
		resource_cache[path] = resource
		Logger.debug("Resource cached: " + path, "ResourceLoader")
	
	resource_loaded.emit(path, resource)
	return resource

## Load scene with caching
func load_scene_cached(path: String) -> PackedScene:
	# Check scene cache first
	if enable_caching and scene_cache.has(path):
		Logger.debug("Scene loaded from cache: " + path, "ResourceLoader")
		return scene_cache[path]
	
	# Load scene
	var scene: PackedScene = load(path) as PackedScene
	if not scene:
		Logger.error("Failed to load scene: " + path, "ResourceLoader")
		return null
	
	# Cache if enabled and under limit
	if enable_caching and scene_cache.size() < cache_limit:
		scene_cache[path] = scene
		Logger.debug("Scene cached: " + path, "ResourceLoader")
	
	resource_loaded.emit(path, scene)
	return scene

## Instantiate scene from cache
func instantiate_scene_cached(path: String) -> Node:
	var scene: PackedScene = load_scene_cached(path)
	if not scene:
		return null
	
	var instance: Node = scene.instantiate()
	if not instance:
		Logger.error("Failed to instantiate scene: " + path, "ResourceLoader")
		return null
	
	return instance

## Preload resource asynchronously
func preload_resource_async(path: String) -> void:
	# Check if already cached
	if enable_caching and resource_cache.has(path):
		return
	
	# Use ResourceLoader for async loading in the background
	call_deferred("_load_resource_deferred", path)

## Load resource in deferred call
func _load_resource_deferred(path: String) -> void:
	var resource: Resource = load(path)
	if resource and enable_caching and resource_cache.size() < cache_limit:
		resource_cache[path] = resource
		resource_preloaded.emit(path, resource)
		Logger.debug("Resource preloaded: " + path, "ResourceLoader")

## Preload critical resources
func _preload_critical_resources() -> void:
	Logger.system("Preloading " + str(critical_resources.size()) + " critical resources", "ResourceLoader")
	
	for resource_path in critical_resources:
		preload_resource_async(resource_path)

## Preload critical resources when they're actually needed (e.g., when starting a game mode)
func preload_critical_resources_now() -> void:
	if preload_critical_resources:
		_preload_critical_resources()
		Logger.system("Critical resources preloaded on demand", "ResourceLoader")
	else:
		Logger.debug("Critical resource preloading is disabled", "ResourceLoader")

## Clear resource cache
func clear_cache() -> int:
	var cleared_count: int = resource_cache.size() + scene_cache.size()
	resource_cache.clear()
	scene_cache.clear()
	
	cache_cleared.emit(cleared_count)
	Logger.debug("Cleared resource cache (" + str(cleared_count) + " resources)", "ResourceLoader")
	return cleared_count

## Clear specific resource from cache
func clear_resource_from_cache(path: String) -> bool:
	var was_removed: bool = false
	
	if resource_cache.has(path):
		resource_cache.erase(path)
		was_removed = true
	
	if scene_cache.has(path):
		scene_cache.erase(path)
		was_removed = true
	
	if was_removed:
		Logger.debug("Removed resource from cache: " + path, "ResourceLoader")
	
	return was_removed

## Get cache statistics
func get_cache_stats() -> Dictionary:
	return {
		"resource_cache_size": resource_cache.size(),
		"scene_cache_size": scene_cache.size(),
		"total_cached": resource_cache.size() + scene_cache.size(),
		"cache_limit": cache_limit,
		"cache_usage_percent": float(resource_cache.size() + scene_cache.size()) / float(cache_limit) * 100.0
	}

## Check if resource exists without loading
func resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path)

## Get resource type without loading
func get_resource_type(path: String) -> String:
	if not resource_exists(path):
		return ""
	
	# Try to determine type from extension
	var extension: String = path.get_extension().to_lower()
	match extension:
		"tscn":
			return "PackedScene"
		"tres":
			return "Resource"
		"gd":
			return "GDScript"
		"cs":
			return "CSharpScript"
		"png", "jpg", "jpeg":
			return "Texture2D"
		"ogg", "wav", "mp3":
			return "AudioStream"
		_:
			return "Unknown"

## Warm up cache with specific resources
func warm_cache(resource_paths: Array[String]) -> void:
	Logger.system("Warming cache with " + str(resource_paths.size()) + " resources", "ResourceLoader")
	
	for path in resource_paths:
		preload_resource_async(path)

## Enable or disable caching
func set_caching_enabled(enabled: bool) -> void:
	enable_caching = enabled
	if not enabled:
		clear_cache()
	Logger.debug("Resource caching " + ("enabled" if enabled else "disabled"), "ResourceLoader")

## Set cache limit
func set_cache_limit(limit: int) -> void:
	cache_limit = limit
	
	# Clear excess resources if current cache exceeds new limit
	while resource_cache.size() + scene_cache.size() > cache_limit:
		if resource_cache.size() > 0:
			var key: String = resource_cache.keys()[0]
			resource_cache.erase(key)
		elif scene_cache.size() > 0:
			var key: String = scene_cache.keys()[0]
			scene_cache.erase(key)
		else:
			break
	
	Logger.debug("Cache limit set to: " + str(cache_limit), "ResourceLoader")

## Print cache contents for debugging
func print_cache_contents() -> void:
	Logger.system("=== Resource Cache Contents ===", "ResourceLoader")
	Logger.system("Resource Cache (" + str(resource_cache.size()) + " items):", "ResourceLoader")
	for path in resource_cache.keys():
		Logger.system("  " + path, "ResourceLoader")
	
	Logger.system("Scene Cache (" + str(scene_cache.size()) + " items):", "ResourceLoader")
	for path in scene_cache.keys():
		Logger.system("  " + path, "ResourceLoader")

func _exit_tree() -> void:
	clear_cache()
	Logger.debug("ResourceLoaderOptimized cleanup completed", "ResourceLoader") 
extends Node



## Main scene controller - Root scene that manages the overall application flow
## Handles initial scene loading and high-level scene management
##
## COLLISION LAYERS: See CollisionLayers class for centralized enum definitions
## - ENVIRONMENT (1): Static world geometry (platforms, walls, ground)
## - PLAYERS (2): Player characters (alive and ragdolled)  
## - ITEMS (4): Pickup items (weapons, consumables)
## - PROJECTILES (8): Bullets, grenades, thrown objects
## - TRIGGERS (16): Area2D triggers for events, pickups, damage zones
## - DESTRUCTIBLES (32): Breakable objects in the environment

@onready var ui_layer: CanvasLayer = $UILayer
@onready var scene_container: Node = $SceneContainer

# Preload common scenes for better performance
var main_menu_scene: PackedScene = preload("res://scenes/ui/main_menu.tscn")
var map_view_scene: PackedScene = preload("res://scenes/ui/map_view.tscn")
var sudden_death_minigame_scene: PackedScene = preload("res://scenes/minigames/sudden_death_minigame.tscn")

func _ready() -> void:
	# Connect to EventBus for scene transitions
	EventBus.scene_transition_requested.connect(_on_scene_transition_requested)
	
	# Start with main menu
	_load_initial_scene()
	Logger.system("Main scene initialized", "Main")

## Handle application shutdown - ensure proper cleanup
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Logger.system("Application shutting down - forcing cleanup", "Main")
		_force_cleanup_all_resources()

## Force cleanup of all resources before shutdown
func _force_cleanup_all_resources() -> void:
	# Clean up dropped items and projectiles
	_cleanup_dropped_items()
	
	# Clear all scenes
	for child in scene_container.get_children():
		child.queue_free()
	
	# Force clear object pools immediately
	if PoolManager:
		PoolManager.clear_all_pools()
	
	# Clean up EventBus connections
	if EventBus:
		EventBus.force_cleanup_all_connections()
	
	# Process pending deletions
	await get_tree().process_frame
	Logger.system("Forced cleanup completed", "Main")

func _load_initial_scene() -> void:
	# Load the main menu as the first scene
	var main_menu_instance: Node = main_menu_scene.instantiate()
	scene_container.add_child(main_menu_instance)
	
	GameManager.transition_to_menu()

func _on_scene_transition_requested(scene_path: String) -> void:
	# Clean up dropped items before scene transition
	_cleanup_dropped_items()
	
	# Clear current scene
	for child in scene_container.get_children():
		child.queue_free()
	
	# Load new scene - try preloaded scenes first for better performance
	var scene_instance: Node = null
	
	match scene_path:
		"res://scenes/ui/main_menu.tscn":
			scene_instance = main_menu_scene.instantiate()
		"res://scenes/ui/map_view.tscn":
			scene_instance = map_view_scene.instantiate()
		"res://scenes/minigames/sudden_death_minigame.tscn":
			scene_instance = sudden_death_minigame_scene.instantiate()
		# Remove the container reference
		"minigame:sudden_death":  # Support direct minigame requests
			scene_instance = sudden_death_minigame_scene.instantiate()
		_:
			# Fallback to load() for other scenes
			var new_scene: PackedScene = load(scene_path)
			if new_scene:
				scene_instance = new_scene.instantiate()
	
	if scene_instance:
		scene_container.add_child(scene_instance)
		Logger.system("Loaded scene: " + scene_path, "Main")
	else:
		Logger.error("Failed to load scene: " + scene_path, "Main") 

## Clean up dropped items during scene transitions
func _cleanup_dropped_items() -> void:
	Logger.system("Cleaning up dropped items and projectiles during scene transition", "Main")
	
	# Find all items and projectiles in the scene 
	var items_to_cleanup: Array[BaseItem] = []
	var projectiles_to_cleanup: Array[Node] = []
	_find_cleanup_nodes_recursive(self, items_to_cleanup, projectiles_to_cleanup)
	
	# Clean up found items (only if not held)
	for item in items_to_cleanup:
		if item and is_instance_valid(item) and not item.is_held:
			Logger.debug("Cleaning up dropped item: " + item.item_name, "Main")
			item.queue_free()
	
	# Clean up projectiles (bullets, etc.)
	for projectile in projectiles_to_cleanup:
		if projectile and is_instance_valid(projectile):
			Logger.debug("Cleaning up projectile: " + projectile.get_class(), "Main")
			projectile.queue_free()
	
	Logger.system("Cleaned up " + str(items_to_cleanup.size()) + " dropped items and " + str(projectiles_to_cleanup.size()) + " projectiles", "Main")

## Recursively find all cleanup nodes in the scene tree
func _find_cleanup_nodes_recursive(node: Node, items: Array[BaseItem], projectiles: Array[Node]) -> void:
	if node is BaseItem:
		items.append(node as BaseItem)
	elif node.has_method("initialize") and node.has_method("_destroy_bullet"):
		# Duck typing check for bullet-like objects
		projectiles.append(node)
	
	for child in node.get_children():
		_find_cleanup_nodes_recursive(child, items, projectiles) 

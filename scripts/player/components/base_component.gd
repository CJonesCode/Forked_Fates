class_name BaseComponent
extends Node

## Base class for all player components
## Provides common interface and lifecycle management

# Reference to the player that owns this component
var player: BasePlayer

# Component lifecycle signals
signal component_ready()
signal component_destroyed()

func _ready() -> void:
	# Get reference to parent player
	player = get_parent() as BasePlayer
	if not player:
		Logger.error("BaseComponent must be a child of BasePlayer", get_class())
		queue_free()
		return
	
	# Initialize component
	_initialize_component()
	component_ready.emit()
	var player_name: String = "Unknown Player"
	if player.player_data:
		player_name = player.player_data.player_name
	Logger.debug("Component " + get_class() + " initialized for " + player_name, get_class())

## Virtual method for component initialization
## Override in derived components
func _initialize_component() -> void:
	pass

## Virtual method for component cleanup
## Override in derived components
func _cleanup_component() -> void:
	pass

func _exit_tree() -> void:
	_cleanup_component()
	component_destroyed.emit()
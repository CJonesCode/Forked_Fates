class_name PlayerSpawner
extends Node

## Standard manager for spawning and managing players in physics-based minigames
## Handles player creation, positioning, respawning, and cleanup

# Configuration
@export var player_scene: PackedScene = preload("res://scenes/player/base_player.tscn")
@export var auto_setup_input: bool = true
@export var apply_player_colors: bool = true

# Spawn management
var spawn_points: Array[Vector2] = []
var spawned_players: Array[BasePlayer] = []
var player_lookup: Dictionary = {}  # player_id -> BasePlayer

# Player colors for visual identification
var player_colors: Array[Color] = [
	Color(1.0, 0.3, 0.3, 1.0),  # Red (Player 1)
	Color(0.3, 0.3, 1.0, 1.0),  # Blue (Player 2)
	Color(0.3, 1.0, 0.3, 1.0),  # Green (Player 3)
	Color(1.0, 1.0, 0.3, 1.0),  # Yellow (Player 4)
	Color(1.0, 0.3, 1.0, 1.0),  # Magenta (Player 5)
	Color(0.3, 1.0, 1.0, 1.0),  # Cyan (Player 6)
	Color(1.0, 0.6, 0.3, 1.0),  # Orange (Player 7)
	Color(0.6, 0.3, 1.0, 1.0),  # Purple (Player 8)
]

# Signals
signal player_spawned(player: BasePlayer)
signal player_despawned(player_id: int)
signal all_players_spawned()

func _ready() -> void:
	Logger.system("PlayerSpawner ready", "PlayerSpawner")

## Setup spawn points from positions array
func setup_spawn_points(points: Array[Vector2]) -> void:
	spawn_points = points.duplicate()
	Logger.system("PlayerSpawner configured with " + str(spawn_points.size()) + " spawn points", "PlayerSpawner")

## Spawn all players from player data array
func spawn_all_players(player_data_array: Array[PlayerData]) -> void:
	Logger.game_flow("Spawning " + str(player_data_array.size()) + " players", "PlayerSpawner")
	
	if spawn_points.size() < player_data_array.size():
		Logger.warning("Not enough spawn points (" + str(spawn_points.size()) + ") for players (" + str(player_data_array.size()) + ")", "PlayerSpawner")
	
	for i in range(player_data_array.size()):
		if i < spawn_points.size():
			spawn_player(player_data_array[i], spawn_points[i])
		else:
			# Use a default position if we run out of spawn points
			spawn_player(player_data_array[i], Vector2.ZERO)
	
	all_players_spawned.emit()

## Spawn a single player at a specific position
func spawn_player(player_data: PlayerData, position: Vector2) -> BasePlayer:
	if not player_scene:
		Logger.error("No player scene configured for PlayerSpawner", "PlayerSpawner")
		return null
	
	# Create player instance
	var player_instance: BasePlayer = player_scene.instantiate()
	
	if not player_instance:
		Logger.error("Failed to instantiate player scene", "PlayerSpawner")
		return null
	
	# Set player data BEFORE adding to scene tree
	player_instance.player_data = player_data
	
	# Add to scene tree
	get_parent().add_child(player_instance)
	
	# Set position
	player_instance.global_position = position
	
	# Set spawn position for respawning
	player_instance.set_spawn_position(position)
	
	# Configure input controller
	if auto_setup_input:
		_setup_player_input(player_instance, player_data.player_id)
	
	# Apply visual identification
	if apply_player_colors:
		_apply_player_color(player_instance, player_data.player_id)
	
	# Track the player
	spawned_players.append(player_instance)
	player_lookup[player_data.player_id] = player_instance
	
	Logger.system("Spawned player: " + player_data.player_name + " at " + str(position), "PlayerSpawner")
	player_spawned.emit(player_instance)
	
	return player_instance

## Respawn a specific player at their spawn position
func respawn_player(player_id: int) -> BasePlayer:
	var player: BasePlayer = get_player(player_id)
	if not player:
		Logger.warning("Cannot respawn - player " + str(player_id) + " not found", "PlayerSpawner")
		return null
	
	# Respawn the player at their designated spawn position
	player.respawn()
	Logger.system("Respawned player " + str(player_id), "PlayerSpawner")
	
	return player

## Get player instance by ID
func get_player(player_id: int) -> BasePlayer:
	return player_lookup.get(player_id, null)

## Get all spawned players
func get_all_players() -> Array[BasePlayer]:
	return spawned_players.duplicate()

## Get all alive players
func get_alive_players() -> Array[BasePlayer]:
	var alive_players: Array[BasePlayer] = []
	for player in spawned_players:
		if player and player.current_state == BasePlayer.PlayerState.ALIVE:
			alive_players.append(player)
	return alive_players

## Get count of alive players
func get_alive_count() -> int:
	return get_alive_players().size()

## Remove a specific player
func despawn_player(player_id: int) -> void:
	var player: BasePlayer = get_player(player_id)
	if not player:
		Logger.warning("Cannot despawn - player " + str(player_id) + " not found", "PlayerSpawner")
		return
	
	# Remove from tracking
	spawned_players.erase(player)
	player_lookup.erase(player_id)
	
	# Remove from scene
	player.queue_free()
	
	Logger.system("Despawned player " + str(player_id), "PlayerSpawner")
	player_despawned.emit(player_id)

## Cleanup all spawned players
func cleanup_players() -> void:
	Logger.system("Cleaning up all spawned players", "PlayerSpawner")
	
	for player in spawned_players:
		if player and is_instance_valid(player):
			player.queue_free()
	
	spawned_players.clear()
	player_lookup.clear()

## Setup input controller for a player
func _setup_player_input(player: BasePlayer, player_id: int) -> void:
	var input_controller: Node = player.get_node("InputController")
	if input_controller and input_controller.has_method("setup_for_player"):
		input_controller.setup_for_player(player_id)
		Logger.system("Configured input for player " + str(player_id), "PlayerSpawner")
	else:
		Logger.warning("No InputController found for player " + str(player_id), "PlayerSpawner")

## Apply visual color identification to player
func _apply_player_color(player: BasePlayer, player_id: int) -> void:
	var player_sprite: Node = player.get_node_or_null("Sprite2D/PlayerSprite")
	if not player_sprite:
		Logger.warning("No PlayerSprite found for color application", "PlayerSpawner")
		return
	
	var color_index: int = player_id % player_colors.size()
	var player_color: Color = player_colors[color_index]
	
	if player_sprite.has_method("set_modulate"):
		player_sprite.modulate = player_color
	elif player_sprite.has_property("color"):
		player_sprite.color = player_color
	
	Logger.system("Applied color " + str(player_color) + " to player " + str(player_id), "PlayerSpawner")

## Modify spawn settings for all future spawns
func modify_spawn_settings(settings: Dictionary) -> void:
	Logger.system("Modifying spawn settings: " + str(settings), "PlayerSpawner")
	
	# Apply settings to existing players
	for player in spawned_players:
		if player and is_instance_valid(player):
			_apply_settings_to_player(player, settings)

## Apply settings to a specific player
func _apply_settings_to_player(player: BasePlayer, settings: Dictionary) -> void:
	if settings.has("health"):
		var health_value: int = settings.health
		if player.player_data:
			player.player_data.max_health = health_value
			player.player_data.current_health = health_value
		player.set_health(health_value)
	
	if settings.has("speed"):
		var speed_value: float = settings.speed
		# Apply speed modification - would need to be implemented in player
		if player.has_method("set_movement_speed"):
			player.set_movement_speed(speed_value)

## Get spawn statistics
func get_spawn_statistics() -> Dictionary:
	return {
		"total_spawned": spawned_players.size(),
		"alive_count": get_alive_count(),
		"spawn_points_available": spawn_points.size(),
		"players_tracked": player_lookup.size()
	} 
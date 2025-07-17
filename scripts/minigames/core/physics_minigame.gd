class_name PhysicsMinigame
extends BaseMinigame

## Base class for physics-based minigames
## Uses standard managers for common patterns like player spawning, item management, etc.
## Example: Combat games, racing games, platformers

# Standard manager references (set up automatically)
var player_spawner: PlayerSpawner = null
var item_spawner: ItemSpawner = null
var victory_condition_manager: VictoryConditionManager = null
var respawn_manager: RespawnManager = null

# Physics-specific configuration
@export var use_player_spawner: bool = true
@export var use_item_spawner: bool = true
@export var use_victory_conditions: bool = true
@export var use_respawn_system: bool = true

# Arena and spawn configuration
@onready var arena: Node2D = $Arena
@onready var spawn_points: Node2D = $SpawnPoints
@onready var respawn_points: Node2D = $RespawnPoints
@onready var item_spawn_points: Node2D = $ItemSpawnPoints

# Physics minigame signals
signal player_spawned(player: BasePlayer)
signal player_eliminated(player_id: int)
signal item_spawned(item: BaseItem)
signal round_started()
signal round_ended()

func _ready() -> void:
	super()
	minigame_name = "Physics Minigame"
	minigame_type = "physics"
	minigame_description = "Physics-based minigame with player spawning and item management"
	tags = ["physics"]
	
	# Default tutorial content for physics minigames
	tutorial_objective = "Survive and defeat your opponents!"
	tutorial_controls = {
		"Move": "WASD / Arrow Keys",
		"Jump": "Space / Up Arrow", 
		"Use Item": "E / Enter",
		"Drop Item": "Q / Shift"
	}
	tutorial_tips = [
		"Collect items for advantages",
		"Use the environment to your benefit",
		"Watch for other players' movements"
	]

## Initialize physics minigame with standard managers
func _on_initialize(minigame_context: MinigameContext) -> void:
	Logger.system("Initializing PhysicsMinigame with standard managers", "PhysicsMinigame")
	
	# Set up standard managers based on configuration
	if use_player_spawner:
		player_spawner = context.get_standard_manager("player_spawner")
		if player_spawner:
			add_child(player_spawner)
			player_spawner.setup_spawn_points(_get_spawn_points())
			player_spawner.player_spawned.connect(_on_player_spawned)
	
	if use_item_spawner:
		item_spawner = context.get_standard_manager("item_spawner")
		if item_spawner:
			add_child(item_spawner)
			item_spawner.setup_spawn_points(_get_item_spawn_points())
			item_spawner.item_spawned.connect(_on_item_spawned)
	
	if use_victory_conditions:
		victory_condition_manager = context.get_standard_manager("victory_condition_manager")
		if victory_condition_manager:
			add_child(victory_condition_manager)
			victory_condition_manager.setup_players(context.participating_players)
			victory_condition_manager.victory_achieved.connect(_on_victory_achieved)
	
	if use_respawn_system:
		respawn_manager = context.get_standard_manager("respawn_manager")
		if respawn_manager:
			add_child(respawn_manager)
			respawn_manager.setup_respawn_points(_get_respawn_points())
			respawn_manager.player_respawned.connect(_on_player_respawned)
	
	# Setup arena and physics environment
	_setup_arena()
	
	# Hook for subclass initialization
	_on_physics_initialize()

## Start the physics minigame
func _on_start() -> void:
	Logger.game_flow("Starting PhysicsMinigame with standard systems", "PhysicsMinigame")
	
	# Spawn players if using player spawner
	if player_spawner:
		player_spawner.spawn_all_players(context.participating_players)
	
	# Spawn initial items if using item spawner
	if item_spawner:
		item_spawner.spawn_initial_items()
	
	# Start victory condition tracking
	if victory_condition_manager:
		victory_condition_manager.start_tracking()
	
	# Start respawn system
	if respawn_manager:
		respawn_manager.start_respawn_tracking()
	
	round_started.emit()
	
	# Hook for subclass start logic
	_on_physics_start()

## End the physics minigame
func _on_end(result: MinigameResult) -> void:
	Logger.game_flow("Ending PhysicsMinigame", "PhysicsMinigame")
	
	# Stop all managers
	if victory_condition_manager:
		victory_condition_manager.stop_tracking()
	
	if respawn_manager:
		respawn_manager.stop_respawn_tracking()
	
	if item_spawner:
		item_spawner.cleanup_items()
	
	if player_spawner:
		player_spawner.cleanup_players()
	
	round_ended.emit()
	
	# Hook for subclass cleanup
	_on_physics_end(result)

## Setup arena physics and environment
func _setup_arena() -> void:
	Logger.system("Setting up physics arena", "PhysicsMinigame")
	
	# Configure physics layers and collision
	# This would set up boundaries, platforms, hazards, etc.
	
	# Hook for subclass arena setup
	_on_setup_arena()

## Get spawn point positions
func _get_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if spawn_points:
		for child in spawn_points.get_children():
			if child is Marker2D:
				points.append(child.global_position)
	return points

## Get respawn point positions
func _get_respawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if respawn_points:
		for child in respawn_points.get_children():
			if child is Marker2D:
				points.append(child.global_position)
	return points

## Get item spawn point positions
func _get_item_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if item_spawn_points:
		for child in item_spawn_points.get_children():
			if child is Marker2D:
				points.append(child.global_position)
	return points

## Handle player spawning
func _on_player_spawned(player: BasePlayer) -> void:
	Logger.system("Player spawned: " + player.player_data.player_name, "PhysicsMinigame")
	player_spawned.emit(player)
	
	# Hook for subclass player spawn handling
	_on_physics_player_spawned(player)

## Handle item spawning
func _on_item_spawned(item: BaseItem) -> void:
	Logger.system("Item spawned: " + item.item_name, "PhysicsMinigame")
	item_spawned.emit(item)
	
	# Hook for subclass item spawn handling
	_on_physics_item_spawned(item)

## Handle player respawning
func _on_player_respawned(player: BasePlayer) -> void:
	Logger.game_flow("Player respawned: " + player.player_data.player_name, "PhysicsMinigame")
	
	# Hook for subclass respawn handling
	_on_physics_player_respawned(player)

## Handle victory conditions
func _on_victory_achieved(winner_data: Dictionary) -> void:
	Logger.game_flow("Victory achieved in PhysicsMinigame", "PhysicsMinigame")
	
	# Create victory result
	var result: MinigameResult
	if winner_data.has("winner_id"):
		result = MinigameResult.create_victory_result(
			winner_data.winner_id,
			context.get_player_ids(),
			minigame_name,
			0.0  # Duration will be set by base class
		)
	else:
		result = MinigameResult.create_draw_result(
			winner_data.get("tied_players", []),
			context.get_player_ids(),
			minigame_name,
			0.0
		)
	
	# Add physics-specific statistics
	if victory_condition_manager:
		result.statistics = victory_condition_manager.get_game_statistics()
	
	# Hook for subclass victory handling
	_on_physics_victory(winner_data, result)
	
	# End the minigame
	end_minigame(result)

# Virtual methods for subclasses to implement physics-specific logic

## Called during physics initialization after managers are set up
func _on_physics_initialize() -> void:
	pass

## Called when physics minigame starts after standard setup
func _on_physics_start() -> void:
	pass

## Called when physics minigame ends before cleanup
func _on_physics_end(result: MinigameResult) -> void:
	pass

## Called during arena setup
func _on_setup_arena() -> void:
	pass

## Called when a player is spawned
func _on_physics_player_spawned(player: BasePlayer) -> void:
	pass

## Called when an item is spawned
func _on_physics_item_spawned(item: BaseItem) -> void:
	pass

## Called when a player respawns
func _on_physics_player_respawned(player: BasePlayer) -> void:
	pass

## Called when victory is achieved, before ending minigame
func _on_physics_victory(winner_data: Dictionary, result: MinigameResult) -> void:
	pass 
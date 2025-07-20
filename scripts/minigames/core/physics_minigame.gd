class_name PhysicsMinigame
extends BaseMinigame

## Base class for physics-based minigames
## Uses standard managers for common patterns like player spawning, weapon management, etc.
## Example: Combat games, racing games, platformers
## Pure throwing-centric weapon system

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
@export var leadership_update_frequency: float = 1.0  # Update leadership every second

# Arena and spawn configuration (assigned by subclass or found automatically)
var arena: Node2D = null
var spawn_points: Node2D = null
var respawn_points: Node2D = null
var item_spawn_points: Node2D = null

# Leadership tracking
var leadership_update_timer: float = 0.0

# Physics minigame signals
signal player_spawned(player: BasePlayer)
signal player_eliminated(player_id: int)
signal weapon_spawned(weapon)
signal round_started()
signal round_ended()

func _ready() -> void:
	super()
	minigame_name = "Physics Minigame"
	minigame_type = "physics"
	minigame_description = "Physics-based minigame with player spawning and weapon management"
	tags = ["physics"]
	
	# Find arena and spawn nodes if they exist
	_find_arena_nodes()
	
	# Throwing-centric tutorial content for physics minigames
	tutorial_objective = "Survive and defeat your opponents!"
	tutorial_controls = {
		"Move": "WASD / Arrow Keys",
		"Jump": "Space / Up Arrow", 
		"Fire Weapon": "E / Enter",      # Fire held weapon
		"Throw Weapon": "Q / Shift",     # Throw weapon as projectile
		"Pick Up Weapon": "R / Ctrl"     # Pick up nearby weapon
	}
	tutorial_tips = [
		"Collect weapons for advantages",
		"Throw weapons as projectiles for extra damage",
		"Fire weapons to attack at range",
		"Pick up weapons dropped by others",
		"Use the environment to your benefit"
	]

func _process(delta: float) -> void:
	# Periodic leadership tracking updates
	if use_leadership_tracking and is_active and not is_paused:
		leadership_update_timer += delta
		if leadership_update_timer >= leadership_update_frequency:
			leadership_update_timer = 0.0
			update_leadership_tracking()

## Initialize physics minigame with standard managers
func _on_initialize(minigame_context: MinigameContext) -> void:
	Logger.system("Initializing PhysicsMinigame with context", "PhysicsMinigame")
	Logger.system("DEBUG: Received context with " + str(minigame_context.participating_players.size()) + " players", "PhysicsMinigame")
	
	# Setup standard managers first
	_setup_standard_managers()
	
	# Hook for subclass initialization
	_on_physics_initialize()

## Setup standard managers for physics minigames
func _setup_standard_managers() -> void:
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
			
			# Connect to weapon spawning signals
			item_spawner.weapon_spawned.connect(_on_weapon_spawned)
			Logger.system("ItemSpawner configured for projectile weapon spawning", "PhysicsMinigame")
	
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

## Start the physics minigame
func _on_start() -> void:
	Logger.game_flow("Starting PhysicsMinigame with standard systems", "PhysicsMinigame")
	Logger.system("DEBUG: Player spawner available: " + str(player_spawner != null), "PhysicsMinigame")
	Logger.system("DEBUG: Item spawner available: " + str(item_spawner != null), "PhysicsMinigame")
	Logger.system("DEBUG: Context available: " + str(context != null), "PhysicsMinigame")
	if context:
		Logger.system("DEBUG: Participating players count: " + str(context.participating_players.size()), "PhysicsMinigame")
	
	# Spawn players if using player spawner
	if player_spawner:
		Logger.system("DEBUG: About to spawn all players", "PhysicsMinigame")
		player_spawner.spawn_all_players(context.participating_players)
		Logger.system("DEBUG: Player spawning command completed", "PhysicsMinigame")
	else:
		Logger.warning("DEBUG: No player spawner available!", "PhysicsMinigame")
	
	# Spawn initial weapons if using item spawner
	if item_spawner:
		Logger.system("DEBUG: About to spawn initial weapons", "PhysicsMinigame")
		item_spawner.spawn_initial_items()
		Logger.system("DEBUG: Weapon spawning command completed", "PhysicsMinigame")
	else:
		Logger.warning("DEBUG: No item spawner available!", "PhysicsMinigame")
	
	# Start victory condition tracking
	if victory_condition_manager:
		victory_condition_manager.start_tracking()
	
	# Start respawn system
	if respawn_manager:
		respawn_manager.start_respawn_tracking()
	
	round_started.emit()
	
	Logger.system("DEBUG: PhysicsMinigame startup sequence completed", "PhysicsMinigame")
	
	# Hook for subclass start logic
	_on_physics_start()

## End the physics minigame
func _on_end(result: MinigameResult) -> void:
	Logger.game_flow("Ending PhysicsMinigame", "PhysicsMinigame")
	
	# Stop systems
	if respawn_manager:
		respawn_manager.stop_respawn_tracking()
	
	if item_spawner:
		item_spawner.stop_spawning()
		item_spawner.cleanup_items()
	
	if player_spawner:
		player_spawner.cleanup_players()
	
	round_ended.emit()
	
	# Hook for subclass cleanup
	_on_physics_end(result)

## Find arena and spawn point nodes automatically
func _find_arena_nodes() -> void:
	# Look for common node names in the scene
	arena = get_node_or_null("Arena")
	spawn_points = get_node_or_null("SpawnPoints") 
	respawn_points = get_node_or_null("RespawnPoints")
	item_spawn_points = get_node_or_null("ItemSpawnPoints")
	
	if arena:
		Logger.system("Found Arena node", "PhysicsMinigame")
	if spawn_points:
		Logger.system("Found SpawnPoints node", "PhysicsMinigame")
	if respawn_points:
		Logger.system("Found RespawnPoints node", "PhysicsMinigame")
	if item_spawn_points:
		Logger.system("Found ItemSpawnPoints node", "PhysicsMinigame")

## Get spawn points for players
func _get_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	if spawn_points:
		for child in spawn_points.get_children():
			if child is Node2D:
				points.append(child.global_position)
	else:
		# Default positions if no spawn points defined
		points = [
			Vector2(100, 300),
			Vector2(300, 300), 
			Vector2(500, 300),
			Vector2(700, 300)
		]
		Logger.warning("No SpawnPoints node found - using default positions", "PhysicsMinigame")
	
	return points

## Get respawn points for players
func _get_respawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	if respawn_points:
		for child in respawn_points.get_children():
			if child is Node2D:
				points.append(child.global_position)
	else:
		# Use spawn points as respawn points if no dedicated respawn points
		points = _get_spawn_points()
	
	return points

## Get weapon spawn points
func _get_item_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	if item_spawn_points:
		for child in item_spawn_points.get_children():
			if child is Node2D:
				points.append(child.global_position)
	else:
		# Default weapon positions if no spawn points defined
		points = [
			Vector2(200, 250),
			Vector2(400, 250),
			Vector2(600, 250)
		]
		Logger.warning("No ItemSpawnPoints node found - using default positions", "PhysicsMinigame")
	
	return points

## Handle player spawning
func _on_player_spawned(player: BasePlayer) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.system("Player spawned: " + player_name, "PhysicsMinigame")
	player_spawned.emit(player)
	
	# Hook for subclass player spawn handling
	_on_physics_player_spawned(player)

## Handle weapon spawning
func _on_weapon_spawned(weapon) -> void:
	Logger.system("Weapon spawned: " + weapon.item_name, "PhysicsMinigame")
	weapon_spawned.emit(weapon)
	
	# Hook for subclass weapon spawn handling
	_on_physics_weapon_spawned(weapon)

## Handle player respawning
func _on_player_respawned(player: BasePlayer) -> void:
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.game_flow("Player respawned: " + player_name, "PhysicsMinigame")
	
	# Hook for subclass respawn handling
	_on_physics_player_respawned(player)

## Handle victory conditions
func _on_victory_achieved(winner_data: Dictionary) -> void:
	Logger.game_flow("Victory achieved in PhysicsMinigame", "PhysicsMinigame")
	
	# Create victory result
	var result
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

## Helper method to update leadership based on current game state
## Override this in subclasses to define leadership criteria
func update_leadership_tracking() -> void:
	if not use_leadership_tracking:
		return
	
	var new_leader = _determine_current_leader()
	if new_leader != current_leader:
		if new_leader:
			award_leadership(new_leader)
		else:
			remove_leadership()

## Determine who should be the leader based on victory conditions
## Override this in subclasses for custom leadership logic
func _determine_current_leader() -> BasePlayer:
	if not victory_condition_manager or not player_spawner:
		return null
	
	var eligible_players = _get_eligible_players()
	if eligible_players.is_empty():
		return null
	
	# Default: leader based on victory condition type
	match victory_condition_manager.victory_type:
		VictoryConditionManager.VictoryType.ELIMINATION:
			return _get_elimination_leader(eligible_players)
		VictoryConditionManager.VictoryType.SCORE_BASED:
			return _get_score_leader(eligible_players)
		_:
			return null

## Get eligible players for leadership
func _get_eligible_players() -> Array[BasePlayer]:
	var eligible: Array[BasePlayer] = []
	if player_spawner:
		var all_players = player_spawner.get_all_players()
		for player in all_players:
			if player and player.player_data and player.player_data.is_alive:
				eligible.append(player)
	return eligible

## Get leader for elimination games (most lives, then most kills)
func _get_elimination_leader(players: Array[BasePlayer]) -> BasePlayer:
	var leader: BasePlayer = null
	var best_lives: int = -1
	var best_kills: int = -1
	
	for player in players:
		var lives = player.player_data.current_lives
		var kills = 0  # Default to 0 since we don't track kills in lifetime_stats during minigames
		
		if lives > best_lives or (lives == best_lives and kills > best_kills):
			leader = player
			best_lives = lives
			best_kills = kills
	
	return leader

## Get leader for score-based games
func _get_score_leader(players: Array[BasePlayer]) -> BasePlayer:
	var leader: BasePlayer = null
	var best_score: int = -1
	
	for player in players:
		var score = 0  # Default to 0 since we don't track scores in lifetime_stats during minigames
		if score > best_score:
			leader = player
			best_score = score
	
	return leader


## Override damage handling for physics minigames - apply damage directly to player health
func _on_damage_reported(victim_id: int, attacker_id: int, damage: int, source_name: String, victim_data: PlayerData) -> void:
	# Find the player in the game
	var victim_player: BasePlayer = null
	if player_spawner:
		victim_player = player_spawner.get_player(victim_id)
	
	if victim_player:
		# Apply damage directly to player health for immediate physics response
		victim_player.take_damage(damage)
		Logger.combat("PhysicsMinigame: Applied " + str(damage) + " damage from " + source_name + " to " + victim_data.player_name, "PhysicsMinigame")
	else:
		Logger.warning("PhysicsMinigame: Could not find player " + str(victim_id) + " to apply damage", "PhysicsMinigame")

# Virtual methods for subclasses to override

## Called when physics minigame initializes
func _on_physics_initialize() -> void:
	pass

## Called when physics minigame starts
func _on_physics_start() -> void:
	pass

## Called when physics minigame ends
func _on_physics_end(result: MinigameResult) -> void:
	pass

## Called when a player spawns
func _on_physics_player_spawned(player: BasePlayer) -> void:
	pass

## Called when a weapon spawns
func _on_physics_weapon_spawned(weapon) -> void:
	pass

## Called when a player respawns
func _on_physics_player_respawned(player: BasePlayer) -> void:
	pass

## Called when victory conditions are met
func _on_physics_victory(winner_data: Dictionary, result: MinigameResult) -> void:
	pass 

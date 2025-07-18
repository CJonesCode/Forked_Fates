extends Node

## Central Game State Manager with State Machine Architecture
## Handles scene transitions, player data, and overall game flow with formal state management

# Enhanced Game States
enum GameState {
	INITIALIZING,
	MENU,
	LOADING,
	MAP_VIEW,
	MINIGAME,
	PAUSED,
	GAME_OVER,
	TRANSITIONING
}

# State machine management
var current_state: GameState = GameState.INITIALIZING : set = _set_current_state
var previous_state: GameState = GameState.INITIALIZING
var state_transition_time: float = 0.0
var can_transition: bool = true

# State machine signals
signal state_changed(old_state: GameState, new_state: GameState)
signal state_transition_completed(state: GameState)
signal state_transition_failed(from_state: GameState, to_state: GameState, reason: String)

# Session data
var session_id: String = ""
var current_map_node: int = 0
var current_minigame: String = ""

# Player management
var players: Dictionary = {} # player_id -> PlayerData
var max_players: int = 4
var local_player_id: int = 0

# Networking (Steam integration)
var is_host: bool = false
var network_enabled: bool = false
var host_steam_id: int = 0
var connected_players: Dictionary = {}  # steam_id -> PlayerData

# Network signals
signal network_player_connected(steam_id: int, player_data: PlayerData)
signal network_player_disconnected(steam_id: int)
signal network_session_started()
signal network_session_ended()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to EventBus signals
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_lives_changed.connect(_on_player_lives_changed)
	EventBus.minigame_ended.connect(_on_minigame_ended)
	
	# Connect to Steam networking events (when available)
	call_deferred("_connect_steam_signals")
	
	# Don't initialize session here - wait for game mode selection
	# _initialize_session()  # REMOVED: Premature initialization
	_set_current_state(GameState.MENU)
	
	Logger.system("GameManager initialized with state machine - session will be initialized when game mode is selected", "GameManager")

## Connect to Steam networking signals (deferred to ensure SteamManager is ready)
func _connect_steam_signals() -> void:
	if not SteamManager:
		Logger.warning("SteamManager not available", "GameManager")
		return
	
	# Connect to Steam lobby events
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined.connect(_on_lobby_joined)
	SteamManager.lobby_left.connect(_on_lobby_left)
	SteamManager.player_joined_lobby.connect(_on_player_joined_lobby)
	SteamManager.player_left_lobby.connect(_on_player_left_lobby)
	
	Logger.system("Connected to Steam networking events", "GameManager")

## Set current state with validation and transition logic
func _set_current_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	
	# Check if transition is valid
	if not _is_valid_transition(current_state, new_state):
		var reason: String = "Invalid transition from " + GameState.keys()[current_state] + " to " + GameState.keys()[new_state]
		Logger.warning(reason, "GameManager")
		state_transition_failed.emit(current_state, new_state, reason)
		return
	
	# Perform state transition
	var old_state: GameState = current_state
	previous_state = current_state
	current_state = new_state
	state_transition_time = Time.get_unix_time_from_system()
	
	# Handle state transition logic
	_handle_state_transition(old_state, new_state)
	
	# Emit signals
	state_changed.emit(old_state, new_state)
	Logger.game_flow("State transition: " + GameState.keys()[old_state] + " -> " + GameState.keys()[new_state], "GameManager")
	
	# Complete transition after a frame
	call_deferred("_complete_state_transition", new_state)

## Complete state transition 
func _complete_state_transition(state: GameState) -> void:
	state_transition_completed.emit(state)

## Check if a state transition is valid
func _is_valid_transition(from_state: GameState, to_state: GameState) -> bool:
	# Define valid transitions
	match from_state:
		GameState.INITIALIZING:
			return to_state in [GameState.MENU, GameState.LOADING]
		GameState.MENU:
			return to_state in [GameState.MAP_VIEW, GameState.LOADING, GameState.GAME_OVER]
		GameState.LOADING:
			return to_state in [GameState.MENU, GameState.MAP_VIEW, GameState.MINIGAME]
		GameState.MAP_VIEW:
			return to_state in [GameState.MINIGAME, GameState.MENU, GameState.PAUSED, GameState.GAME_OVER, GameState.LOADING]
		GameState.MINIGAME:
			return to_state in [GameState.MAP_VIEW, GameState.PAUSED, GameState.GAME_OVER, GameState.LOADING]
		GameState.PAUSED:
			return to_state in [GameState.MAP_VIEW, GameState.MINIGAME, GameState.MENU]
		GameState.GAME_OVER:
			return to_state in [GameState.MENU, GameState.LOADING]
		GameState.TRANSITIONING:
			return true  # Transitioning can go to any state
		_:
			return false

## Handle state transition logic
func _handle_state_transition(old_state: GameState, new_state: GameState) -> void:
	# Exit old state
	_exit_state(old_state)
	
	# Enter new state
	_enter_state(new_state)

## Handle entering a new state
func _enter_state(state: GameState) -> void:
	match state:
		GameState.INITIALIZING:
			pass  # No logging needed for initialization
		GameState.MENU:
			_enter_menu_state()
		GameState.LOADING:
			_enter_loading_state()
		GameState.MAP_VIEW:
			_enter_map_view_state()
		GameState.MINIGAME:
			_enter_minigame_state()
		GameState.PAUSED:
			_enter_paused_state()
		GameState.GAME_OVER:
			_enter_game_over_state()
		GameState.TRANSITIONING:
			pass  # No specific logic needed

## Handle exiting a state
func _exit_state(state: GameState) -> void:
	match state:
		GameState.INITIALIZING:
			pass  # No cleanup needed
		GameState.MENU:
			pass  # No cleanup needed
		GameState.LOADING:
			pass  # No cleanup needed
		GameState.MAP_VIEW:
			pass  # No cleanup needed
		GameState.MINIGAME:
			_exit_minigame_state()
		GameState.PAUSED:
			pass  # No cleanup needed
		GameState.GAME_OVER:
			pass  # No cleanup needed
		GameState.TRANSITIONING:
			pass  # No cleanup needed

## State-specific enter methods
func _enter_menu_state() -> void:
	# Reset session data when returning to menu
	if previous_state == GameState.GAME_OVER:
		_initialize_session()

func _enter_loading_state() -> void:
	# Setup loading state
	pass

func _enter_map_view_state() -> void:
	# Ensure UI is properly shown
	pass

func _enter_minigame_state() -> void:
	# Minigame-specific setup
	pass

func _enter_paused_state() -> void:
	# Pause the game tree
	get_tree().paused = true

func _enter_game_over_state() -> void:
	# Game over logic
	pass

## State-specific exit methods
func _exit_minigame_state() -> void:
	current_minigame = ""

## Public methods for state transitions
func transition_to_menu() -> void:
	_set_current_state(GameState.MENU)

func transition_to_map_view() -> void:
	_set_current_state(GameState.MAP_VIEW)

func transition_to_minigame() -> void:
	_set_current_state(GameState.MINIGAME)

func transition_to_paused() -> void:
	_set_current_state(GameState.PAUSED)

func transition_to_game_over() -> void:
	_set_current_state(GameState.GAME_OVER)

## Get current game state
func get_current_state() -> GameState:
	return current_state

## Check if game is in a specific state
func is_in_state(state: GameState) -> bool:
	return current_state == state

## Check if game can be paused in current state
func can_pause() -> bool:
	return current_state in [GameState.MAP_VIEW, GameState.MINIGAME]

## Start local mode with proper session initialization
func start_local() -> void:
	Logger.system("Starting local mode", "GameManager")
	
	# Ensure we're in local mode
	network_enabled = false
	is_host = false
	
	# Resources will be loaded lazily when needed (following lazy loading principles)
	# No need for explicit preloading since all systems use lazy initialization
	
	# Initialize session with test players for local mode
	_initialize_session()
	
	# Transition to map view
	transition_to_map_view()

## Initialize a new game session
func _initialize_session() -> void:
	session_id = _generate_session_id()
	current_map_node = 0
	players.clear()
	
	# Only create test players for local mode
	# Multiplayer players will be added when they join the lobby
	if not network_enabled:
		# Create test players for local gameplay
		add_player(0, "Player 1")
		add_player(1, "Player 2")
		add_player(2, "Player 3")
		add_player(3, "Player 4")
		Logger.system("Created test players for local session", "GameManager")
	else:
		Logger.system("Initialized empty session for multiplayer", "GameManager")

## Generate a unique session ID
func _generate_session_id() -> String:
	var time_string := str(Time.get_unix_time_from_system())
	var random_suffix := str(randi() % 10000)
	return "session_" + time_string + "_" + random_suffix

## Add a player to the session
func add_player(player_id: int, player_name: String) -> bool:
	if players.size() >= max_players:
		Logger.warning("Cannot add player: session full", "GameManager")
		return false
	
	if players.has(player_id):
		Logger.warning("Player ID already exists: " + str(player_id), "GameManager")
		return false
	
	var player_data: PlayerData = PlayerData.new(player_id, player_name)
	
	players[player_id] = player_data
	Logger.system("Added player: " + player_name + " (ID: " + str(player_id) + ")", "GameManager")
	return true

## Remove a player from the session
func remove_player(player_id: int) -> bool:
	if not players.has(player_id):
		return false
	
	players.erase(player_id)
	Logger.system("Removed player ID: " + str(player_id), "GameManager")
	return true

## Get player data by ID
func get_player_data(player_id: int) -> PlayerData:
	return players.get(player_id, null)

## Update player health (internal - doesn't emit events to avoid loops)
func update_player_health(player_id: int, new_health: int) -> void:
	var player_data: PlayerData = get_player_data(player_id)
	if player_data:
		player_data.current_health = clamp(new_health, 0, player_data.max_health)
		player_data.is_alive = player_data.current_health > 0
		# Don't emit event here - this method is called FROM the event handler

## Start a minigame with proper context and player data
func start_minigame(minigame_type: String) -> void:
	current_minigame = minigame_type
	_set_current_state(GameState.MINIGAME)
	
	# Reset all player data to default values for new minigame session
	for player_data in players.values():
		player_data.reset_for_new_minigame()
	Logger.system("Reset all player data for new minigame session", "GameManager")
	
	# Create proper minigame context with player data
	var context: MinigameContext = MinigameContext.new()
	
	# Add all current players to the context
	for player_data in players.values():
		context.participating_players.append(player_data)
	
	# Create map snapshot (placeholder for now)
	context.map_state_snapshot = {
		"current_map_node": str(current_map_node),
		"available_nodes": [],
		"completed_nodes": [],
		"player_positions": {},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Launch the minigame using proper registry system instead of direct scene loading
	match minigame_type:
		"sudden_death":
			_launch_sudden_death_minigame(context)
		_:
			Logger.warning("Unknown minigame type: " + minigame_type, "GameManager")
			# Fallback to map view if unknown minigame
			_set_current_state(GameState.MAP_VIEW)
			EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")
	
	EventBus.minigame_started.emit(minigame_type)

## Launch sudden death minigame with proper initialization
func _launch_sudden_death_minigame(context: MinigameContext) -> void:
	# Load the minigame scene
	var minigame_scene: PackedScene = preload("res://scenes/minigames/sudden_death_minigame.tscn")
	if not minigame_scene:
		Logger.error("Failed to load sudden death minigame scene", "GameManager")
		return
	
	# Transition to the scene first
	EventBus.request_scene_transition("res://scenes/minigames/sudden_death_minigame.tscn")
	
	# Wait for scene to load, then initialize it
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame to ensure scene is fully ready
	
	# Find the minigame instance in the scene tree
	var minigame_instance: SuddenDeathMinigame = _find_sudden_death_instance()
	if minigame_instance:
		# Check if the minigame has already been initialized (to prevent double init)
		if minigame_instance.context:
			Logger.system("Minigame already initialized - skipping GameManager initialization", "GameManager")
			return
		
		Logger.system("Initializing sudden death minigame with " + str(context.participating_players.size()) + " players", "GameManager")
		
		# Remove tutorial completely for testing (don't just set duration to 0)
		Logger.system("DEBUG: Clearing tutorial content for faster testing", "GameManager")
		minigame_instance.tutorial_rules.clear()
		minigame_instance.tutorial_controls.clear()
		minigame_instance.tutorial_objective = ""
		minigame_instance.tutorial_tips.clear()
		
		minigame_instance.initialize_minigame(context)
		minigame_instance.start_minigame()
	else:
		Logger.error("Could not find sudden death minigame instance after scene load", "GameManager")

## Find the sudden death minigame instance in the current scene
func _find_sudden_death_instance() -> SuddenDeathMinigame:
	# Search through the scene tree for the minigame instance
	var scene_container: Node = get_tree().current_scene.get_node_or_null("SceneContainer")
	if scene_container:
		for child in scene_container.get_children():
			if child is SuddenDeathMinigame:
				return child
	
	# Also check if the current scene IS the minigame
	if get_tree().current_scene is SuddenDeathMinigame:
		return get_tree().current_scene as SuddenDeathMinigame
	
	# Search all children of current scene as fallback
	return _find_node_recursive(get_tree().current_scene, SuddenDeathMinigame) as SuddenDeathMinigame

## Recursively find a node of specific type
func _find_node_recursive(node: Node, node_type) -> Node:
	if node.get_script() and node.get_script().get_global_name() == node_type.get_global_name():
		return node
	
	for child in node.get_children():
		var result = _find_node_recursive(child, node_type)
		if result:
			return result
	
	return null

## Get alive players count
func get_alive_players_count() -> int:
	var count := 0
	for player_data in players.values():
		if player_data.is_alive:
			count += 1
	return count

## Check if game should end
func check_game_end_condition() -> bool:
	return get_alive_players_count() <= 1

# Signal handlers
func _on_player_died(player_id: int) -> void:
	var player_data: PlayerData = get_player_data(player_id)
	if player_data:
		player_data.is_alive = false
		player_data.current_health = 0
		Logger.game_flow("Player died: " + player_data.player_name, "GameManager")
		
		# NOTE: Lives decrementing is now handled by individual minigames
		# This allows for different game modes (infinite lives, survival, etc.)

func _on_player_health_changed(player_id: int, new_health: int, max_health: int) -> void:
	Logger.debug("GameManager received health change for Player " + str(player_id) + ": " + str(new_health), "GameManager")
	var player_data: PlayerData = get_player_data(player_id)
	if player_data:
		var old_health: int = player_data.current_health
		Logger.debug("GameManager PlayerData before: " + str(old_health) + "/" + str(player_data.max_health), "GameManager")
		update_player_health(player_id, new_health)
		Logger.debug("GameManager PlayerData after: " + str(player_data.current_health) + "/" + str(player_data.max_health) + " = " + str(player_data.get_health_percentage()) + "%", "GameManager")
	else:
		Logger.warning("GameManager: No player data found for Player " + str(player_id), "GameManager")

func _on_player_lives_changed(player_id: int, new_lives: int) -> void:
	var player_data: PlayerData = get_player_data(player_id)
	if player_data:
		player_data.current_lives = new_lives
		Logger.game_flow("Player " + player_data.player_name + " lives updated: " + str(new_lives), "GameManager")

func _on_minigame_ended(winner_id: int, results: Dictionary) -> void:
	Logger.game_flow("Minigame ended. Winner: " + str(winner_id), "GameManager")
	# Return to map view
	_set_current_state(GameState.MAP_VIEW)

## Steam Networking Functions

## Host a multiplayer game session
func host_game() -> void:
	if not SteamManager or not SteamManager.is_steam_enabled:
		Logger.warning("Cannot host - Steam not available", "GameManager")
		return
	
	is_host = true
	host_steam_id = SteamManager.get_local_steam_id()
	network_enabled = true
	
	# Resources will be loaded lazily when needed (following lazy loading principles)
	# No need for explicit preloading since all systems use lazy initialization
	
	# Initialize empty multiplayer session
	_initialize_session()  # This will create empty session since network_enabled = true
	connected_players.clear()
	
	# Create Steam lobby
	SteamManager.create_lobby()
	Logger.system("Starting to host game session", "GameManager")

## Join a multiplayer game session
func join_game(lobby_id: int) -> void:
	if not SteamManager or not SteamManager.is_steam_enabled:
		Logger.warning("Cannot join - Steam not available", "GameManager")
		return
	
	is_host = false
	network_enabled = true
	
	# Initialize empty multiplayer session
	_initialize_session()  # This will create empty session since network_enabled = true
	connected_players.clear()
	
	# Join Steam lobby
	SteamManager.join_lobby(lobby_id)
	Logger.system("Attempting to join game session: " + str(lobby_id), "GameManager")

## Leave current multiplayer session
func leave_game() -> void:
	if not network_enabled:
		return
	
	if SteamManager and SteamManager.is_steam_enabled:
		SteamManager.leave_lobby()
	
	# Reset networking state
	is_host = false
	network_enabled = false
	host_steam_id = 0
	connected_players.clear()
	
	# Reinitialize session for local mode
	_initialize_session()
	
	Logger.system("Left multiplayer session", "GameManager")
	network_session_ended.emit()

## Add a network player to the session
func add_network_player(steam_id: int, player_name: String) -> bool:
	if connected_players.has(steam_id):
		Logger.warning("Network player already exists: " + str(steam_id), "GameManager")
		return false
	
	# Find next available player ID
	var player_id: int = _get_next_player_id()
	if player_id == -1:
		Logger.warning("Cannot add network player: session full", "GameManager")
		return false
	
	var player_data: PlayerData = PlayerData.new(player_id, player_name)
	
	# Add to both local players and connected players tracking
	players[player_id] = player_data
	connected_players[steam_id] = player_data
	
	Logger.system("Added network player: " + player_name + " (Steam ID: " + str(steam_id) + ", Player ID: " + str(player_id) + ")", "GameManager")
	network_player_connected.emit(steam_id, player_data)
	
	# TODO: Send local player data to new player if we're host
	# This requires implementing player data messaging in SteamManager
	if is_host:
		var local_player = get_player_data(local_player_id)
		if local_player:
			# TODO: SteamManager.send_player_data(local_player, steam_id)
			Logger.debug("TODO: Send player data to new player " + str(steam_id), "GameManager")
	
	return true

## Remove a network player from the session
func remove_network_player(steam_id: int) -> bool:
	if not connected_players.has(steam_id):
		return false
	
	var player_data: PlayerData = connected_players[steam_id]
	var player_id: int = player_data.player_id
	
	# Remove from both tracking dictionaries
	connected_players.erase(steam_id)
	players.erase(player_id)
	
	Logger.system("Removed network player: " + player_data.player_name + " (Steam ID: " + str(steam_id) + ")", "GameManager")
	network_player_disconnected.emit(steam_id)
	
	return true

## Get next available player ID for network players
func _get_next_player_id() -> int:
	for i in range(max_players):
		if not players.has(i):
			return i
	return -1

## Steam event handlers
func _on_lobby_created(lobby_id: int) -> void:
	Logger.system("Game lobby created: " + str(lobby_id), "GameManager")
	
	# Only emit session started once for the host
	if not network_enabled:
		Logger.warning("Lobby created but network not enabled - this shouldn't happen", "GameManager")
		return
	
	network_session_started.emit()
	
	# Add self as first player (host)
	var local_steam_id = SteamManager.get_local_steam_id()
	var local_name = SteamManager.get_player_name(local_steam_id)
	add_network_player(local_steam_id, local_name)

func _on_lobby_joined(lobby_id: int) -> void:
	Logger.system("Joined game lobby: " + str(lobby_id), "GameManager")
	
	# Only emit session started for clients (not hosts who already did in _on_lobby_created)
	if not is_host:
		network_session_started.emit()
		
		# TODO: Send our player data to the host
		# This requires implementing player data messaging in SteamManager
		var local_player = get_player_data(local_player_id)
		if not local_player:
			# Create local player if it doesn't exist
			var local_steam_id = SteamManager.get_local_steam_id()
			var local_name = SteamManager.get_player_name(local_steam_id)
			add_player(local_player_id, local_name)
			local_player = get_player_data(local_player_id)
		
		if local_player:
			# TODO: SteamManager.send_player_data(local_player)
			Logger.debug("TODO: Send player data to host", "GameManager")
	else:
		Logger.debug("Host received lobby_joined signal - Steam automatically joins host to their own lobby", "GameManager")

func _on_lobby_left(lobby_id: int) -> void:
	Logger.system("Left lobby: " + str(lobby_id), "GameManager")
	leave_game()

func _on_player_joined_lobby(steam_id: int) -> void:
	if is_host:
		var player_name = SteamManager.get_player_name(steam_id)
		Logger.system("Player joined lobby: " + player_name + " (" + str(steam_id) + ")", "GameManager")
		add_network_player(steam_id, player_name)

func _on_player_left_lobby(steam_id: int) -> void:
	var player_name = SteamManager.get_player_name(steam_id)
	Logger.system("Player left lobby: " + player_name + " (" + str(steam_id) + ")", "GameManager")
	remove_network_player(steam_id)

## Get multiplayer session info
func get_lobby_info() -> Dictionary:
	if not network_enabled or not SteamManager:
		return {}
	
	return {
		"lobby_id": SteamManager.current_lobby_id,
		"is_host": is_host,
		"player_count": connected_players.size(),
		"max_players": max_players,
		"players": get_network_player_names()
	}

func get_network_player_names() -> Array[String]:
	var names: Array[String] = []
	for player_data in connected_players.values():
		names.append(player_data.player_name)
	return names

func is_multiplayer_session() -> bool:
	return network_enabled and connected_players.size() > 1 

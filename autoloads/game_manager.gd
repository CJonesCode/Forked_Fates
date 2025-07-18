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

# Networking preparation (for future use)
var is_host: bool = false
var network_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect to EventBus signals
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_lives_changed.connect(_on_player_lives_changed)
	EventBus.minigame_ended.connect(_on_minigame_ended)
	
	# Initialize session and transition to menu
	_initialize_session()
	_set_current_state(GameState.MENU)
	
	Logger.system("GameManager initialized with state machine", "GameManager")

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

## Initialize a new game session
func _initialize_session() -> void:
	session_id = _generate_session_id()
	current_map_node = 0
	players.clear()
	
	# Create test players for local gameplay
	add_player(0, "Player 1")
	add_player(1, "Player 2")
	add_player(2, "Player 3")
	add_player(3, "Player 4")

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
		
		# For debugging: skip tutorial to test spawning
		Logger.system("DEBUG: Skipping tutorial for faster testing", "GameManager")
		minigame_instance.tutorial_duration = 0.0  # Skip tutorial
		
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

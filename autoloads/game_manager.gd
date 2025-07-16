extends Node

## Central game state manager and session coordinator
## Handles scene transitions, player data, and overall game flow

# Game states
enum GameState {
	MENU,
	MAP_VIEW,
	MINIGAME,
	PAUSED,
	GAME_OVER
}

# PlayerData class is defined in scripts/core/player_data.gd

# Current game state
var current_state: GameState = GameState.MENU
var previous_state: GameState = GameState.MENU

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
	
	# Connect to EventBus signals (removed scene_transition_requested - handled by Main)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_lives_changed.connect(_on_player_lives_changed)
	EventBus.minigame_ended.connect(_on_minigame_ended)
	
	# Initialize session
	_initialize_session()
	print("GameManager initialized")

## Initialize a new game session
func _initialize_session() -> void:
	session_id = _generate_session_id()
	current_map_node = 0
	current_state = GameState.MENU
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
		print("Cannot add player: session full")
		return false
	
	if players.has(player_id):
		print("Player ID already exists: ", player_id)
		return false
	
	var player_data = PlayerData.new(player_id, player_name)
	
	players[player_id] = player_data
	print("Added player: ", player_name, " (ID: ", player_id, ")")
	return true

## Remove a player from the session
func remove_player(player_id: int) -> bool:
	if not players.has(player_id):
		return false
	
	players.erase(player_id)
	print("Removed player ID: ", player_id)
	return true

## Get player data by ID
func get_player_data(player_id: int) -> PlayerData:
	return players.get(player_id, null)

## Update player health (internal - doesn't emit events to avoid loops)
func update_player_health(player_id: int, new_health: int) -> void:
	var player_data = get_player_data(player_id)
	if player_data:
		player_data.current_health = clamp(new_health, 0, player_data.max_health)
		player_data.is_alive = player_data.current_health > 0
		# Don't emit event here - this method is called FROM the event handler

## Change game state
func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	
	previous_state = current_state
	current_state = new_state
	print("Game state changed: ", GameState.keys()[previous_state], " -> ", GameState.keys()[current_state])

## Start a minigame
func start_minigame(minigame_type: String) -> void:
	current_minigame = minigame_type
	change_state(GameState.MINIGAME)
	
	# Transition directly to the specific minigame scene
	match minigame_type:
		"sudden_death":
			EventBus.request_scene_transition("res://scenes/minigames/sudden_death_minigame.tscn")
		_:
			print("Unknown minigame type: ", minigame_type)
			# Fallback to map view if unknown minigame
			change_state(GameState.MAP_VIEW)
			EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")
	
	EventBus.minigame_started.emit(minigame_type)

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
	var player_data = get_player_data(player_id)
	if player_data:
		player_data.is_alive = false
		player_data.current_health = 0
		print("Player died: ", player_data.player_name)

func _on_player_health_changed(player_id: int, new_health: int) -> void:
	print("🎮 GameManager received health change for Player ", player_id, ": ", new_health)
	var player_data = get_player_data(player_id)
	if player_data:
		var old_health = player_data.current_health
		print("   GameManager PlayerData before: ", old_health, "/", player_data.max_health)
		update_player_health(player_id, new_health)
		print("   GameManager PlayerData after: ", player_data.current_health, "/", player_data.max_health, " = ", player_data.get_health_percentage(), "%")
	else:
		print("   ❌ GameManager: No player data found for Player ", player_id)

func _on_player_lives_changed(player_id: int, new_lives: int) -> void:
	var player_data = get_player_data(player_id)
	if player_data:
		player_data.current_lives = new_lives
		print("Player ", player_data.player_name, " lives updated: ", new_lives)

func _on_minigame_ended(winner_id: int, results: Dictionary) -> void:
	print("Minigame ended. Winner: ", winner_id)
	current_minigame = ""
	# Return to map view
	change_state(GameState.MAP_VIEW) 

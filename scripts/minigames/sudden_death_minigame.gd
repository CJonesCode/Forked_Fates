class_name SuddenDeathMinigame
extends PhysicsMinigame

@onready var ui_overlay: CanvasLayer = $UIOverlay
@onready var back_button: Button = $UIOverlay/BackButton
@onready var game_timer_label: Label = $UIOverlay/GameTimer

# Player HUD now managed by UIManager
var game_timer: float = 0.0

func _ready() -> void:
	super()
	
	minigame_name = "Sudden Death"
	minigame_description = "3-life elimination combat with ragdoll physics"
	min_players = 2
	max_players = 4
	estimated_duration = 180.0
	tags = ["combat", "elimination", "physics"]
	
	tutorial_rules = [
		"Each player starts with 3 lives",
		"Lose a life when your health reaches 0",
		"Players respawn after 3 seconds if they have lives remaining",
		"Items spawn around the arena - collect them for advantages",
		"Last player standing wins!"
	]
	tutorial_objective = "Be the last player alive!"
	tutorial_tips = [
		"Collect weapons like pistols and bats",
		"Use ragdoll physics to avoid attacks",
		"Control territory around item spawn points"
	]
	tutorial_duration = 7.0
	
	# ONLY initialize from GameManager if context hasn't been set yet
	# This prevents double initialization
	if not context:
		Logger.system("Context not set - checking for fallback initialization", "SuddenDeathMinigame")
		_initialize_from_game_manager()
	else:
		Logger.system("Context already set - skipping fallback initialization", "SuddenDeathMinigame")

## Initialize minigame context from GameManager (fallback for direct scene loading)
func _initialize_from_game_manager() -> void:
	if not GameManager or GameManager.players.is_empty():
		Logger.warning("No players available from GameManager for minigame initialization", "SuddenDeathMinigame")
		return
	
	Logger.system("Creating minigame context from GameManager player data", "SuddenDeathMinigame")
	
	# Create context with GameManager player data
	var fallback_context: MinigameContext = MinigameContext.new()
	
	# Add all GameManager players to context
	for player_data in GameManager.players.values():
		fallback_context.participating_players.append(player_data)
	
	# Create basic map snapshot
	fallback_context.map_state_snapshot = {
		"current_map_node": str(GameManager.current_map_node),
		"available_nodes": [],
		"completed_nodes": [],
		"player_positions": {},
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Initialize and start the minigame
	initialize_minigame(fallback_context)
	
	# Start after a brief delay to ensure everything is ready
	await get_tree().process_frame
	start_minigame()

func _on_physics_initialize() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
	
	victory_condition_manager.victory_type = VictoryConditionManager.VictoryType.ELIMINATION
	respawn_manager.respawn_delay = 3.0
	respawn_manager.max_respawns = -1  # Use lives system instead
	
	# Connect to player death events for lives management
	EventBus.player_died.connect(_on_sudden_death_player_died)
	
	# Show player HUD using UIManager
	var player_data_array: Array[PlayerData] = []
	for player_data in GameManager.players.values():
		player_data_array.append(player_data)
	UIManager.show_game_hud(player_data_array)

## Override tutorial process to add debug logging
func _process(delta: float) -> void:
	super(delta)
	
	# Add debug logging for tutorial state
	if is_showing_tutorial and tutorial_timer > 0:
		if int(tutorial_timer) != int(tutorial_timer + delta):  # Log every second
			Logger.system("Tutorial countdown: " + str(int(tutorial_timer)) + " seconds remaining", "SuddenDeathMinigame")
	
	# Game timer update
	if is_active and not is_paused:
		game_timer += delta
		_update_game_timer_display()

## Override tutorial finish to add logging
func finish_tutorial() -> void:
	Logger.system("SuddenDeathMinigame finishing tutorial", "SuddenDeathMinigame")
	super()

## Override start gameplay to add logging
func _start_gameplay() -> void:
	Logger.system("SuddenDeathMinigame starting gameplay", "SuddenDeathMinigame") 
	super()

## Override physics start to add logging  
func _on_physics_start() -> void:
	Logger.system("SuddenDeathMinigame physics start - spawning should begin", "SuddenDeathMinigame")
	game_timer = 0.0
	_update_game_timer_display()
	EventBus.round_started.emit()

func _update_game_timer_display() -> void:
	if game_timer_label:
		var minutes: int = int(game_timer) / 60
		var seconds: int = int(game_timer) % 60
		game_timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_back_button_pressed() -> void:
	abort_minigame()
	EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")
	GameManager.transition_to_map_view()

func _on_physics_victory(winner_data: Dictionary, result: MinigameResult) -> void:
	result.statistics["game_duration"] = game_timer
	
	if winner_data.has("winner_id"):
		var winner_data_obj: PlayerData = context.get_player_data(winner_data.winner_id)
		if winner_data_obj:
			result.statistics["winner_name"] = winner_data_obj.player_name
	
	EventBus.minigame_ended.emit(result.winners[0] if not result.winners.is_empty() else -1, {
		"minigame_type": "sudden_death",
		"duration": game_timer,
		"winner_name": result.statistics.get("winner_name", "No One")
	})

## Handle player death for Sudden Death specific rules (3 lives elimination)
func _on_sudden_death_player_died(player_id: int) -> void:
	var player_data: PlayerData = GameManager.get_player_data(player_id)
	if not player_data:
		return
	
	# Decrement lives for Sudden Death mode
	player_data.current_lives -= 1
	Logger.game_flow("Sudden Death: " + player_data.player_name + " died (Lives remaining: " + str(player_data.current_lives) + ")", "SuddenDeathMinigame")
	
	# Update UI
	EventBus.emit_player_lives_changed(player_id, player_data.current_lives)
	
	# Check if player is eliminated (out of lives)
	if player_data.is_out_of_lives():
		Logger.game_flow("Sudden Death: " + player_data.player_name + " ELIMINATED - out of lives!", "SuddenDeathMinigame")
		
		# Block player from respawning
		if respawn_manager:
			respawn_manager.block_player_respawn(player_id)
		
		# Eliminate from victory tracking
		if victory_condition_manager:
			victory_condition_manager.eliminate_player(player_id)

## Clean up Sudden Death specific connections
func _on_physics_end(result: MinigameResult) -> void:
	# Disconnect from death events
	if EventBus.player_died.is_connected(_on_sudden_death_player_died):
		EventBus.player_died.disconnect(_on_sudden_death_player_died)
	
	# Clear respawn blocks
	if respawn_manager:
		respawn_manager.clear_all_respawn_blocks() 

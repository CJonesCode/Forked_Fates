class_name SuddenDeathMinigame
extends PhysicsMinigame

@onready var ui_overlay: CanvasLayer = $UIOverlay
@onready var back_button: Button = $UIOverlay/BackButton
@onready var game_timer_label: Label = $UIOverlay/GameTimer

# Game state tracking
var game_timer: float = 0.0

# Kill tracking (simplified - no more timing windows)
var player_kills: Dictionary = {}  # player_id -> kill_count

func _ready() -> void:
	super()
	
	minigame_name = "Sudden Death"
	minigame_description = "3-life elimination combat with ragdoll physics and projectile weapons"
	min_players = 2
	max_players = 4
	estimated_duration = 180.0
	tags = ["combat", "elimination", "physics", "weapons"]
	
	# Throwing-centric tutorial content
	tutorial_rules = [
		"Each player starts with 3 lives (3 deaths allowed)",
		"Lose a life each time your health reaches 0",
		"Players respawn after 3 seconds if they have lives remaining",
		"Weapons spawn around the arena - grab them quickly!",
		"Last player standing wins!"
	]
	tutorial_objective = "Be the last player alive in projectile-based combat!"
	tutorial_tips = [
		"FIRE weapons to attack enemies at range",
		"THROW weapons as projectiles for surprise attacks",
		"PICK UP weapons dropped by defeated players",
		"Thrown weapons deal damage on impact!",
		"Use ragdoll physics to dodge incoming attacks",
		"Control territory around weapon spawn points"
	]
	tutorial_duration = 7.0
	
	# Don't auto-initialize in _ready() - wait for explicit initialization
	# The GameManager will call initialize_minigame() and start_minigame() when appropriate
	Logger.system("SuddenDeathMinigame ready with projectile weapon system - waiting for explicit initialization", "SuddenDeathMinigame")

## Initialize minigame context from GameManager (fallback for direct scene loading)
## DEPRECATED: This method should not be called automatically in _ready()
func _initialize_from_game_manager() -> void:
	Logger.warning("_initialize_from_game_manager() called - this should only be used for standalone testing", "SuddenDeathMinigame")
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
	
	# Connect to kill events for kill tracking (simplified)
	EventBus.player_killed_by.connect(_on_player_killed_by)
	
	# Show player HUD using UIManager
	var player_data_array: Array[PlayerData] = []
	for player_data in GameManager.players.values():
		player_data_array.append(player_data)
	UIManager.show_game_hud(player_data_array)
	
	# Connect HUD to VictoryConditionManager for kill tracking (new)
	await get_tree().process_frame  # Wait for HUD to be ready
	_connect_hud_to_victory_manager()
	
	Logger.system("SuddenDeathMinigame initialized with projectile weapon system", "SuddenDeathMinigame")

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

## Projectile weapon system integration
func _on_physics_weapon_spawned(weapon) -> void:
	Logger.combat("Projectile weapon spawned: " + weapon.item_name + " in Sudden Death arena", "SuddenDeathMinigame")
	
	# Could add weapon-specific effects here
	# e.g., highlight powerful weapons, add spawn effects, etc.

func _update_game_timer_display() -> void:
	if game_timer_label:
		var minutes: int = int(game_timer) / 60
		var seconds: int = int(game_timer) % 60
		game_timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

func _on_back_button_pressed() -> void:
	# BaseMinigame.abort_minigame() now handles cleanup timing automatically
	await abort_minigame()
	
	# Transition after cleanup is complete
	EventBus.request_scene_transition("res://scenes/ui/map_view.tscn")
	GameManager.transition_to_map_view()

func _on_physics_victory(winner_data: Dictionary, result: MinigameResult) -> void:
	result.statistics["game_duration"] = game_timer
	
	# Add projectile weapon statistics
	if item_spawner:
		result.statistics["weapons_spawned"] = item_spawner.get_spawn_statistics().get("total_weapons", 0)
	
	if winner_data.has("winner_id"):
		var winner_data_obj: PlayerData = context.get_player_data(winner_data.winner_id)
		if winner_data_obj:
			result.statistics["winner_name"] = winner_data_obj.player_name
	
	# Create comprehensive MinigameStats for each participating player
	var all_participants: Array[int] = context.get_player_ids()
	for i in range(all_participants.size()):
		var player_id: int = all_participants[i]
		var player_data: PlayerData = context.get_player_data(player_id)
		if player_data:
			var minigame_stats: MinigameStats = _create_elimination_stats(
				player_id, 
				player_data.player_name, 
				i + 1,  # Rank (1st, 2nd, etc.) - TODO: Calculate actual final rankings
				player_data.player_id == winner_data.get("winner_id", -1)
			)
			result.add_player_stats(minigame_stats)
	
	# Add updated party progress to result for comprehensive data flow
	result.party_progress = GameManager.get_party_progress()
	
	EventBus.minigame_ended.emit(result.winners[0] if not result.winners.is_empty() else -1, {
		"minigame_type": "sudden_death",
		"duration": game_timer,
		"winner_name": result.statistics.get("winner_name", "No One"),
		"weapons_used": result.statistics.get("weapons_spawned", 0)
	})

## Create detailed elimination statistics for a player
func _create_elimination_stats(player_id: int, player_name: String, rank: int, was_winner: bool) -> MinigameStats:
	var stats: MinigameStats = MinigameStats.new(player_id, player_name)
	
	# Core performance metrics
	stats.rank = rank
	stats.score = _calculate_player_score(player_id)
	stats.performance_rating = _get_performance_rating(rank, was_winner)
	
	# Sudden Death specific statistics
	stats.add_stat("survival_time", game_timer if was_winner else 0.0, "time")
	stats.add_stat("eliminations", _get_player_eliminations(player_id))
	stats.add_stat("deaths", _get_player_deaths(player_id))
	stats.add_stat("damage_dealt", _get_player_damage_dealt(player_id))
	stats.add_stat("damage_taken", _get_player_damage_taken(player_id))
	stats.add_stat("weapons_used", _get_player_weapons_used(player_id))
	
	# Add achievements based on performance
	_add_elimination_achievements(stats, player_id, was_winner)
	
	# Add rewards based on rank and performance
	_add_elimination_rewards(stats, rank, was_winner)
	
	# Add display formatting hints
	_setup_elimination_display_data(stats)
	
	return stats

## Calculate score for a player based on performance
func _calculate_player_score(player_id: int) -> int:
	var base_score: int = 100  # Base participation score
	var eliminations: int = _get_player_eliminations(player_id)
	var deaths: int = _get_player_deaths(player_id)
	var damage_dealt: int = _get_player_damage_dealt(player_id)
	
	# Score formula: base + (eliminations * 50) + (damage_dealt / 10) - (deaths * 25)
	var score: int = base_score + (eliminations * 50) + (damage_dealt / 10) - (deaths * 25)
	return max(0, score)  # Ensure non-negative score

## Get performance rating based on rank and winner status
func _get_performance_rating(rank: int, was_winner: bool) -> String:
	if was_winner:
		return "Excellent"
	elif rank <= 2:
		return "Good"
	elif rank <= 3:
		return "Average"
	else:
		return "Poor"

## Add achievements based on player performance
func _add_elimination_achievements(stats: MinigameStats, player_id: int, was_winner: bool) -> void:
	var eliminations: int = _get_player_eliminations(player_id)
	var deaths: int = _get_player_deaths(player_id)
	var damage_dealt: int = _get_player_damage_dealt(player_id)
	
	if was_winner:
		stats.achievements.append("Last One Standing")
	
	if eliminations >= 3:
		stats.achievements.append("Triple Eliminator")
	elif eliminations >= 2:
		stats.achievements.append("Double Trouble")
	
	if deaths == 0:
		stats.achievements.append("Untouchable")
	
	if damage_dealt >= 200:
		stats.achievements.append("Heavy Hitter")
	
	if eliminations > 0 and deaths == 0:
		stats.achievements.append("Perfect Round")

## Add rewards based on performance
func _add_elimination_rewards(stats: MinigameStats, rank: int, was_winner: bool) -> void:
	if was_winner:
		stats.rewards_earned.append("victory_bonus")
	
	if rank <= 2:
		stats.rewards_earned.append("health_boost")
	
	# Special rewards for achievements
	if "Triple Eliminator" in stats.achievements:
		stats.rewards_earned.append("weapon_mastery")
	
	if "Untouchable" in stats.achievements:
		stats.rewards_earned.append("defensive_bonus")

## Setup display formatting hints for UI
func _setup_elimination_display_data(stats: MinigameStats) -> void:
	stats.display_data["highlight_stats"] = ["eliminations", "survival_time", "damage_dealt"]
	stats.display_data["format_types"] = {
		"survival_time": "time",
		"damage_dealt": "number",
		"damage_taken": "number"
	}
	stats.display_data["stat_labels"] = {
		"eliminations": "Enemies Defeated",
		"deaths": "Times Defeated",
		"damage_dealt": "Damage Output",
		"damage_taken": "Damage Received",
		"weapons_used": "Weapons Collected",
		"survival_time": "Survival Time"
	}

## Get player elimination count (placeholder - integrate with damage system)
func _get_player_eliminations(player_id: int) -> int:
	# TODO: Track actual eliminations from damage system
	return 0

## Get player death count (from current lives)
func _get_player_deaths(player_id: int) -> int:
	var player_data: PlayerData = context.get_player_data(player_id)
	if player_data:
		return player_data.max_lives - player_data.current_lives
	return 0

## Get damage dealt by player (placeholder - integrate with damage system)
func _get_player_damage_dealt(player_id: int) -> int:
	# TODO: Track actual damage dealt from damage system
	return 0

## Get damage taken by player (placeholder - integrate with damage system)
func _get_player_damage_taken(player_id: int) -> int:
	# TODO: Track actual damage taken from damage system  
	return 0

## Get weapons used by player (placeholder - integrate with item system)
func _get_player_weapons_used(player_id: int) -> int:
	# TODO: Track actual weapons picked up/used
	return 0

## Handle player death for Sudden Death specific rules (3 lives elimination)
## Lives Semantics: 3 lives = 3 deaths allowed before elimination
## - Start with 3 lives
## - Die → 2 lives, can respawn
## - Die → 1 life, can respawn  
## - Die → 0 lives, eliminated (no respawn)
func _on_sudden_death_player_died(player_id: int) -> void:
	var player_data: PlayerData = GameManager.get_player_data(player_id)
	if not player_data:
		return
	
	# Prevent negative lives - only decrement if player has lives remaining
	if player_data.current_lives <= 0:
		Logger.warning("Sudden Death: " + player_data.player_name + " died but already has 0 lives - not decrementing further", "SuddenDeathMinigame")
		return
	
	# Decrement lives for Sudden Death mode (one death used)
	player_data.current_lives -= 1
	Logger.game_flow("Sudden Death: " + player_data.player_name + " died (Lives remaining: " + str(player_data.current_lives) + ")", "SuddenDeathMinigame")
	
	# Update UI
	EventBus.emit_player_lives_changed(player_id, player_data.current_lives)
	
	# Update leadership tracking since lives changed
	update_leadership_tracking()
	
	# Check if player is eliminated (out of deaths allowed)
	if player_data.is_out_of_lives():
		Logger.game_flow("Sudden Death: " + player_data.player_name + " ELIMINATED - out of lives!", "SuddenDeathMinigame")
		
		# Block player from respawning
		if respawn_manager:
			respawn_manager.block_player_respawn(player_id)
		
		# Eliminate from victory tracking
		if victory_condition_manager:
			victory_condition_manager.eliminate_player(player_id)
		
		# Update leadership tracking since player elimination might change leader
		update_leadership_tracking()

## Handle kill tracking (simplified - no timing windows)
func _on_player_killed_by(victim_id: int, killer_id: int, source_name: String) -> void:
	Logger.debug("⚔️ SUDDEN DEATH: Kill event received - victim=" + str(victim_id) + " killer=" + str(killer_id) + " source=" + source_name, "SuddenDeathMinigame")
	
	# Only track kills from actual players (not environment)
	if killer_id == -1:
		Logger.combat("⚔️ Player " + str(victim_id) + " died from " + source_name + " (environmental) - no kill awarded", "SuddenDeathMinigame")
		return
	
	Logger.combat("⚔️ ✅ PROCESSING KILL: Player " + str(killer_id) + " killed Player " + str(victim_id) + " with " + source_name, "SuddenDeathMinigame")
	
	# Award the kill to the killer
	if victory_condition_manager:
		Logger.debug("⚔️ Adding score to victory manager for player " + str(killer_id), "SuddenDeathMinigame")
		victory_condition_manager.add_score(killer_id, 1)
		
		# Update local kill tracking
		var old_kills = player_kills.get(killer_id, 0)
		player_kills[killer_id] = old_kills + 1
		var new_kills = player_kills[killer_id]
		
		Logger.combat("⚔️ ✅ KILL CREDITED: Player " + str(killer_id) + " kills: " + str(old_kills) + " -> " + str(new_kills), "SuddenDeathMinigame")
		
		var killer_data = GameManager.get_player_data(killer_id)
		var victim_data = GameManager.get_player_data(victim_id)
		if killer_data and victim_data:
			Logger.combat("⚔️ Kill credited: " + killer_data.player_name + " eliminated " + victim_data.player_name + " with " + source_name, "SuddenDeathMinigame")
			
			# Kill feed automatically shows via EventBus.player_killed_by signal
		else:
			Logger.error("⚔️ ❌ Failed to get player data for kill logging - killer=" + str(killer_id) + " victim=" + str(victim_id), "SuddenDeathMinigame")
		
		# Log the new kill count
		Logger.combat("⚔️ Player " + str(killer_id) + " now has " + str(new_kills) + " kills", "SuddenDeathMinigame")
		
		# Update leadership tracking since kill count changed
		update_leadership_tracking()
	else:
		Logger.error("⚔️ ❌ No victory_condition_manager - kill not credited!", "SuddenDeathMinigame")

## Override base class kill tracking to use simplified local tracking
func _get_player_kills(player_id: int) -> int:
	return player_kills.get(player_id, 0)

## Connect PlayerHUD to VictoryConditionManager for kill tracking (new)
func _connect_hud_to_victory_manager() -> void:
	Logger.system("Attempting to connect PlayerHUD to VictoryConditionManager...", "SuddenDeathMinigame")
	
	if not victory_condition_manager:
		Logger.warning("No VictoryConditionManager available for HUD connection", "SuddenDeathMinigame")
		return
	else:
		Logger.system("VictoryConditionManager found: " + str(victory_condition_manager), "SuddenDeathMinigame")
	
	# Get the current HUD from UIManager
	var hud_controller = UIManager.get_hud_controller()
	if not hud_controller:
		Logger.warning("No HUD controller available", "SuddenDeathMinigame")
		return
	else:
		Logger.system("HUD controller found: " + str(hud_controller), "SuddenDeathMinigame")
	
	var player_hud = hud_controller.get_current_hud()
	if not player_hud:
		Logger.warning("No PlayerHUD available for connection", "SuddenDeathMinigame")
		return
	else:
		Logger.system("PlayerHUD found: " + str(player_hud), "SuddenDeathMinigame")
	
	# Connect the VictoryConditionManager's score_updated signal to the HUD
	if not victory_condition_manager.score_updated.is_connected(player_hud._on_player_kills_changed):
		victory_condition_manager.score_updated.connect(player_hud._on_player_kills_changed)
		Logger.system("✅ Connected PlayerHUD to VictoryConditionManager for kill tracking", "SuddenDeathMinigame")
	else:
		Logger.system("✅ PlayerHUD already connected to VictoryConditionManager", "SuddenDeathMinigame")

## Clean up Sudden Death specific connections
func _on_physics_end(result: MinigameResult) -> void:
	# Disconnect from death events
	if EventBus.player_died.is_connected(_on_sudden_death_player_died):
		EventBus.player_died.disconnect(_on_sudden_death_player_died)
	
	# Disconnect from kill tracking events (simplified)
	if EventBus.player_killed_by.is_connected(_on_player_killed_by):
		EventBus.player_killed_by.disconnect(_on_player_killed_by)
	
	# Clear respawn blocks
	if respawn_manager:
		respawn_manager.clear_all_respawn_blocks()
	
	# Clear kill tracking data (simplified)
	player_kills.clear()
	
	Logger.system("SuddenDeathMinigame cleanup completed with simplified kill tracking", "SuddenDeathMinigame") 

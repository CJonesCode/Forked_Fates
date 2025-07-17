class_name BaseMinigame
extends Node

## Minimal base interface for all minigames
## Provides the essential lifecycle and communication methods that every minigame must implement

# Minigame metadata - each minigame defines its own info
@export var minigame_name: String = "Unknown Minigame"
@export var minigame_description: String = ""
@export var minigame_type: String = "custom"  # "physics", "ui", "turn_based", "custom"
@export var max_players: int = 4
@export var min_players: int = 1
@export var estimated_duration: float = 300.0  # 5 minutes default
@export var tags: Array[String] = []  # ["combat", "elimination", "physics"]
@export var enabled: bool = true

# Tutorial content - each minigame defines its own tutorial
@export var tutorial_rules: Array[String] = []  # ["Rule 1", "Rule 2", "Rule 3"]
@export var tutorial_controls: Dictionary = {}  # {"Move": "WASD", "Jump": "Space", "Use": "E"}
@export var tutorial_objective: String = ""     # "Last player standing wins!"
@export var tutorial_tips: Array[String] = []   # ["Tip: Use items wisely!", "Tip: Watch for respawns!"]
@export var tutorial_duration: float = 5.0      # How long to show tutorial (0 = manual start)

# Core signals - all minigames must emit these
signal minigame_started()
signal minigame_ended(result)
signal minigame_paused()
signal minigame_resumed()
signal tutorial_shown()
signal tutorial_finished()

# Context and state
var context = null
var is_active: bool = false
var is_paused: bool = false
var is_showing_tutorial: bool = false
var tutorial_timer: float = 0.0
var start_time: float = 0.0

func _ready() -> void:
	Logger.system("BaseMinigame ready: " + minigame_name, "BaseMinigame")

## Process tutorial timer
func _process(delta: float) -> void:
	if is_showing_tutorial and tutorial_duration > 0 and tutorial_timer > 0:
		tutorial_timer -= delta
		
		# Auto-finish tutorial when timer expires
		if tutorial_timer <= 0:
			finish_tutorial()

## Initialize the minigame with context and player data
func initialize_minigame(minigame_context: MinigameContext) -> void:
	if context:
		Logger.warning("Minigame already initialized", "BaseMinigame")
		return
	
	# Store context
	context = minigame_context
	Logger.system("Initializing minigame: " + minigame_name + " with " + str(context.participating_players.size()) + " players", "BaseMinigame")
	
	# Connect to universal damage reporting system
	EventBus.player_damage_reported.connect(_on_player_damage_reported)
	
	# Call virtual implementation
	_on_initialize(minigame_context)

## Start the minigame (shows tutorial first if configured)
## Virtual method - can be overridden by subclasses
func start_minigame() -> void:
	if context == null:
		Logger.error("Cannot start minigame - not initialized with context", "BaseMinigame")
		return
	
	# Show tutorial first if we have tutorial content
	if _has_tutorial_content():
		show_tutorial()
	else:
		# Skip tutorial and start immediately
		_start_gameplay()

## Show the tutorial screen
func show_tutorial() -> void:
	is_showing_tutorial = true
	
	if tutorial_duration > 0:
		tutorial_timer = tutorial_duration
	
	Logger.game_flow("Showing tutorial for: " + minigame_name, "BaseMinigame")
	tutorial_shown.emit()
	
	# Virtual implementation hook
	_on_tutorial_shown()

## Finish tutorial and start actual gameplay
func finish_tutorial() -> void:
	if not is_showing_tutorial:
		return
	
	is_showing_tutorial = false
	tutorial_timer = 0.0
	
	Logger.game_flow("Tutorial finished for: " + minigame_name, "BaseMinigame")
	tutorial_finished.emit()
	
	# Virtual implementation hook
	_on_tutorial_finished()
	
	# Start actual gameplay
	_start_gameplay()

## Start the actual gameplay (after tutorial)
func _start_gameplay() -> void:
	is_active = true
	start_time = Time.get_unix_time_from_system()
	
	Logger.game_flow("Starting gameplay: " + minigame_name, "BaseMinigame")
	minigame_started.emit()
	
	# Virtual implementation hook
	_on_start()

## End the minigame with results
## Virtual method - can be overridden but should call super._ready()
func end_minigame(result) -> void:
	if not is_active:
		Logger.warning("Trying to end inactive minigame: " + minigame_name, "BaseMinigame")
		return
	
	is_active = false
	
	# Hide any active game HUD when minigame ends
	UIManager.hide_game_hud()
	
	# Disconnect universal systems
	if EventBus.player_damage_reported.is_connected(_on_player_damage_reported):
		EventBus.player_damage_reported.disconnect(_on_player_damage_reported)
	
	# Set duration if not already set
	if result.duration == 0.0:
		result.duration = Time.get_unix_time_from_system() - start_time
	
	# Set minigame type if not already set
	if result.minigame_type == "":
		result.minigame_type = minigame_name
	
	Logger.game_flow("Ending minigame: " + minigame_name + " after " + str(result.duration) + "s", "BaseMinigame")
	minigame_ended.emit(result)
	
	# Virtual implementation hook
	_on_end(result)

## Handle player damage reported from any source (weapons, hazards, etc.)
## This is available to ALL minigame types, not just physics-based ones
func _on_player_damage_reported(victim_id: int, attacker_id: int, damage: int, source_name: String) -> void:
	# Find the target player by ID in the context
	var target_player_data: PlayerData = null
	for player_data in context.participating_players:
		if player_data.player_id == victim_id:
			target_player_data = player_data
			break
	
	if not target_player_data:
		Logger.warning("Damage target not found in minigame context: Player " + str(victim_id), "BaseMinigame")
		return
	
	# Default implementation: delegate to subclass
	# Subclasses can override this or use the virtual method below
	_on_damage_reported(victim_id, attacker_id, damage, source_name, target_player_data)

## Virtual method for subclasses to handle damage in their specific way
## Examples:
##   - Physics: Apply directly to player health
##   - Collection: Reduce collected items, respawn player
##   - Vehicle: Reduce speed, damage vehicle
##   - Turn-based: Queue damage for next turn
func _on_damage_reported(victim_id: int, attacker_id: int, damage: int, source_name: String, victim_data: PlayerData) -> void:
	# Default: just log the damage event
	var victim_name: String = victim_data.player_name
	var attacker_name: String = "Player " + str(attacker_id)
	
	# Try to get attacker name from context
	for player_data in context.participating_players:
		if player_data.player_id == attacker_id:
			attacker_name = player_data.player_name
			break
	
	Logger.combat("Damage reported: " + str(damage) + " from " + attacker_name + " to " + victim_name + " via " + source_name, "BaseMinigame")
	
	# Subclasses should override this method to apply damage appropriately

## Pause the minigame
## Virtual method - can be overridden by subclasses
func pause_minigame() -> void:
	if not is_active or is_paused:
		return
	
	is_paused = true
	Logger.game_flow("Pausing minigame: " + minigame_name, "BaseMinigame")
	minigame_paused.emit()
	
	# Virtual implementation hook
	_on_pause()

## Resume the minigame from pause
## Virtual method - can be overridden by subclasses
func resume_minigame() -> void:
	if not is_active or not is_paused:
		return
	
	is_paused = false
	Logger.game_flow("Resuming minigame: " + minigame_name, "BaseMinigame")
	minigame_resumed.emit()
	
	# Virtual implementation hook
	_on_resume()

## Force cleanup and termination (for emergency exits)
func abort_minigame() -> void:
	Logger.warning("Aborting minigame: " + minigame_name, "BaseMinigame")
	
	if is_active:
		var abort_result = MinigameResult.new()
		abort_result.outcome = MinigameResult.MinigameOutcome.ABANDONED
		abort_result.participating_players = context.get_player_ids() if context else []
		abort_result.minigame_type = minigame_name
		abort_result.duration = Time.get_unix_time_from_system() - start_time if start_time > 0 else 0.0
		
		end_minigame(abort_result)
	
	# Virtual implementation hook
	_on_abort()

## Get current minigame status for debugging/monitoring
func get_status() -> Dictionary:
	return {
		"name": minigame_name,
		"active": is_active,
		"paused": is_paused,
		"showing_tutorial": is_showing_tutorial,
		"tutorial_time_remaining": tutorial_timer,
		"players": context.participating_players.size() if context else 0,
		"duration": Time.get_unix_time_from_system() - start_time if start_time > 0 else 0.0
	}

## Check if minigame has tutorial content defined
func _has_tutorial_content() -> bool:
	return not tutorial_rules.is_empty() or not tutorial_objective.is_empty() or not tutorial_controls.is_empty()

## Get tutorial data for UI display
func get_tutorial_data() -> Dictionary:
	return {
		"rules": tutorial_rules.duplicate(),
		"controls": tutorial_controls.duplicate(),
		"objective": tutorial_objective,
		"tips": tutorial_tips.duplicate(),
		"duration": tutorial_duration,
		"time_remaining": tutorial_timer
	}

## Create MinigameInfo from this minigame's metadata (for self-registration)
func create_registry_info(scene_path: String):
	var info = MinigameRegistry.MinigameInfo.new(
		minigame_name.to_lower().replace(" ", "_"),  # Convert to ID
		minigame_name,
		scene_path
	)
	
	info.description = minigame_description
	info.minigame_type = minigame_type
	info.min_players = min_players
	info.max_players = max_players
	info.estimated_duration = estimated_duration
	info.tags = tags.duplicate()
	info.enabled = enabled
	
	return info

# Virtual methods for subclasses to implement
# These provide clean hooks without requiring super._ready() calls

## Called during initialize_minigame() after basic setup
## Override this to set up your minigame-specific systems
func _on_initialize(minigame_context) -> void:
	# Default implementation does nothing
	pass

## Called during start_minigame() after basic setup
## Override this to begin your gameplay logic
func _on_start() -> void:
	# Default implementation does nothing
	pass

## Called during end_minigame() after basic cleanup
## Override this to handle cleanup of your systems
func _on_end(result) -> void:
	# Default implementation does nothing
	pass

## Called during pause_minigame()
## Override this to pause your gameplay systems
func _on_pause() -> void:
	# Default implementation does nothing
	pass

## Called during resume_minigame()
## Override this to resume your gameplay systems
func _on_resume() -> void:
	# Default implementation does nothing
	pass

## Called during abort_minigame()
## Override this to handle emergency cleanup
func _on_abort() -> void:
	# Default implementation does nothing
	pass

## Called when tutorial is shown
## Override this to customize tutorial display
func _on_tutorial_shown() -> void:
	# Default implementation does nothing
	pass

## Called when tutorial finishes
## Override this to handle tutorial cleanup
func _on_tutorial_finished() -> void:
	# Default implementation does nothing
	pass 
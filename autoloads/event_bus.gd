extends Node

## Global event bus for decoupled communication throughout the game
## Use this for cross-scene communication and events that need to reach distant nodes

# Player-related signals
signal player_health_changed(player_id: int, new_health: int)
signal player_lives_changed(player_id: int, new_lives: int)  # New signal for lives
signal player_died(player_id: int)
signal player_respawned(player_id: int)
signal player_ragdolled(player_id: int)
signal player_recovered(player_id: int)
signal player_respawn_timer_updated(player_id: int, time_remaining: float)
signal player_damage_reported(victim_id: int, attacker_id: int, damage: int, weapon_name: String)

# Item-related signals  
signal item_picked_up(player_id: int, item_name: String)
signal item_dropped(player_id: int, item_name: String)
signal item_used(player_id: int, item_name: String)

# Minigame signals
signal minigame_started(minigame_type: String)
signal minigame_ended(winner_id: int, results: Dictionary)
signal round_started()
signal round_ended()

# Map navigation signals
signal map_node_selected(node_id: int)
signal map_progression_updated(current_node: int)

# Game state signals
signal scene_transition_requested(scene_path: String)
signal game_paused()
signal game_resumed()

# Network signals (for future multiplayer implementation)
signal network_player_joined(player_id: int)
signal network_player_left(player_id: int)
signal network_state_synced(game_state: Dictionary)

func _ready() -> void:
	# Set process mode to always so EventBus works even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	Logger.system("EventBus initialized", "EventBus")

## Emit a player health change event
func emit_player_health_changed(player_id: int, new_health: int) -> void:
	player_health_changed.emit(player_id, new_health)

## Emit a player lives change event
func emit_player_lives_changed(player_id: int, new_lives: int) -> void:
	player_lives_changed.emit(player_id, new_lives)

## Emit a player death event
func emit_player_died(player_id: int) -> void:
	player_died.emit(player_id)

## Emit a player respawn event
func emit_player_respawned(player_id: int) -> void:
	player_respawned.emit(player_id)

## Emit a respawn timer update
func emit_player_respawn_timer_updated(player_id: int, time_remaining: float) -> void:
	player_respawn_timer_updated.emit(player_id, time_remaining)

## Report damage dealt to a player (for minigame to handle)
func report_player_damage(victim_id: int, attacker_id: int, damage: int, weapon_name: String) -> void:
	player_damage_reported.emit(victim_id, attacker_id, damage, weapon_name)

## Emit an item pickup event
func emit_item_picked_up(player_id: int, item_name: String) -> void:
	item_picked_up.emit(player_id, item_name)

## Emit an item drop event  
func emit_item_dropped(player_id: int, item_name: String) -> void:
	item_dropped.emit(player_id, item_name)

## Emit an item use event
func emit_item_used(player_id: int, item_name: String) -> void:
	item_used.emit(player_id, item_name)

## Request a scene transition
func request_scene_transition(scene_path: String) -> void:
	scene_transition_requested.emit(scene_path) 

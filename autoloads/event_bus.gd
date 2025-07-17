extends Node

## Enhanced Global Event Bus for Decoupled Communication
## Features typed signals and automatic connection management for better reliability

# Signal connection management
var signal_connections: Array[SignalConnectionInfo] = []

# Signal connection info helper class
class SignalConnectionInfo:
	var source: Object
	var signal_name: String  
	var target: Object
	var method: Callable
	var connection_id: int
	
	func _init(src: Object, sig: String, tgt: Object, mth: Callable, id: int):
		source = src
		signal_name = sig
		target = tgt
		method = mth
		connection_id = id

# Connection ID counter
var next_connection_id: int = 1

# Player-related signals
signal player_health_changed(player_id: int, new_health: int, max_health: int)
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
	Logger.system("Enhanced EventBus initialized with connection management", "EventBus")

## Connect signal with automatic cleanup tracking
func connect_safe(source: Object, signal_name: String, target: Object, method: Callable, flags: int = 0) -> int:
	if not source or not target:
		Logger.error("Cannot connect signal - invalid source or target", "EventBus")
		return -1
	
	if not source.has_signal(signal_name):
		Logger.error("Signal '" + signal_name + "' does not exist on source object", "EventBus")
		return -1
	
	# Connect the signal
	var result: int = source.connect(signal_name, method, flags)
	if result != OK:
		Logger.error("Failed to connect signal: " + signal_name, "EventBus")
		return -1
	
	# Track the connection for cleanup
	var connection_id: int = next_connection_id
	next_connection_id += 1
	
	var connection_info: SignalConnectionInfo = SignalConnectionInfo.new(source, signal_name, target, method, connection_id)
	signal_connections.append(connection_info)
	
	Logger.debug("Connected signal: " + signal_name + " (ID: " + str(connection_id) + ")", "EventBus")
	return connection_id

## Disconnect signal by connection ID
func disconnect_safe(connection_id: int) -> bool:
	for i in range(signal_connections.size()):
		var conn: SignalConnectionInfo = signal_connections[i]
		if conn.connection_id == connection_id:
			if conn.source and conn.source.is_connected(conn.signal_name, conn.method):
				conn.source.disconnect(conn.signal_name, conn.method)
			signal_connections.remove_at(i)
			Logger.debug("Disconnected signal by ID: " + str(connection_id), "EventBus")
			return true
	
	Logger.warning("Connection ID not found for disconnect: " + str(connection_id), "EventBus")
	return false

## Disconnect all signals from a specific target (for cleanup)
func disconnect_all_from_target(target: Object) -> int:
	if not target:
		return 0
	
	var disconnected_count: int = 0
	for i in range(signal_connections.size() - 1, -1, -1):
		var conn: SignalConnectionInfo = signal_connections[i]
		if conn.target == target:
			if conn.source and conn.source.is_connected(conn.signal_name, conn.method):
				conn.source.disconnect(conn.signal_name, conn.method)
			signal_connections.remove_at(i)
			disconnected_count += 1
	
	if disconnected_count > 0:
		Logger.debug("Disconnected " + str(disconnected_count) + " signals from target: " + str(target), "EventBus")
	
	return disconnected_count

## Cleanup invalid signal connections
func cleanup_connections() -> int:
	var cleaned_count: int = 0
	for i in range(signal_connections.size() - 1, -1, -1):
		var conn: SignalConnectionInfo = signal_connections[i]
		if not conn.source or not conn.target or not conn.source.is_connected(conn.signal_name, conn.method):
			signal_connections.remove_at(i)
			cleaned_count += 1
	
	if cleaned_count > 0:
		Logger.debug("Cleaned up " + str(cleaned_count) + " invalid signal connections", "EventBus")
	
	return cleaned_count

## Get connection statistics for debugging
func get_connection_stats() -> Dictionary:
	var stats: Dictionary = {
		"total_connections": signal_connections.size(),
		"valid_connections": 0,
		"invalid_connections": 0,
		"connections_by_signal": {}
	}
	
	for conn in signal_connections:
		if conn.source and conn.target and conn.source.is_connected(conn.signal_name, conn.method):
			stats.valid_connections += 1
		else:
			stats.invalid_connections += 1
		
		if not stats.connections_by_signal.has(conn.signal_name):
			stats.connections_by_signal[conn.signal_name] = 0
		stats.connections_by_signal[conn.signal_name] += 1
	
	return stats

## Force cleanup all connections on shutdown
func force_cleanup_all_connections() -> void:
	Logger.system("EventBus forcing cleanup of all " + str(signal_connections.size()) + " connections", "EventBus")
	
	# Disconnect all signals
	for conn in signal_connections:
		if conn.source and conn.target and is_instance_valid(conn.source) and is_instance_valid(conn.target):
			if conn.source.is_connected(conn.signal_name, conn.method):
				conn.source.disconnect(conn.signal_name, conn.method)
	
	# Clear all connections
	signal_connections.clear()
	next_connection_id = 1
	
	Logger.system("EventBus cleanup completed", "EventBus")

## Cleanup on exit
func _exit_tree() -> void:
	force_cleanup_all_connections()

## Emit a player health change event
func emit_player_health_changed(player_id: int, new_health: int, max_health: int) -> void:
	player_health_changed.emit(player_id, new_health, max_health)

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

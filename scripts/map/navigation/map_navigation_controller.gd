class_name MapNavigationController
extends RefCounted

## Controller to integrate MapNavigation with UI and game systems
## Bridges the navigation logic with existing map view and voting systems

var navigation: MapNavigation
var map_view: Control
var party_progress: PartyProgressData

# Current voting state
var active_voting_decision: int = -1
var voting_timer: Timer

signal navigation_updated(state: Dictionary)
signal voting_started(available_moves: Array[String])
signal voting_completed(chosen_node: String)

func _init(map_view_node: Control) -> void:
	map_view = map_view_node
	party_progress = GameManager.get_party_progress()
	
	if not party_progress:
		Logger.error("MapNavigationController requires PartyProgressData", "MapNavigationController")
		return
	
	# Initialize navigation system
	navigation = MapNavigation.new(party_progress)
	
	# Connect navigation signals
	navigation.move_requested.connect(_on_move_requested)
	navigation.node_completed.connect(_on_node_completed)
	navigation.nodes_unlocked.connect(_on_nodes_unlocked)
	
	# Connect to EventBus for global navigation events
	EventBus.map_move_requested.connect(_on_global_move_requested)
	EventBus.map_node_completed.connect(_on_global_node_completed)
	EventBus.map_nodes_unlocked.connect(_on_global_nodes_unlocked)
	
	Logger.system("MapNavigationController initialized", "MapNavigationController")

## Initialize with map data from map view
func initialize_with_map(map_data: Dictionary) -> void:
	if not navigation:
		Logger.error("Navigation system not initialized", "MapNavigationController")
		return
	
	navigation.initialize_map(map_data, "start")
	_emit_navigation_update()
	Logger.game_flow("Navigation initialized with map data", "MapNavigationController")

## Request movement to a specific node (triggers validation)
func request_move_to_node(target_node: String) -> bool:
	if not navigation:
		Logger.error("Navigation system not initialized", "MapNavigationController")
		return false
	
	Logger.game_flow("Move requested to node: " + target_node, "MapNavigationController")
	return navigation.move_to_node(target_node)

## Get available movement options for current position
func get_available_moves() -> Array[String]:
	if not navigation:
		return []
	
	return navigation.get_available_moves()

## Start democratic voting for next node
func start_movement_voting(deadline_seconds: int = 30) -> bool:
	if not navigation:
		Logger.error("Cannot start voting without navigation system", "MapNavigationController")
		return false
	
	var available_moves: Array[String] = navigation.get_available_moves()
	if available_moves.is_empty():
		Logger.warning("No available moves to vote on", "MapNavigationController")
		return false
	
	# Start the voting process
	active_voting_decision = navigation.start_node_voting(deadline_seconds)
	if active_voting_decision < 0:
		Logger.error("Failed to start voting decision", "MapNavigationController")
		return false
	
	# Start monitoring timer
	_start_voting_monitor()
	
	Logger.game_flow("Movement voting started with " + str(available_moves.size()) + " options", "MapNavigationController")
	voting_started.emit(available_moves)
	return true

## Submit a vote for movement
func vote_for_move(player_id: int, node_id: String) -> bool:
	if not navigation or active_voting_decision < 0:
		Logger.error("No active voting session", "MapNavigationController")
		return false
	
	var result: bool = navigation.vote_for_move(active_voting_decision, player_id, node_id)
	if result:
		Logger.game_flow("Vote submitted by player " + str(player_id) + " for node: " + node_id, "MapNavigationController")
		_check_voting_completion()
	
	return result

## Mark current node as completed (called when minigame ends)
func complete_current_node() -> void:
	if not navigation:
		Logger.error("Navigation system not initialized", "MapNavigationController")
		return
	
	var current_node: String = navigation.current_node_id
	navigation.mark_node_completed(current_node)
	_emit_navigation_update()
	Logger.game_flow("Node completed: " + current_node, "MapNavigationController")

## Check if map progression is complete
func is_progression_complete() -> bool:
	if not navigation:
		return false
	
	return navigation.is_map_complete()

## Get current navigation state for UI updates
func get_navigation_state() -> Dictionary:
	if not navigation:
		return {}
	
	return navigation.get_navigation_state()

## Check voting completion and resolve if ready
func _check_voting_completion() -> void:
	if not party_progress or active_voting_decision < 0:
		return
	
	if party_progress.is_voting_complete(active_voting_decision):
		_resolve_voting()

## Resolve completed voting and execute move
func _resolve_voting() -> void:
	if not navigation or active_voting_decision < 0:
		return
	
	var success: bool = navigation.resolve_node_voting(active_voting_decision)
	if success:
		var chosen_node: String = navigation.current_node_id
		Logger.game_flow("Voting resolved and moved to: " + chosen_node, "MapNavigationController")
		voting_completed.emit(chosen_node)
	else:
		Logger.error("Failed to resolve voting and move", "MapNavigationController")
	
	# Clean up voting state
	_end_voting_session()
	_emit_navigation_update()

## Start monitoring voting progress
func _start_voting_monitor() -> void:
	if voting_timer:
		voting_timer.queue_free()
	
	voting_timer = Timer.new()
	voting_timer.wait_time = 1.0  # Check every second
	voting_timer.timeout.connect(_check_voting_completion)
	voting_timer.autostart = true
	
	# Add to map view to handle lifecycle
	if map_view:
		map_view.add_child(voting_timer)

## End voting session and cleanup
func _end_voting_session() -> void:
	active_voting_decision = -1
	
	if voting_timer:
		voting_timer.queue_free()
		voting_timer = null

## Emit navigation state update
func _emit_navigation_update() -> void:
	var state: Dictionary = get_navigation_state()
	navigation_updated.emit(state)

## Signal handlers for local navigation events
func _on_move_requested(node_id: String) -> void:
	Logger.debug("Navigation move requested: " + node_id, "MapNavigationController")
	# Trigger any UI updates needed for movement

func _on_node_completed(node_id: String) -> void:
	Logger.debug("Navigation node completed: " + node_id, "MapNavigationController")
	# Handle node completion effects (unlock animations, etc.)

func _on_nodes_unlocked(unlocked_nodes: Array[String]) -> void:
	Logger.debug("Navigation nodes unlocked: " + str(unlocked_nodes), "MapNavigationController")
	# Trigger unlock animations or UI updates

## Global EventBus handlers (for multiplayer synchronization)
func _on_global_move_requested(node_id: String) -> void:
	Logger.debug("Global move requested received: " + node_id, "MapNavigationController")
	# Handle remote player move requests in multiplayer

func _on_global_node_completed(node_id: String) -> void:
	Logger.debug("Global node completion received: " + node_id, "MapNavigationController")
	# Sync remote node completions in multiplayer

func _on_global_nodes_unlocked(unlocked_nodes: Array[String]) -> void:
	Logger.debug("Global nodes unlocked received: " + str(unlocked_nodes), "MapNavigationController")
	# Sync remote node unlocks in multiplayer

## Auto-start movement voting when multiple options available
func auto_start_voting_if_needed() -> bool:
	var available_moves: Array[String] = get_available_moves()
	
	# Only auto-start voting if multiple options exist
	if available_moves.size() > 1:
		return start_movement_voting()
	elif available_moves.size() == 1:
		# Auto-move to single available option
		Logger.game_flow("Auto-moving to single available node: " + available_moves[0], "MapNavigationController")
		return request_move_to_node(available_moves[0])
	
	# No available moves - map might be complete
	return false

## Cleanup method
func cleanup() -> void:
	_end_voting_session()
	
	if navigation:
		# Disconnect signals if needed
		if navigation.move_requested.is_connected(_on_move_requested):
			navigation.move_requested.disconnect(_on_move_requested)
		if navigation.node_completed.is_connected(_on_node_completed):
			navigation.node_completed.disconnect(_on_node_completed)
		if navigation.nodes_unlocked.is_connected(_on_nodes_unlocked):
			navigation.nodes_unlocked.disconnect(_on_nodes_unlocked)
	
	# Disconnect EventBus signals
	if EventBus.map_move_requested.is_connected(_on_global_move_requested):
		EventBus.map_move_requested.disconnect(_on_global_move_requested)
	if EventBus.map_node_completed.is_connected(_on_global_node_completed):
		EventBus.map_node_completed.disconnect(_on_global_node_completed)
	if EventBus.map_nodes_unlocked.is_connected(_on_global_nodes_unlocked):
		EventBus.map_nodes_unlocked.disconnect(_on_global_nodes_unlocked)
	
	Logger.system("MapNavigationController cleanup completed", "MapNavigationController")

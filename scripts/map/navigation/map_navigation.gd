class_name MapNavigation
extends RefCounted

## Map Navigation Controller for Slay the Spire Style Progression
## Handles movement rules, validation, and state management for map progression

# Core state tracking
var current_node_id: String = ""
var visited_nodes: Array[String] = []
var available_nodes: Array[String] = []
var map_data: Dictionary = {}

# Party progress integration
var party_progress: PartyProgressData

# EventBus signals
signal move_requested(node_id: String)
signal node_completed(node_id: String) 
signal nodes_unlocked(unlocked_nodes: Array[String])

func _init(progress_data: PartyProgressData = null) -> void:
	party_progress = progress_data
	if party_progress:
		_sync_from_party_progress()
	else:
		Logger.warning("MapNavigation initialized without PartyProgressData", "MapNavigation")
	
	# Connect internal signals to EventBus for global communication
	move_requested.connect(EventBus.emit_map_move_requested)
	node_completed.connect(EventBus.emit_map_node_completed)
	nodes_unlocked.connect(EventBus.emit_map_nodes_unlocked)

## Initialize with map data and starting state
func initialize_map(map_data_dict: Dictionary, start_node: String = "start") -> void:
	map_data = map_data_dict
	current_node_id = start_node
	visited_nodes.clear()
	available_nodes = [start_node]
	
	# Do NOT unlock connected nodes initially - they must complete the start node minigame first
	# unlock_connected_nodes(start_node)  # Removed - nodes unlock only after minigame completion
	
	# Sync with party progress if available
	if party_progress:
		party_progress.current_map_node = 0  # Reset to start
		party_progress.nodes_completed.clear()
		party_progress.nodes_available = [1]  # Start node in PartyProgressData uses int IDs
		party_progress.path_taken.clear()
		
		# Add available nodes to party progress
		for node_id in available_nodes:
			var node_int_id: int = _convert_string_to_int_id(node_id)
			if node_int_id not in party_progress.nodes_available:
				party_progress.nodes_available.append(node_int_id)
	
	Logger.game_flow("Map navigation initialized at node: " + start_node, "MapNavigation")

## Check if a move from one node to another is valid
func is_move_valid(from_id: String, to_id: String) -> bool:
	# Rule 1: Cannot move from invalid source
	if from_id != current_node_id:
		Logger.warning("Invalid move: not currently at source node " + from_id, "MapNavigation")
		return false
	
	# Rule 2: Cannot move to already visited nodes (no backtracking)
	if to_id in visited_nodes:
		Logger.warning("Invalid move: cannot return to visited node " + to_id, "MapNavigation")
		return false
	
	# Rule 3: Can only move to directly connected nodes
	if not _are_nodes_connected(from_id, to_id):
		Logger.warning("Invalid move: nodes " + from_id + " and " + to_id + " are not connected", "MapNavigation")
		return false
	
	# Rule 4: Target node must be available
	if not can_access_node(to_id):
		Logger.warning("Invalid move: node " + to_id + " is not currently available", "MapNavigation")
		return false
	
	return true

## Check if a specific node can be accessed (is unlocked and available)
func can_access_node(node_id: String) -> bool:
	# Must exist in map data
	if not map_data.has("nodes") or not map_data.nodes.has(node_id):
		return false
	
	# Must be in available nodes list
	if node_id not in available_nodes:
		return false
	
	# Must be reachable through forward connections only
	return is_node_forward_reachable(node_id)

## Get the list of visited nodes
func get_visited_nodes() -> Array[String]:
	return visited_nodes.duplicate()

## Mark a node as completed and handle progression
func mark_node_completed(node_id: String) -> void:
	if node_id != current_node_id:
		Logger.error("Cannot complete node " + node_id + " - not currently at this node", "MapNavigation")
		return
	
	# Add to visited nodes (don't add start node to visited as per PartyProgressData pattern)
	if node_id != "start":
		visited_nodes.append(node_id)
	
	# Sync with party progress
	if party_progress:
		var node_int_id: int = _convert_string_to_int_id(node_id)
		if node_int_id > 0:  # Don't mark start as completed
			party_progress.nodes_completed.append(node_int_id)
		party_progress.path_taken.append(node_int_id)
	
	Logger.game_flow("Node completed: " + node_id, "MapNavigation")
	node_completed.emit(node_id)
	
	# Unlock connected nodes
	unlock_connected_nodes(node_id)

## Move to a new node (handles validation and state updates)
func move_to_node(target_id: String) -> bool:
	if not is_move_valid(current_node_id, target_id):
		return false
	
	# Mark current node as completed before moving
	mark_node_completed(current_node_id)
	
	# Update current position
	var previous_node: String = current_node_id
	current_node_id = target_id
	
	# Remove target from available nodes (it's now current)
	available_nodes.erase(target_id)
	
	# Sync with party progress
	if party_progress:
		var target_int_id: int = _convert_string_to_int_id(target_id)
		party_progress.current_map_node = target_int_id
		party_progress.nodes_available.erase(target_int_id)
	
	Logger.game_flow("Moved from " + previous_node + " to " + target_id, "MapNavigation")
	move_requested.emit(target_id)
	
	return true

## Unlock all nodes connected to the completed node
func unlock_connected_nodes(completed_node_id: String) -> void:
	if not map_data.has("connections") or not map_data.connections.has(completed_node_id):
		Logger.debug("No connections found for node: " + completed_node_id, "MapNavigation")
		return
	
	var connections: Array = map_data.connections[completed_node_id]
	var newly_unlocked: Array[String] = []
	
	for connected_node_id in connections:
		# Ensure connected node exists in map
		if not map_data.nodes.has(connected_node_id):
			Logger.warning("Connected node " + connected_node_id + " not found in map data", "MapNavigation")
			continue
		
		# Only unlock if not already visited or available
		if connected_node_id not in visited_nodes and connected_node_id not in available_nodes:
			available_nodes.append(connected_node_id)
			newly_unlocked.append(connected_node_id)
			
			# Sync with party progress
			if party_progress:
				var node_int_id: int = _convert_string_to_int_id(connected_node_id)
				if node_int_id not in party_progress.nodes_available:
					party_progress.nodes_available.append(node_int_id)
					party_progress.total_nodes_unlocked = max(party_progress.total_nodes_unlocked, node_int_id)
	
	if not newly_unlocked.is_empty():
		Logger.game_flow("Unlocked " + str(newly_unlocked.size()) + " new nodes: " + str(newly_unlocked), "MapNavigation")
		nodes_unlocked.emit(newly_unlocked)

## Get all currently available move options
func get_available_moves() -> Array[String]:
	var valid_moves: Array[String] = []
	
	for node_id in available_nodes:
		if is_move_valid(current_node_id, node_id) and is_node_forward_reachable(node_id):
			valid_moves.append(node_id)
	
	return valid_moves

## Initialize voting for available nodes
func start_node_voting(deadline_seconds: int = 30) -> int:
	if not party_progress:
		Logger.error("Cannot start voting without PartyProgressData", "MapNavigation")
		return -1
	
	var available_moves: Array[String] = get_available_moves()
	if available_moves.is_empty():
		Logger.warning("No available moves for voting", "MapNavigation")
		return -1
	
	# Convert to int IDs for PartyProgressData
	var available_int_ids: Array[int] = []
	for node_id in available_moves:
		available_int_ids.append(_convert_string_to_int_id(node_id))
	
	var decision_index: int = party_progress.add_node_voting(available_int_ids, deadline_seconds)
	Logger.game_flow("Started node voting with " + str(available_moves.size()) + " options", "MapNavigation")
	
	return decision_index

## Vote for a node movement
func vote_for_move(decision_index: int, player_id: int, node_id: String) -> bool:
	if not party_progress:
		Logger.error("Cannot vote without PartyProgressData", "MapNavigation")
		return false
	
	var available_moves: Array[String] = get_available_moves()
	var node_index: int = available_moves.find(node_id)
	
	if node_index == -1:
		Logger.warning("Invalid vote for node: " + node_id, "MapNavigation")
		return false
	
	var result: bool = party_progress.vote_for_node(decision_index, player_id, node_index)
	if result:
		Logger.game_flow("Player " + str(player_id) + " voted for node: " + node_id, "MapNavigation")
	
	return result

## Resolve voting and execute the chosen move
func resolve_node_voting(decision_index: int) -> bool:
	if not party_progress:
		Logger.error("Cannot resolve voting without PartyProgressData", "MapNavigation")
		return false
	
	if not party_progress.is_voting_complete(decision_index):
		Logger.warning("Voting is not complete yet", "MapNavigation")
		return false
	
	var chosen_option: int = party_progress.resolve_voting(decision_index)
	var available_moves: Array[String] = get_available_moves()
	
	if chosen_option < 0 or chosen_option >= available_moves.size():
		Logger.error("Invalid voting result: " + str(chosen_option), "MapNavigation")
		return false
	
	var chosen_node: String = available_moves[chosen_option]
	Logger.game_flow("Voting resolved: chosen node " + chosen_node, "MapNavigation")
	
	# Clean up the voting decision
	party_progress.remove_decision(decision_index)
	
	# Execute the move
	return move_to_node(chosen_node)

## Get current navigation state for UI/debugging
func get_navigation_state() -> Dictionary:
	return {
		"current_node": current_node_id,
		"visited_nodes": visited_nodes.duplicate(),
		"available_nodes": available_nodes.duplicate(),
		"available_moves": get_available_moves(),
		"total_nodes_visited": visited_nodes.size(),
		"can_progress": not get_available_moves().is_empty()
	}

## Check if the map is complete (reached final node)
func is_map_complete() -> bool:
	# Check if current node is marked as final in map data
	if map_data.has("final_node"):
		return current_node_id == map_data.final_node
	
	# Fallback: check if no moves available and not at start
	return get_available_moves().is_empty() and current_node_id != "start"

## Sync state from PartyProgressData (for initialization/restore)
func _sync_from_party_progress() -> void:
	if not party_progress:
		return
	
	# Convert int-based party progress to string-based navigation state
	current_node_id = _convert_int_to_string_id(party_progress.current_map_node)
	
	visited_nodes.clear()
	for node_int in party_progress.nodes_completed:
		visited_nodes.append(_convert_int_to_string_id(node_int))
	
	available_nodes.clear()
	for node_int in party_progress.nodes_available:
		available_nodes.append(_convert_int_to_string_id(node_int))
	
	Logger.debug("Synced navigation state from PartyProgressData", "MapNavigation")

## Check if two nodes are connected in the map
func _are_nodes_connected(from_id: String, to_id: String) -> bool:
	if not map_data.has("connections") or not map_data.connections.has(from_id):
		return false
	
	var connections: Array = map_data.connections[from_id]
	return to_id in connections

## Convert string node ID to int for PartyProgressData compatibility
func _convert_string_to_int_id(node_id: String) -> int:
	# Simple hash-based conversion for demo - in production would use proper mapping
	if node_id == "start":
		return 0
	elif node_id == "boss_finale":
		return 999
	else:
		# Extract layer and node numbers for predictable mapping
		var parts: PackedStringArray = node_id.split("_")
		if parts.size() >= 4 and parts[0] == "layer" and parts[2] == "node":
			var layer: int = parts[1].to_int()
			var index: int = parts[3].to_int()
			return (layer * 10) + index + 1  # +1 to avoid 0 (reserved for start)
	
	# Fallback: use hash
	return abs(node_id.hash()) % 900 + 1  # Keep under 999 (reserved for boss)

## Convert int ID back to string node ID  
func _convert_int_to_string_id(node_int: int) -> String:
	if node_int == 0:
		return "start"
	elif node_int == 999:
		return "boss_finale"
	else:
		# Reverse the layer/index calculation
		var layer: int = (node_int - 1) / 10
		var index: int = (node_int - 1) % 10
		return "layer_" + str(layer) + "_node_" + str(index)

## Validate map data structure
func _validate_map_data() -> bool:
	if not map_data.has("nodes") or not map_data.has("connections"):
		Logger.error("Invalid map data: missing nodes or connections", "MapNavigation")
		return false
	
	# Validate all connections reference existing nodes
	for from_node in map_data.connections:
		if not map_data.nodes.has(from_node):
			Logger.error("Invalid map data: connection from non-existent node " + from_node, "MapNavigation")
			return false
		
		for to_node in map_data.connections[from_node]:
			if not map_data.nodes.has(to_node):
				Logger.error("Invalid map data: connection to non-existent node " + to_node, "MapNavigation")
				return false
	
	return true

## Check if node is reachable through forward connections only (no backtracking)
func is_node_forward_reachable(target_node_id: String) -> bool:
	# If target is the current node, it's always reachable
	if target_node_id == current_node_id:
		return true
	
	# Use breadth-first search to find path from current node to target
	# Only following forward connections (never visiting already visited nodes)
	var queue: Array[String] = [current_node_id]
	var explored: Array[String] = [current_node_id]
	
	while queue.size() > 0:
		var current: String = queue.pop_front()
		
		# Check all connections from current node
		if map_data.has("connections") and map_data.connections.has(current):
			var connections: Array = map_data.connections[current]
			for connected_node_id in connections:
				# Skip if already explored or visited (no backtracking)
				if connected_node_id in explored or connected_node_id in visited_nodes:
					continue
				
				# Found target through forward path
				if connected_node_id == target_node_id:
					return true
				
				# Add to queue for further exploration
				if connected_node_id not in queue:
					queue.append(connected_node_id)
					explored.append(connected_node_id)
	
	# No forward path found
	return false

## Reset navigation state for new session
func reset_navigation() -> void:
	var start_node: String = map_data.get("start_node", "start")
	current_node_id = start_node
	visited_nodes.clear()
	available_nodes = [start_node]
	
	if party_progress:
		party_progress.reset_for_new_session()
	
	Logger.game_flow("Navigation state reset to start node: " + start_node, "MapNavigation")

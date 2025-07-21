extends Control

## Map View Coordinator - Clean coordinator using new map architecture
## Bridges MapGenerator, MapRenderer, and MapNavigation with existing UI structure

# Preload map system classes
const MapData = preload("res://scripts/map/core/map_data.gd")
const MapNode = preload("res://scripts/map/core/map_node.gd")
const MapGenerator = preload("res://scripts/map/core/map_generator.gd")
const MapRenderer = preload("res://scripts/ui/map/map_renderer.gd")
const MapNavigation = preload("res://scripts/map/navigation/map_navigation.gd")

@onready var map_container: Control = $MapContainer
@onready var start_game_button: Button = $UIContainer/StartGameButton
@onready var back_button: Button = $UIContainer/BackButton
@onready var test_minigame_button: Button = $UIContainer/TestMinigameButton

# Core map system components
var map_generator
var map_renderer
var map_navigation

# Current map state
var current_map_data
var voting_ui_panel: Control = null
var current_voting_decision: int = -1

func _ready() -> void:
	# Connect UI signals
	start_game_button.pressed.connect(_on_start_game_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	test_minigame_button.pressed.connect(_on_test_minigame_button_pressed)
	
	# Initialize map system components
	_initialize_map_system()
	
	Logger.system("Map view coordinator loaded with new architecture", "MapView")

## Initialize the map system components and generate map
func _initialize_map_system() -> void:
	# Initialize map generator
	map_generator = MapGenerator.new()
	
	# Initialize map renderer
	map_renderer = MapRenderer.new()
	map_renderer.node_selected.connect(_on_node_selected)
	
	# Initialize navigation system
	var party_progress = GameManager.get_party_progress()
	map_navigation = MapNavigation.new(party_progress)
	
	# Load existing map or generate new one
	_initialize_or_load_map()

## Load existing map or generate new one
func _initialize_or_load_map() -> void:
	# Check if we have persistent map data
	if GameManager.has_persistent_map():
		Logger.system("Loading persistent map data", "MapView")
		_load_persistent_map()
	else:
		Logger.system("No persistent map found, generating new map", "MapView")
		_generate_and_setup_map()

## Load persistent map data from GameManager
func _load_persistent_map() -> void:
	# Get stored data from GameManager
	current_map_data = GameManager.get_stored_map_data()
	var navigation_data: Dictionary = GameManager.get_stored_navigation_data()
	
	if not current_map_data or navigation_data.is_empty():
		Logger.error("Invalid persistent map data, generating new map", "MapView")
		_generate_and_setup_map()
		return
	
	# Initialize navigation system with stored data
	map_navigation.initialize_map(navigation_data)
	
	# Connect to minigame completion events
	if not EventBus.minigame_ended.is_connected(_on_minigame_completed):
		EventBus.minigame_ended.connect(_on_minigame_completed)
	
	# Render the map
	map_renderer.render(current_map_data, map_container)
	
	# Update renderer state with current available moves and visited nodes
	var available_moves: Array[String] = map_navigation.get_available_moves()
	var visited_nodes: Array[String] = map_navigation.get_visited_nodes()
	map_renderer.update_state(current_map_data, available_moves, visited_nodes)
	
	Logger.game_flow("Persistent map loaded and rendered successfully", "MapView")

## Generate map and initialize navigation
func _generate_and_setup_map() -> void:
	# Generate map using MapGenerator with default configuration
	# The generator will automatically load the default MapGenerationConfig
	current_map_data = map_generator.generate()
	if not current_map_data:
		Logger.error("Failed to generate map data", "MapView")
		return
	
	# Convert to format expected by MapNavigation
	var navigation_map_data: Dictionary = _convert_map_data_for_navigation(current_map_data)
	
	# Initialize navigation system with correct start node
	var start_node_id: String = navigation_map_data.get("start_node", "")
	map_navigation.initialize_map(navigation_map_data, start_node_id)
	
	# Connect to minigame completion events
	if not EventBus.minigame_ended.is_connected(_on_minigame_completed):
		EventBus.minigame_ended.connect(_on_minigame_completed)
	
	# Render the map
	map_renderer.render(current_map_data, map_container)
	
	# Update renderer state with initial available moves and visited nodes
	var available_moves: Array[String] = map_navigation.get_available_moves()
	var visited_nodes: Array[String] = map_navigation.get_visited_nodes()
	map_renderer.update_state(current_map_data, available_moves, visited_nodes)
	
	# Store map data for persistence
	_store_map_data()
	
	Logger.game_flow("Map generated and rendered successfully", "MapView")

## Store current map data for persistence
func _store_map_data() -> void:
	if current_map_data and map_navigation:
		var navigation_map_data: Dictionary = _convert_map_data_for_navigation(current_map_data)
		GameManager.store_map_data(current_map_data, navigation_map_data)

## Convert MapData to format expected by MapNavigation
func _convert_map_data_for_navigation(map_data) -> Dictionary:
	var nav_data: Dictionary = {
		"nodes": {},
		"connections": {},
		"start_node": "",
		"final_node": ""
	}
	
	# Convert nodes
	for node in map_data.nodes.values():
		nav_data.nodes[node.id] = {
			"id": node.id,
			"layer": node.layer,
			"index": node.index,
			"node_type": node.node_type,
			"available": (node.node_type == "start")
		}
		
		# Set start and final nodes
		if node.node_type == "start":
			nav_data.start_node = node.id
		elif node.node_type == "boss":
			nav_data.final_node = node.id
		
		# Convert connections
		nav_data.connections[node.id] = node.outgoing_connections.duplicate()
	
	return nav_data

## Handle node selection from renderer
func _on_node_selected(node_id: String) -> void:
	Logger.game_flow("Node selected: " + node_id, "MapView")
	
	# If clicking current node, start its minigame
	if node_id == map_navigation.current_node_id:
		_start_current_node_minigame()
		return
	
	# Get available moves from navigation
	var available_moves: Array[String] = map_navigation.get_available_moves()
	
	# Check if the selected node is a valid move
	if node_id not in available_moves:
		Logger.warning("Selected node is not available for movement: " + node_id, "MapView")
		return
	
	# If multiple moves available, start voting; otherwise move directly
	if available_moves.size() > 1:
		_start_movement_voting(available_moves)
	else:
		_execute_move_to_node(node_id)

## Execute movement to a specific node
func _execute_move_to_node(node_id: String) -> bool:
	var success: bool = map_navigation.move_to_node(node_id)
	if success:
		Logger.game_flow("Successfully moved to node: " + node_id, "MapView")
		
		# Update renderer state after navigation change
		var available_moves: Array[String] = map_navigation.get_available_moves()
		var visited_nodes: Array[String] = map_navigation.get_visited_nodes()
		map_renderer.update_state(current_map_data, available_moves, visited_nodes)
		
		# Start minigame for the new node
		var node = current_map_data.get_node(node_id)
		if node and node.node_type != "start":
			_start_node_minigame(node)
		
		return true
	else:
		Logger.warning("Failed to move to node: " + node_id, "MapView")
		return false

## Start minigame for a specific node
func _start_node_minigame(node) -> void:
	Logger.game_flow("Starting minigame for node: " + node.id + " (type: " + node.node_type + ")", "MapView")
	
	# Map node types directly to minigame types
	var minigame_type: String = node.node_type
	
	match node.node_type:
		"start":
			minigame_type = "sudden_death"  # Start always uses sudden_death
		"boss":
			minigame_type = "sudden_death"  # Boss uses sudden_death (could be enhanced later)
		"normal":
			minigame_type = "sudden_death"  # Fallback for any remaining normal nodes
		"sudden_death", "shop", "race", "gem_collection", "tag":
			minigame_type = node.node_type  # Use the node type directly as minigame type
		_:
			minigame_type = "sudden_death"  # Fallback for unknown types
	
	# Start the minigame through GameManager
	GameManager.start_minigame(minigame_type)

## Start movement voting
func _start_movement_voting(available_moves: Array[String]) -> void:
	Logger.game_flow("Starting movement voting with " + str(available_moves.size()) + " options", "MapView")
	
	# Start voting through navigation system
	current_voting_decision = map_navigation.start_node_voting(30)
	if current_voting_decision >= 0:
		_create_voting_ui(available_moves)
		_start_voting_monitor()

## Create voting UI using UIFactory patterns
func _create_voting_ui(available_moves: Array[String]) -> void:
	# Clean up existing voting UI
	_cleanup_voting_ui()
	
	# Create voting panel using UIFactory
	var panel_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
	panel_config.element_name = "VotingPanel"
	panel_config.size = Vector2(800, 120)
	panel_config.position = Vector2(0, map_container.size.y - 140)
	
	voting_ui_panel = UIFactory.create_ui_element(UIFactory.UIElementType.PANEL, panel_config) as Control
	if not voting_ui_panel:
		Logger.error("Failed to create voting panel", "MapView")
		return
	
	# Add title label
	var title_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
	title_config.element_name = "VotingTitle"
	title_config.text = "Vote for Next Node:"
	title_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_config.size = Vector2(800, 30)
	title_config.position = Vector2(0, 10)
	
	var title_label: Label = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, title_config) as Label
	if title_label:
		voting_ui_panel.add_child(title_label)
	
	# Create voting buttons for each available move
	var button_width: float = 780.0 / available_moves.size()
	
	for i in range(available_moves.size()):
		var node_id: String = available_moves[i]
		var node = current_map_data.get_node(node_id)
		var display_text: String = _get_node_display_name(node)
		
		var button_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
		button_config.element_name = "VoteButton_" + str(i)
		button_config.text = display_text
		button_config.size = Vector2(button_width - 10, 40)
		button_config.position = Vector2(i * button_width + 10, 50)
		
		var vote_button: Button = UIFactory.create_ui_element(UIFactory.UIElementType.BUTTON, button_config) as Button
		if vote_button:
			voting_ui_panel.add_child(vote_button)
			vote_button.pressed.connect(_on_vote_button_pressed.bind(node_id))
	
	# Add voting panel to map container
	map_container.add_child(voting_ui_panel)
	Logger.system("Created voting UI with " + str(available_moves.size()) + " options", "MapView")

## Get display name for a node
func _get_node_display_name(node) -> String:
	if not node:
		return "Unknown"
	
	match node.node_type:
		"start":
			return "Start"
		"boss":
			return "Boss Battle"
		"normal":
			return "Combat Node"
		_:
			return "Node " + str(node.index)

## Handle vote button press
func _on_vote_button_pressed(node_id: String) -> void:
	Logger.game_flow("Vote submitted for node: " + node_id, "MapView")
	
	# TODO: Get actual local player ID
	var local_player_id: int = 0
	
	# Submit vote through navigation
	var success: bool = map_navigation.vote_for_move(current_voting_decision, local_player_id, node_id)
	if success:
		# Disable all voting buttons after successful vote
		if voting_ui_panel:
			for child in voting_ui_panel.get_children():
				if child is Button:
					child.disabled = true
	else:
		Logger.warning("Failed to submit vote for node: " + node_id, "MapView")

## Start voting monitor
func _start_voting_monitor() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_check_voting_completion)
	timer.autostart = true
	add_child(timer)

## Check voting completion
func _check_voting_completion() -> void:
	var party_progress = GameManager.get_party_progress()
	if party_progress and current_voting_decision >= 0:
		if party_progress.is_voting_complete(current_voting_decision):
			_resolve_voting()

## Resolve voting
func _resolve_voting() -> void:
	var success: bool = map_navigation.resolve_node_voting(current_voting_decision)
	if success:
		var chosen_node: String = map_navigation.current_node_id
		Logger.game_flow("Voting resolved and moved to: " + chosen_node, "MapView")
		
		# Update renderer state after voting resolution
		var available_moves: Array[String] = map_navigation.get_available_moves()
		var visited_nodes: Array[String] = map_navigation.get_visited_nodes()
		map_renderer.update_state(current_map_data, available_moves, visited_nodes)
		
		_cleanup_voting_ui()
		current_voting_decision = -1
		
		# Start minigame for the new node
		var node = current_map_data.get_node(chosen_node)
		if node and node.node_type != "start":
			_start_node_minigame(node)

## Clean up voting UI
func _cleanup_voting_ui() -> void:
	if voting_ui_panel:
		voting_ui_panel.queue_free()
		voting_ui_panel = null
	
	# Remove voting timers
	for child in get_children():
		if child is Timer and child.timeout.is_connected(_check_voting_completion):
			child.queue_free()
	
	Logger.debug("Voting UI cleaned up", "MapView")

## Handle completion of current node (called when minigame ends)
func _on_node_completed() -> void:
	Logger.game_flow("Current node completed", "MapView")
	map_navigation.mark_node_completed(map_navigation.current_node_id)
	
	# Update renderer state after completing node and unlocking new paths
	var available_moves: Array[String] = map_navigation.get_available_moves()
	var visited_nodes: Array[String] = map_navigation.get_visited_nodes()
	map_renderer.update_state(current_map_data, available_moves, visited_nodes)
	
	# Check if map is complete
	if map_navigation.is_map_complete():
		Logger.game_flow("Map progression completed!", "MapView")
		# TODO: Handle map completion (victory screen, etc.)
	else:
		# Auto-start voting or movement for next available options
		if available_moves.size() > 1:
			_start_movement_voting(available_moves)
		elif available_moves.size() == 1:
			_execute_move_to_node(available_moves[0])

# Navigation signal handlers (simplified)
func _on_move_requested(node_id: String) -> void:
	Logger.debug("Move requested to: " + node_id, "MapView")

func _on_navigation_node_completed(node_id: String) -> void:
	Logger.debug("Node completed: " + node_id, "MapView")

func _on_nodes_unlocked(unlocked_nodes: Array[String]) -> void:
	Logger.debug("Nodes unlocked: " + str(unlocked_nodes), "MapView")

## UI Button handlers
func _on_back_button_pressed() -> void:
	Logger.game_flow("Returning to main menu", "MapView")
	_cleanup_resources()
	EventBus.request_scene_transition("res://scenes/ui/main_menu.tscn")
	GameManager.transition_to_menu()

func _on_start_game_button_pressed() -> void:
	Logger.game_flow("Starting game from start node", "MapView")
	# Start the minigame for the current start node
	_start_current_node_minigame()

func _on_test_minigame_button_pressed() -> void:
	Logger.game_flow("Starting test minigame", "MapView")
	GameManager.start_minigame("sudden_death")

## Start the minigame for the current node
func _start_current_node_minigame() -> void:
	var current_node_id: String = map_navigation.current_node_id
	var node_data = current_map_data.get_node(current_node_id)
	
	if node_data:
		Logger.game_flow("Starting minigame for node: " + current_node_id, "MapView")
		# All nodes use sudden_death for now
		GameManager.start_minigame("sudden_death")
	else:
		Logger.error("Cannot start minigame: current node not found", "MapView")

## Handle minigame completion to unlock connected nodes
func _on_minigame_completed(minigame_type: String, results: Dictionary) -> void:
	Logger.game_flow("Minigame completed: " + minigame_type, "MapView")
	
	# Mark current node as completed and unlock connected nodes
	var current_node_id: String = map_navigation.current_node_id
	map_navigation.mark_node_completed(current_node_id)
	map_navigation.unlock_connected_nodes(current_node_id)
	
	# Update renderer to show newly available nodes
	var available_moves: Array[String] = map_navigation.get_available_moves()
	var visited_nodes: Array[String] = map_navigation.get_visited_nodes()
	map_renderer.update_state(current_map_data, available_moves, visited_nodes)
	
	# Store updated navigation state
	_store_map_data()
	
	Logger.game_flow("Connected nodes unlocked after completing: " + current_node_id, "MapView")

## Clean up resources on exit
func _cleanup_resources() -> void:
	_cleanup_voting_ui()
	
	# Clear map renderer
	if map_renderer:
		map_renderer = null
	
	Logger.debug("Map view resources cleaned up", "MapView")

## Handle scene exit
func _exit_tree() -> void:
	_cleanup_resources()

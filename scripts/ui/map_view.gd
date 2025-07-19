extends Control

## MVP Map View Controller - Slay the Spire Style Visual Implementation
## Creates a 4-layer tree map with authentic StS visual design

@onready var map_container: Control = $MapContainer
@onready var back_button: Button = $UIContainer/BackButton
@onready var test_minigame_button: Button = $UIContainer/TestMinigameButton

# MVP Map data structure (using simple dictionaries)
var map_data: Dictionary = {}
var current_node_id: String = ""
var visited_nodes: Array[String] = []
var node_buttons: Dictionary = {}
var connection_lines: Array[Line2D] = []

# Available minigames for random selection
var available_minigames: Array[String] = ["sudden_death", "king_of_hill", "team_battle", "free_for_all"]

# Visual configuration for Slay the Spire style
var node_size: Vector2 = Vector2(64, 64)
var layer_spacing: float = 120.0
var node_spacing: float = 80.0

# Node type icons (using text symbols for now, easily replaceable with actual icons)
var node_icons: Dictionary = {
	"tutorial": "🎯",
	"sudden_death": "⚔️",
	"king_of_hill": "👑", 
	"team_battle": "🛡️",
	"free_for_all": "💥",
	"boss_battle": "🐉"
}

func _ready() -> void:
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	test_minigame_button.pressed.connect(_on_test_minigame_button_pressed)
	
	# Generate and display MVP map
	_generate_mvp_map()
	_display_map()
	
	Logger.system("MVP Map view loaded with Slay the Spire styling", "MapView")

## Generate a simple 4-layer tree map
func _generate_mvp_map() -> void:
	map_data = {
		"nodes": {},
		"connections": {},
		"layers": 4,
		"current_node": "start",
		"final_node": "boss_finale"
	}
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Layer 0: Start node
	_create_node("start", 0, 0, "Start", "tutorial")
	current_node_id = "start"
	
	# Generate layers 1-3 with random nodes
	var previous_layer_nodes: Array[String] = ["start"]
	
	for layer in range(1, 4):
		var nodes_in_layer = rng.randi_range(2, 5)
		var current_layer_nodes: Array[String] = []
		
		for node_index in range(nodes_in_layer):
			var node_id = "layer_" + str(layer) + "_node_" + str(node_index)
			var minigame_type = available_minigames[rng.randi() % available_minigames.size()]
			_create_node(node_id, layer, node_index, minigame_type.capitalize(), minigame_type)
			current_layer_nodes.append(node_id)
		
		# Connect previous layer to current layer
		_connect_layers(previous_layer_nodes, current_layer_nodes, rng)
		previous_layer_nodes = current_layer_nodes
	
	# Layer 4: Final boss node (all paths lead here)
	_create_node("boss_finale", 4, 0, "Final Boss", "boss_battle")
	_connect_layers(previous_layer_nodes, ["boss_finale"], rng)
	
	Logger.system("Generated MVP map with " + str(map_data.nodes.size()) + " nodes", "MapView")

## Create a node in the map data
func _create_node(node_id: String, layer: int, index: int, display_name: String, minigame_type: String) -> void:
	map_data.nodes[node_id] = {
		"id": node_id,
		"layer": layer,
		"index": index,
		"display_name": display_name,
		"minigame_type": minigame_type,
		"position": _calculate_node_position(layer, index, _count_nodes_in_layer(layer)),
		"available": (node_id == "start"),  # Only start node available initially
		"completed": false,
		"connections_out": []
	}

## Connect nodes between layers
func _connect_layers(from_layer: Array[String], to_layer: Array[String], rng: RandomNumberGenerator) -> void:
	# Each node in from_layer connects to 1-3 nodes in to_layer
	for from_node in from_layer:
		var connections_to_make = rng.randi_range(1, min(3, to_layer.size()))
		var possible_targets = to_layer.duplicate()
		
		for i in range(connections_to_make):
			if possible_targets.is_empty():
				break
			
			var target = possible_targets[rng.randi() % possible_targets.size()]
			map_data.nodes[from_node].connections_out.append(target)
			possible_targets.erase(target)

## Calculate node position for Slay the Spire style layout
func _calculate_node_position(layer: int, index: int, total_in_layer: int) -> Vector2:
	var container_size: Vector2 = Vector2(800, 600)  # Default size
	if map_container and map_container.size != Vector2.ZERO:
		container_size = map_container.size
	
	# Vertical layout like Slay the Spire (bottom to top)
	var y = container_size.y - (layer * layer_spacing) - 80  # Bottom to top progression
	
	# Center the layer horizontally
	var total_width = (total_in_layer - 1) * node_spacing
	var start_x = (container_size.x - total_width) / 2.0
	var x = start_x + (index * node_spacing)
	
	return Vector2(x, y)

## Count how many nodes will be in a layer (for positioning)
func _count_nodes_in_layer(target_layer: int) -> int:
	var count = 0
	for node_data in map_data.nodes.values():
		if node_data.layer == target_layer:
			count += 1
	return count + 1  # +1 for the node we're about to add

## Display the map using Slay the Spire visual style
func _display_map() -> void:
	# Clear existing display
	_clear_map_display()
	
	# Create connection lines first (behind nodes)
	_draw_connections()
	
	# Create node buttons with icons
	for node_id in map_data.nodes.keys():
		_create_node_visual(node_id)
	
	# Update button states
	_update_node_availability()

## Clear previous map display
func _clear_map_display() -> void:
	for child in map_container.get_children():
		child.queue_free()
	node_buttons.clear()
	connection_lines.clear()

## Draw dotted connection lines like Slay the Spire
func _draw_connections() -> void:
	for node_id in map_data.nodes.keys():
		var node_data = map_data.nodes[node_id]
		for target_id in node_data.connections_out:
			if target_id in map_data.nodes:
				_create_dotted_connection(node_data.position, map_data.nodes[target_id].position)

## Create a dotted connection line like Slay the Spire
func _create_dotted_connection(from_pos: Vector2, to_pos: Vector2) -> void:
	var line = Line2D.new()
	
	# Create dotted line effect
	var distance = from_pos.distance_to(to_pos)
	var direction = (to_pos - from_pos).normalized()
	var dot_spacing = 8.0
	var dot_count = int(distance / dot_spacing)
	
	for i in range(dot_count):
		var start_pos = from_pos + direction * (i * dot_spacing)
		var end_pos = from_pos + direction * (i * dot_spacing + 3.0)  # Small dots
		
		if i < dot_count - 1:  # Don't overdraw at the end
			line.add_point(start_pos)
			line.add_point(end_pos)
	
	line.default_color = Color(0.4, 0.3, 0.2, 0.8)  # Brown/sepia color
	line.width = 2.0
	line.z_index = -1  # Behind nodes
	
	map_container.add_child(line)
	connection_lines.append(line)

## Create a Slay the Spire style node visual
func _create_node_visual(node_id: String) -> void:
	var node_data = map_data.nodes[node_id]
	
	# Create a container for the node
	var node_container = Control.new()
	node_container.size = node_size
	node_container.position = node_data.position - node_size / 2
	
	# Create background circle for the node
	var background = ColorRect.new()
	background.size = node_size
	background.color = _get_node_background_color(node_data)
	# Make it circular by using a custom shader or drawing (simplified with ColorRect for now)
	node_container.add_child(background)
	
	# Create icon label
	var icon_config = UIFactory.UIElementConfig.new()
	icon_config.element_name = "NodeIcon_" + node_id
	icon_config.text = node_icons.get(node_data.minigame_type, "❓")
	icon_config.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_config.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var icon_label = UIFactory.create_ui_element(UIFactory.UIElementType.LABEL, icon_config)
	if icon_label and icon_label is Label:
		var label = icon_label as Label
		label.size = node_size
		label.add_theme_font_size_override("font_size", 24)
		node_container.add_child(label)
	
	# Create invisible button for interaction
	var button = Button.new()
	button.size = node_size
	button.flat = true  # No visual button appearance
	button.pressed.connect(_on_node_pressed.bind(node_id))
	node_container.add_child(button)
	
	# Store references
	node_buttons[node_id] = button
	map_container.add_child(node_container)

## Get background color for node based on its state and type
func _get_node_background_color(node_data: Dictionary) -> Color:
	var node_id = node_data.id
	
	# State-based coloring
	if node_id == current_node_id:
		return Color(1.0, 1.0, 0.6, 1.0)  # Light yellow for current
	elif node_id in visited_nodes:
		return Color(0.5, 0.5, 0.5, 0.8)  # Gray for visited
	elif node_data.available:
		# Type-based coloring for available nodes
		match node_data.minigame_type:
			"tutorial":
				return Color(0.7, 0.9, 0.7, 1.0)  # Light green
			"boss_battle":
				return Color(0.9, 0.4, 0.4, 1.0)  # Red for boss
			_:
				return Color(0.8, 0.8, 0.9, 1.0)  # Light blue for regular
	else:
		return Color(0.3, 0.3, 0.3, 0.6)  # Dark gray for locked

## Update which nodes are available/disabled
func _update_node_availability() -> void:
	for node_id in node_buttons.keys():
		var button = node_buttons[node_id]
		var node_data = map_data.nodes[node_id]
		
		# Check if node is available and not completed
		var is_available = node_data.available and not node_data.completed
		var is_visited = node_id in visited_nodes
		
		# Set button state
		button.disabled = not is_available or is_visited
		
		# Update visual appearance by changing the container's modulate
		var container = button.get_parent()
		if container:
			if is_visited:
				container.modulate = Color(0.7, 0.7, 0.7, 1.0)  # Dimmed for visited
			elif is_available:
				container.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Full brightness for available
			else:
				container.modulate = Color(0.5, 0.5, 0.5, 0.8)   # Dimmed for locked

## Handle node button press
func _on_node_pressed(node_id: String) -> void:
	var node_data = map_data.nodes[node_id]
	
	# Check if this is a valid move
	if not _can_move_to_node(node_id):
		Logger.warning("Cannot move to node: " + node_id, "MapView")
		return
	
	# Move to the node
	_move_to_node(node_id)

## Check if player can move to a specific node
func _can_move_to_node(target_node_id: String) -> bool:
	# Cannot move to already visited nodes
	if target_node_id in visited_nodes:
		return false
	
	# Must be connected to current node
	var current_node_data = map_data.nodes[current_node_id]
	if not target_node_id in current_node_data.connections_out:
		return false
	
	# Node must be available (unlocked nodes are automatically available)
	var target_node_data = map_data.nodes[target_node_id]
	return target_node_data.available

## Move player to a node and start appropriate action
func _move_to_node(node_id: String) -> void:
	var node_data = map_data.nodes[node_id]
	
	# Mark current node as visited and completed
	if current_node_id != "":
		visited_nodes.append(current_node_id)
		map_data.nodes[current_node_id].completed = true
	
	# Update current position
	current_node_id = node_id
	map_data.current_node = node_id
	
	# Unlock connected nodes
	_unlock_connected_nodes(node_id)
	
	# Update visual state
	_update_node_availability()
	
	Logger.game_flow("Moved to node: " + node_data.display_name, "MapView")
	
	# Start the minigame for this node
	if node_data.minigame_type != "tutorial":
		_start_node_minigame(node_data)

## Unlock nodes connected to the given node
func _unlock_connected_nodes(node_id: String) -> void:
	var node_data = map_data.nodes[node_id]
	for connected_id in node_data.connections_out:
		if connected_id in map_data.nodes:
			map_data.nodes[connected_id].available = true

## Start the minigame for a node
func _start_node_minigame(node_data: Dictionary) -> void:
	Logger.game_flow("Starting minigame: " + node_data.minigame_type, "MapView")
	
	# For MVP, just start sudden_death for all nodes (until more minigames exist)
	var minigame_type = "sudden_death"  # Default to working minigame
	if node_data.minigame_type == "boss_battle":
		minigame_type = "sudden_death"  # Boss uses same minigame for now
	
	GameManager.start_minigame(minigame_type)

func _on_back_button_pressed() -> void:
	Logger.game_flow("Returning to main menu", "MapView")
	EventBus.request_scene_transition("res://scenes/ui/main_menu.tscn")
	GameManager.transition_to_menu()

func _on_test_minigame_button_pressed() -> void:
	Logger.game_flow("Starting test minigame", "MapView")
	GameManager.start_minigame("sudden_death") 
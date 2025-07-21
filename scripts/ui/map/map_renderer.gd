class_name MapRenderer
extends RefCounted

signal node_selected(node_id: String)

# Required imports
const MinigameDisplayNames = preload("res://scripts/map/config/minigame_display_names.gd")
const LineDrawer = preload("res://scripts/ui/map/line_drawer.gd")

# Configuration
var visual_config: MapVisualConfig
var _default_visual_config: MapVisualConfig

# Current rendered data
var _current_map_data: MapData
var _current_container: Control
var _node_buttons: Dictionary = {}
var _line_drawer: LineDrawer
var _connection_data: Array = []  # Store connection info for updating colors

func _init(config: MapVisualConfig = null) -> void:
	if config:
		visual_config = config
	else:
		_load_default_visual_config()

func _load_default_visual_config() -> void:
	if not _default_visual_config:
		_default_visual_config = ConfigManager.get_map_visual_config("default_visual") as MapVisualConfig
	visual_config = _default_visual_config

## Main rendering method
func render(map_data: MapData, container: Control) -> void:
	if not map_data or not container:
		Logger.error("Invalid parameters for map rendering", "MapRenderer")
		return
	
	_current_map_data = map_data
	_current_container = container
	
	# Clear existing content
	_clear_container()
	
	# Create line drawer if needed
	if not _line_drawer:
		_line_drawer = LineDrawer.new()
		_line_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_current_container.add_child(_line_drawer)
		_current_container.move_child(_line_drawer, 0)  # Behind everything
	
	# Calculate layer positions with precomputed counts
	var layer_counts: Dictionary = _precompute_layer_counts(map_data)
	var layer_positions: Dictionary = _calculate_layer_positions(layer_counts, container.size.y)
	
	# Create node buttons FIRST so they exist for connection line positioning
	_create_node_buttons(map_data, layer_positions)
	
	# Draw connection lines AFTER buttons exist using line drawer
	_create_connection_lines(map_data)

## Update visual state without full re-render
func update_state(map_data: MapData, available_moves: Array = [], visited_nodes: Array = []) -> void:
	if not map_data or not _current_container:
		return
	
	_current_map_data = map_data
	
	# Update existing node button states
	for node_id: String in _node_buttons.keys():
		var button: Button = _node_buttons[node_id]
		var node: MapNode = map_data.get_node(node_id)
		if node and button:
			_update_node_button_state(button, node, available_moves)
	
	# Update connection line positions if needed
	_update_connection_line_positions()
	
	# Update connection line colors based on visited status
	_update_connection_line_colors(visited_nodes)

## Clear all rendered content
func _clear_container() -> void:
	if not _current_container:
		return
	
	# Clear line drawer
	if _line_drawer:
		_line_drawer.clear_lines()
	
	# Remove all child nodes except line drawer
	for child in _current_container.get_children():
		if child != _line_drawer:
			child.queue_free()
	
	# Clear tracking dictionaries and arrays
	_node_buttons.clear()
	_connection_data.clear()

## Precompute how many nodes are in each layer
func _precompute_layer_counts(map_data: MapData) -> Dictionary:
	var layer_counts: Dictionary = {}
	
	for node: MapNode in map_data.nodes.values():
		if node.layer not in layer_counts:
			layer_counts[node.layer] = 0
		layer_counts[node.layer] += 1
	
	return layer_counts

## Calculate Y positions for each layer to prevent overlap
func _calculate_layer_positions(layer_counts: Dictionary, container_height: float) -> Dictionary:
	var layer_positions: Dictionary = {}
	
	# Calculate available height with margins
	var margin: float = visual_config.container_margin.y
	var available_height: float = container_height - (2 * margin)
	
	for layer: int in layer_counts.keys():
		var nodes_in_layer: int = layer_counts[layer]
		var total_content_height: float = nodes_in_layer * visual_config.node_size.y + (nodes_in_layer - 1) * visual_config.row_spacing
		
		# Auto-scale spacing if content would overflow
		var row_spacing: float = visual_config.row_spacing
		if total_content_height > available_height and nodes_in_layer > 1:
			row_spacing = (available_height - nodes_in_layer * visual_config.node_size.y) / max(1, nodes_in_layer - 1)
			row_spacing = max(10.0, row_spacing)  # Minimum spacing
		
		var final_total_height: float = (nodes_in_layer - 1) * row_spacing
		var y_offset: float = margin + (available_height - final_total_height) * 0.5
		
		layer_positions[layer] = y_offset
	
	return layer_positions

## Create buttons for all nodes using UIFactory
func _create_node_buttons(map_data: MapData, layer_positions: Dictionary) -> void:
	var layers: Array = map_data.nodes.values().map(func(node: MapNode): return node.layer)
	layers = Array(layers.reduce(func(acc, layer): 
		if layer not in acc: acc.append(layer)
		return acc, []))
	layers.sort()
	
	for layer: int in layers:
		var nodes_in_layer: Array[MapNode] = map_data.get_nodes_in_layer(layer)
		nodes_in_layer.sort_custom(func(a: MapNode, b: MapNode): return a.index < b.index)
		
		var y_start: float = layer_positions[layer]
		
		for i in range(nodes_in_layer.size()):
			var node: MapNode = nodes_in_layer[i]
			var node_button: Button = _create_node_button(node, layer, y_start + i * visual_config.row_spacing)
			_current_container.add_child(node_button)
			_node_buttons[node.id] = node_button

## Create individual node button through UIFactory
func _create_node_button(node: MapNode, layer: int, y_position: float) -> Button:
	# Create single clickable node button
	var button_config: UIFactory.UIElementConfig = UIFactory.UIElementConfig.new()
	button_config.element_name = "MapNode_" + node.id
	button_config.text = _get_node_display_text(node)
	button_config.size = visual_config.node_size
	button_config.position = Vector2(layer * visual_config.layer_spacing, y_position)
	
	var button: Button = UIFactory.create_ui_element(UIFactory.UIElementType.BUTTON, button_config) as Button
	
	# Update visual state (will be updated with accessibility info when update_state is called)
	_update_node_button_state(button, node)
	
	# Connect button signal
	if not button.pressed.is_connected(_on_node_button_pressed):
		button.pressed.connect(_on_node_button_pressed.bind(node.id))
	
	return button

## Get display text for node based on type
func _get_node_display_text(node: MapNode) -> String:
	return MinigameDisplayNames.get_display_name(node.node_type)

## Update button visual state based on node data
func _update_node_button_state(button: Button, node: MapNode, available_moves: Array = []) -> void:
	if not button:
		return
	
	var color: Color = _get_node_state_color(node, available_moves)
	var is_accessible: bool = _is_node_accessible(node, available_moves)
	
	# Set button accessibility
	button.disabled = not is_accessible
	
	# Apply color styling with better visual design
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	var pressed_style: StyleBoxFlat = StyleBoxFlat.new()
	var disabled_style: StyleBoxFlat = StyleBoxFlat.new()
	
	# Configure normal state
	normal_style.bg_color = color
	normal_style.set_corner_radius_all(visual_config.corner_radius)
	normal_style.set_border_width_all(visual_config.border_width)
	normal_style.border_color = color.darkened(0.3)
	normal_style.shadow_offset = Vector2(2, 2)
	normal_style.shadow_size = 1
	normal_style.shadow_color = Color(0, 0, 0, 0.3)
	
	# Configure hover state (brighter)
	hover_style.bg_color = color.lightened(0.2)
	hover_style.set_corner_radius_all(visual_config.corner_radius)
	hover_style.set_border_width_all(visual_config.border_width)
	hover_style.border_color = color.darkened(0.2)
	hover_style.shadow_offset = Vector2(3, 3)
	hover_style.shadow_size = 2
	hover_style.shadow_color = Color(0, 0, 0, 0.4)
	
	# Configure pressed state (darker)
	pressed_style.bg_color = color.darkened(0.1)
	pressed_style.set_corner_radius_all(visual_config.corner_radius)
	pressed_style.set_border_width_all(visual_config.border_width)
	pressed_style.border_color = color.darkened(0.4)
	pressed_style.shadow_offset = Vector2(1, 1)
	pressed_style.shadow_size = 1
	pressed_style.shadow_color = Color(0, 0, 0, 0.5)
	
	# Configure disabled state
	disabled_style.bg_color = color.darkened(0.4)
	disabled_style.set_corner_radius_all(visual_config.corner_radius)
	disabled_style.set_border_width_all(1)
	disabled_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	
	# Set font color for better contrast
	button.add_theme_color_override("font_color", visual_config.font_color)
	button.add_theme_color_override("font_hover_color", visual_config.font_color)
	button.add_theme_color_override("font_pressed_color", visual_config.font_color)
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.7))

## Get color based on node state
func _get_node_state_color(node: MapNode, available_moves: Array = []) -> Color:
	# Check if node is available for movement
	if node.id in available_moves:
		return visual_config.color_available
	
	# For now, use node type to determine state since we don't have navigation state here
	# This will be properly colored when we integrate with navigation state tracking
	match node.node_type:
		"start":
			return visual_config.color_visited  # Start node is always "visited"
		"boss":
			return visual_config.color_locked   # Boss is locked until accessible
		_:
			return visual_config.color_locked   # Other nodes locked by default

## Check if node is accessible for player interaction
func _is_node_accessible(node: MapNode, available_moves: Array = []) -> bool:
	# Available moves are accessible
	if node.id in available_moves:
		return true
	
	# All other nodes are not accessible for clicking
	return false

## Create connection lines between nodes
func _create_connection_lines(map_data: MapData) -> void:
	if not _line_drawer:
		return
		
	_line_drawer.clear_lines()
	_connection_data.clear()
	
	for node: MapNode in map_data.nodes.values():
		for connection_id: String in node.outgoing_connections:
			var target_node: MapNode = map_data.get_node(connection_id)
			if target_node:
				_create_connection_line(node, target_node)

## Create single connection line between two nodes
func _create_connection_line(from_node: MapNode, to_node: MapNode) -> void:
	# Calculate positions using button centers
	var from_container: Control = _node_buttons.get(from_node.id)
	var to_container: Control = _node_buttons.get(to_node.id)
	
	if from_container and to_container and _line_drawer:
		var from_center: Vector2 = from_container.position + visual_config.node_size * 0.5
		var to_center: Vector2 = to_container.position + visual_config.node_size * 0.5
		
		# Store connection data for color updates
		_connection_data.append({
			"from_id": from_node.id,
			"to_id": to_node.id,
			"from_pos": from_center,
			"to_pos": to_center
		})
		
		# Add white dotted line by default
		_line_drawer.add_line(from_center, to_center, Color.WHITE, 3.0, true)

## Apply dashed effect to connection line
func _apply_dashed_effect(line: Line2D, line_color: Color = Color.WHITE) -> void:
	# Create small dot pattern like Slay the Spire
	var dash_length: int = max(4, int(visual_config.dash_length))  # Small dots
	var gap_length: int = max(8, int(visual_config.dash_length * 1.5))  # Larger gaps
	var pattern_length: int = dash_length + gap_length
	var line_height: int = max(2, int(visual_config.line_width))
	
	# Create image for dot pattern
	var image: Image = Image.create(pattern_length, line_height, false, Image.FORMAT_RGBA8)
	
	# Fill the entire image with transparent first
	image.fill(Color.TRANSPARENT)
	
	# Create small dot - fill only center portion for more dot-like appearance
	var dot_start: int = 0
	var dot_end: int = dash_length
	
	for x in range(dot_start, dot_end):
		for y in range(line_height):
			image.set_pixel(x, y, line_color)
	
	# Create texture from image
	var texture: ImageTexture = ImageTexture.new()
	texture.set_image(image)
	
	line.texture = texture
	line.texture_mode = Line2D.LINE_TEXTURE_TILE

## Update connection line colors based on visited nodes
func _update_connection_line_colors(visited_nodes: Array = []) -> void:
	if not _line_drawer:
		return
	
	# Clear existing lines and redraw with updated colors
	_line_drawer.clear_lines()
	
	for connection_data in _connection_data:
		var from_id: String = connection_data.from_id
		var to_id: String = connection_data.to_id
		var from_pos: Vector2 = connection_data.from_pos
		var to_pos: Vector2 = connection_data.to_pos
		
		# Check if both nodes have been visited
		var from_visited: bool = from_id in visited_nodes
		var to_visited: bool = to_id in visited_nodes
		
		# White dotted for unvisited, dark solid for visited connections
		var line_color: Color = Color.WHITE
		var is_dotted: bool = true
		
		if from_visited and to_visited:
			line_color = Color(0.3, 0.3, 0.3, 0.9)  # Dark gray
			is_dotted = false  # Solid line for visited
		
		_line_drawer.add_line(from_pos, to_pos, line_color, 3.0, is_dotted)

## Update connection line positions based on current button positions
func _update_connection_line_positions() -> void:
	# TODO: Update this for LineDrawer approach
	return

## Handle node button press
func _on_node_button_pressed(node_id: String) -> void:
	node_selected.emit(node_id)

class_name MapGenerator

var _default_generation_config: MapGenerationConfig

func _init() -> void:
	_load_default_generation_config()

func _load_default_generation_config() -> void:
	if not _default_generation_config:
		_default_generation_config = ConfigManager.get_map_generation_config("default_generation") as MapGenerationConfig

static func generate(config: MapGenerationConfig = null) -> MapData:
	var generator: MapGenerator = MapGenerator.new()
	return generator._generate_with_config(config)

func _generate_with_config(config: MapGenerationConfig = null) -> MapData:
	var generation_config: MapGenerationConfig = config if config else _default_generation_config
	var seed_value: int = generation_config.get_effective_seed()
	
	Logger.system("MapGenerator starting generation with seed: %d" % seed_value)
	seed(seed_value)
	
	var map_data: MapData = MapData.new()
	
	# Precompute layer node counts to ensure consistent structure
	var layer_counts: Array[int] = []
	layer_counts.append(1) # Start layer
	for i in range(generation_config.get_intermediate_layer_count()):
		var min_nodes: int = generation_config.get_min_nodes_for_layer(i + 1)
		var max_nodes: int = generation_config.get_max_nodes_for_layer(i + 1)
		layer_counts.append(randi_range(min_nodes, max_nodes))
	layer_counts.append(1) # Boss layer
	
	Logger.system("MapGenerator layer structure: %s" % str(layer_counts))
	
	# Generate nodes for each layer
	_generate_nodes(map_data, layer_counts, generation_config)
	
	# Create connections ensuring no dead ends
	_create_connections(map_data, layer_counts, generation_config)
	
	# Validate final map
	if generation_config.ensure_connectivity and not map_data.validate_connectivity():
		Logger.system("MapGenerator validation failed, regenerating...")
		return _generate_with_config(generation_config) # Regenerate if validation fails
	
	Logger.system("MapGenerator completed successfully with %d total nodes" % map_data.get_total_nodes())
	return map_data

func _generate_nodes(map_data: MapData, layer_counts: Array[int], config: MapGenerationConfig) -> void:
	for layer_index in range(layer_counts.size()):
		var nodes_in_layer: int = layer_counts[layer_index]
		
		for node_index in range(nodes_in_layer):
			var node_id: String = "L%d_N%d" % [layer_index, node_index]
			var node_type: String = _get_node_type(layer_index, layer_counts.size(), config)
			
			var node: MapNode = MapNode.new(node_id, layer_index, node_index, node_type)
			map_data.add_node(node)
			
			Logger.system("MapGenerator created node: %s (type: %s)" % [node_id, node_type])

func _get_node_type(layer_index: int, total_layers: int, config: MapGenerationConfig) -> String:
	if layer_index == 0:
		return "start"
	elif layer_index == total_layers - 1:
		return "boss"
	else:
		# Use configured node types with special node weight
		if randf() < config.special_node_weight and config.available_node_types.size() > 0:
			return config.available_node_types[randi() % config.available_node_types.size()]
		else:
			return "normal"

func _create_connections(map_data: MapData, layer_counts: Array[int], config: MapGenerationConfig) -> void:
	Logger.system("MapGenerator creating connections...")
	
	# Store all existing connections to check for overlaps
	var existing_connections: Array = []
	
	# Connect each layer to the next, ensuring every node has proper connectivity
	for layer_index in range(layer_counts.size() - 1):
		var current_layer_nodes: Array[MapNode] = map_data.get_nodes_in_layer(layer_index)
		var next_layer_nodes: Array[MapNode] = map_data.get_nodes_in_layer(layer_index + 1)
		
		# Calculate node positions for overlap detection
		var current_positions: Dictionary = _calculate_node_positions(current_layer_nodes, layer_index, layer_counts)
		var next_positions: Dictionary = _calculate_node_positions(next_layer_nodes, layer_index + 1, layer_counts)
		
		# Ensure every node in next layer has at least one incoming connection
		_ensure_incoming_connections(current_layer_nodes, next_layer_nodes, config, existing_connections, current_positions, next_positions)
		
		# Ensure every node in current layer has at least one outgoing connection
		_ensure_outgoing_connections(current_layer_nodes, next_layer_nodes, config, existing_connections, current_positions, next_positions)

func _ensure_incoming_connections(current_layer: Array[MapNode], next_layer: Array[MapNode], config: MapGenerationConfig, existing_connections: Array, current_positions: Dictionary, next_positions: Dictionary) -> void:
	# First pass: guarantee each next layer node gets at least one connection
	for target_node: MapNode in next_layer:
		var source_node: MapNode = _find_valid_connection_source(target_node, current_layer, existing_connections, current_positions, next_positions)
		if source_node:
			source_node.add_connection(target_node.id)
			_add_connection_to_tracking(existing_connections, source_node.id, target_node.id, current_positions, next_positions)
			Logger.system("MapGenerator guaranteed connection: %s (idx:%d) -> %s (idx:%d)" % [source_node.id, source_node.index, target_node.id, target_node.index])
	
	# Skip additional connections for now to reduce overlap potential
	# Second pass: add additional random connections for variety (only if no overlaps)
	#if randf() < config.additional_connection_chance:
	#	var additional_connections: int = randi_range(1, max(1, current_layer.size()))
	#	for i in range(additional_connections):
	#		var target_node: MapNode = next_layer[randi() % next_layer.size()]
	#		var source_node: MapNode = _find_valid_connection_source(target_node, current_layer, existing_connections, current_positions, next_positions)
	#		if source_node and not source_node.has_connection(target_node.id):
	#			source_node.add_connection(target_node.id)
	#			_add_connection_to_tracking(existing_connections, source_node.id, target_node.id, current_positions, next_positions)

func _ensure_outgoing_connections(current_layer: Array[MapNode], next_layer: Array[MapNode], config: MapGenerationConfig, existing_connections: Array, current_positions: Dictionary, next_positions: Dictionary) -> void:
	# Ensure every current layer node has at least one outgoing connection
	for source_node: MapNode in current_layer:
		if not source_node.has_outgoing_connections():
			var target_node: MapNode = _find_valid_connection_target(source_node, next_layer, existing_connections, current_positions, next_positions)
			if target_node:
				source_node.add_connection(target_node.id)
				_add_connection_to_tracking(existing_connections, source_node.id, target_node.id, current_positions, next_positions)
				Logger.system("MapGenerator ensured outgoing for: %s (idx:%d) -> %s (idx:%d)" % [source_node.id, source_node.index, target_node.id, target_node.index])

## Calculate positions for nodes to enable overlap detection
func _calculate_node_positions(nodes: Array[MapNode], layer_index: int, layer_counts: Array[int]) -> Dictionary:
	var positions: Dictionary = {}
	
	# Use same positioning logic as MapRenderer
	var layer_spacing: float = 200.0  # Standard layer spacing
	var row_spacing: float = 80.0     # Standard row spacing
	var container_height: float = 600.0  # Approximate container height
	var margin: float = 50.0
	
	var available_height: float = container_height - (2 * margin)
	var nodes_count: int = nodes.size()
	
	var total_content_height: float = nodes_count * 64.0 + (nodes_count - 1) * row_spacing
	
	# Auto-scale spacing if content would overflow
	if total_content_height > available_height and nodes_count > 1:
		row_spacing = (available_height - nodes_count * 64.0) / max(1, nodes_count - 1)
		row_spacing = max(10.0, row_spacing)
	
	var final_total_height: float = (nodes_count - 1) * row_spacing
	var y_offset: float = margin + (available_height - final_total_height) * 0.5
	
	for i in range(nodes.size()):
		var node: MapNode = nodes[i]
		var pos: Vector2 = Vector2(layer_index * layer_spacing + 32, y_offset + i * row_spacing + 32)  # +32 for node center
		positions[node.id] = pos
	
	return positions

## Check if two lines intersect (for overlap detection)
func _lines_intersect(line1_start: Vector2, line1_end: Vector2, line2_start: Vector2, line2_end: Vector2) -> bool:
	# Add a small buffer around intersection detection to prevent near-misses
	var d1: Vector2 = line1_end - line1_start
	var d2: Vector2 = line2_end - line2_start
	var d3: Vector2 = line1_start - line2_start
	
	var cross1: float = d1.x * d2.y - d1.y * d2.x
	if abs(cross1) < 0.001:  # Lines are parallel or collinear
		return _lines_are_collinear_and_overlapping(line1_start, line1_end, line2_start, line2_end)
	
	var t1: float = (d3.x * d2.y - d3.y * d2.x) / cross1
	var t2: float = (d3.x * d1.y - d3.y * d1.x) / cross1
	
	# Use slightly relaxed bounds to catch near-intersections
	return t1 >= -0.01 and t1 <= 1.01 and t2 >= -0.01 and t2 <= 1.01

## Check if two collinear lines overlap
func _lines_are_collinear_and_overlapping(line1_start: Vector2, line1_end: Vector2, line2_start: Vector2, line2_end: Vector2) -> bool:
	# For collinear lines, check if they overlap along their length
	var line1_min_x: float = min(line1_start.x, line1_end.x)
	var line1_max_x: float = max(line1_start.x, line1_end.x)
	var line2_min_x: float = min(line2_start.x, line2_end.x)
	var line2_max_x: float = max(line2_start.x, line2_end.x)
	
	var line1_min_y: float = min(line1_start.y, line1_end.y)
	var line1_max_y: float = max(line1_start.y, line1_end.y)
	var line2_min_y: float = min(line2_start.y, line2_end.y)
	var line2_max_y: float = max(line2_start.y, line2_end.y)
	
	# Check if the line segments overlap in both x and y dimensions
	var x_overlap: bool = line1_max_x >= line2_min_x and line2_max_x >= line1_min_x
	var y_overlap: bool = line1_max_y >= line2_min_y and line2_max_y >= line1_min_y
	
	return x_overlap and y_overlap

## Find a valid connection target that doesn't create overlapping lines and respects Y adjacency
func _find_valid_connection_target(source_node: MapNode, possible_targets: Array[MapNode], existing_connections: Array, current_positions: Dictionary, next_positions: Dictionary) -> MapNode:
	var source_pos: Vector2 = current_positions[source_node.id]
	
	# Sort targets by Y adjacency first (within +/-1), then by Y position
	var adjacent_targets: Array[MapNode] = []
	var non_adjacent_targets: Array[MapNode] = []
	
	for target_node: MapNode in possible_targets:
		var y_distance: int = abs(target_node.index - source_node.index)
		if y_distance <= 1:
			adjacent_targets.append(target_node)
		else:
			non_adjacent_targets.append(target_node)
	
	# Sort both arrays by index for consistent ordering
	adjacent_targets.sort_custom(func(a: MapNode, b: MapNode): return a.index < b.index)
	non_adjacent_targets.sort_custom(func(a: MapNode, b: MapNode): return a.index < b.index)
	
	# Try adjacent targets first
	for target_node: MapNode in adjacent_targets:
		var target_pos: Vector2 = next_positions[target_node.id]
		
		# Check if this connection would overlap with any existing connections
		var has_overlap: bool = false
		for connection in existing_connections:
			var existing_start: Vector2 = connection.start_pos
			var existing_end: Vector2 = connection.end_pos
			
			if _lines_intersect(source_pos, target_pos, existing_start, existing_end):
				has_overlap = true
				break
		
		if not has_overlap:
			return target_node
	
	# If no adjacent non-overlapping target found, find nearest Y position as fallback (to prevent orphaning)
	if non_adjacent_targets.size() > 0:
		# Find the nearest node by Y distance (index difference)
		var nearest_target: MapNode = non_adjacent_targets[0]
		var min_distance: int = abs(nearest_target.index - source_node.index)
		
		for target_node: MapNode in non_adjacent_targets:
			var distance: int = abs(target_node.index - source_node.index)
			if distance < min_distance:
				min_distance = distance
				nearest_target = target_node
		
		# Try the nearest target for overlap
		var nearest_pos: Vector2 = next_positions[nearest_target.id]
		var has_overlap: bool = false
		for connection in existing_connections:
			var existing_start: Vector2 = connection.start_pos
			var existing_end: Vector2 = connection.end_pos
			
			if _lines_intersect(source_pos, nearest_pos, existing_start, existing_end):
				has_overlap = true
				break
		
		if not has_overlap:
			return nearest_target
	
	# Final fallback to prevent orphaning - use nearest available
	if adjacent_targets.size() > 0:
		return adjacent_targets[0]
	elif non_adjacent_targets.size() > 0:
		# Return the nearest non-adjacent target
		var nearest_target: MapNode = non_adjacent_targets[0]
		var min_distance: int = abs(nearest_target.index - source_node.index)
		
		for target_node: MapNode in non_adjacent_targets:
			var distance: int = abs(target_node.index - source_node.index)
			if distance < min_distance:
				min_distance = distance
				nearest_target = target_node
		
		return nearest_target
	
	return null

## Find a valid connection source that doesn't create overlapping lines and respects Y adjacency
func _find_valid_connection_source(target_node: MapNode, possible_sources: Array[MapNode], existing_connections: Array, current_positions: Dictionary, next_positions: Dictionary) -> MapNode:
	var target_pos: Vector2 = next_positions[target_node.id]
	
	# Sort sources by Y adjacency first (within +/-1), then by index
	var adjacent_sources: Array[MapNode] = []
	var non_adjacent_sources: Array[MapNode] = []
	
	for source_node: MapNode in possible_sources:
		var y_distance: int = abs(source_node.index - target_node.index)
		if y_distance <= 1:
			adjacent_sources.append(source_node)
		else:
			non_adjacent_sources.append(source_node)
	
	# Sort both arrays by index for consistent ordering
	adjacent_sources.sort_custom(func(a: MapNode, b: MapNode): return a.index < b.index)
	non_adjacent_sources.sort_custom(func(a: MapNode, b: MapNode): return a.index < b.index)
	
	# Try adjacent sources first
	for source_node: MapNode in adjacent_sources:
		var source_pos: Vector2 = current_positions[source_node.id]
		
		# Check if this connection would overlap with any existing connections
		var has_overlap: bool = false
		for connection in existing_connections:
			var existing_start: Vector2 = connection.start_pos
			var existing_end: Vector2 = connection.end_pos
			
			if _lines_intersect(source_pos, target_pos, existing_start, existing_end):
				has_overlap = true
				break
		
		if not has_overlap:
			return source_node
	
	# If no adjacent non-overlapping source found, find nearest Y position as fallback (to prevent orphaning)
	if non_adjacent_sources.size() > 0:
		# Find the nearest node by Y distance (index difference)
		var nearest_source: MapNode = non_adjacent_sources[0]
		var min_distance: int = abs(nearest_source.index - target_node.index)
		
		for source_node: MapNode in non_adjacent_sources:
			var distance: int = abs(source_node.index - target_node.index)
			if distance < min_distance:
				min_distance = distance
				nearest_source = source_node
		
		# Try the nearest source for overlap
		var nearest_pos: Vector2 = current_positions[nearest_source.id]
		var has_overlap: bool = false
		for connection in existing_connections:
			var existing_start: Vector2 = connection.start_pos
			var existing_end: Vector2 = connection.end_pos
			
			if _lines_intersect(nearest_pos, target_pos, existing_start, existing_end):
				has_overlap = true
				break
		
		if not has_overlap:
			return nearest_source
	
	# Final fallback to prevent orphaning - use nearest available
	if adjacent_sources.size() > 0:
		return adjacent_sources[0]
	elif non_adjacent_sources.size() > 0:
		# Return the nearest non-adjacent source
		var nearest_source: MapNode = non_adjacent_sources[0]
		var min_distance: int = abs(nearest_source.index - target_node.index)
		
		for source_node: MapNode in non_adjacent_sources:
			var distance: int = abs(source_node.index - target_node.index)
			if distance < min_distance:
				min_distance = distance
				nearest_source = source_node
		
		return nearest_source
	
	return null

## Add connection to tracking array
func _add_connection_to_tracking(existing_connections: Array, from_id: String, to_id: String, current_positions: Dictionary, next_positions: Dictionary) -> void:
	existing_connections.append({
		"from_id": from_id,
		"to_id": to_id,
		"start_pos": current_positions[from_id],
		"end_pos": next_positions[to_id]
	})

class_name MapGenerationTests
extends RefCounted

## Comprehensive tests for map generation system
## Tests MapGenerator.generate() with various configurations and validates results

static func run_all_tests() -> void:
	Logger.system("=== Starting Map Generation Tests ===")
	
	var tests_passed: int = 0
	var tests_failed: int = 0
	
	# Basic generation tests
	if test_basic_generation():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_deterministic_generation():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_connectivity_validation():
		tests_passed += 1
	else:
		tests_failed += 1
	
	# Configuration tests
	if test_various_configurations():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_layer_structure():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_node_types():
		tests_passed += 1
	else:
		tests_failed += 1
	
	# Edge case tests
	if test_minimum_configuration():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_maximum_configuration():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_edge_cases():
		tests_passed += 1
	else:
		tests_failed += 1
	
	# Stress tests
	if test_stress_generation():
		tests_passed += 1
	else:
		tests_failed += 1
	
	Logger.system("=== Map Generation Tests Complete ===")
	Logger.system("Tests Passed: %d, Tests Failed: %d" % [tests_passed, tests_failed])
	
	if tests_failed > 0:
		Logger.error("Some map generation tests failed!", "MapGenerationTests")
	else:
		Logger.system("All map generation tests passed!")

## Test basic map generation with default parameters
static func test_basic_generation() -> bool:
	Logger.system("Testing basic map generation...")
	
	var map_data: MapData = MapGenerator.generate()
	
	# Validate basic properties
	if not map_data:
		Logger.error("Map generation returned null", "MapGenerationTests")
		return false
	
	if map_data.get_total_nodes() < 5:  # At least start + intermediate + boss
		Logger.error("Map has too few nodes: %d" % map_data.get_total_nodes(), "MapGenerationTests")
		return false
	
	var start_node: MapNode = map_data.get_start_node()
	if not start_node:
		Logger.error("Map has no start node", "MapGenerationTests")
		return false
	
	var boss_nodes: Array[MapNode] = map_data.get_boss_nodes()
	if boss_nodes.is_empty():
		Logger.error("Map has no boss nodes", "MapGenerationTests")
		return false
	
	if not map_data.validate_connectivity():
		Logger.error("Basic map failed connectivity validation", "MapGenerationTests")
		return false
	
	Logger.system("✓ Basic generation test passed")
	return true

## Test deterministic generation with same seed
static func test_deterministic_generation() -> bool:
	Logger.system("Testing deterministic generation...")
	
	var test_seed: int = 12345
	var config: Dictionary = {"seed": test_seed, "intermediate_layers": 2}
	
	var map1: MapData = MapGenerator.generate(config)
	var map2: MapData = MapGenerator.generate(config)
	
	# Maps should be identical with same seed
	if map1.get_total_nodes() != map2.get_total_nodes():
		Logger.error("Maps with same seed have different node counts: %d vs %d" % [map1.get_total_nodes(), map2.get_total_nodes()], "MapGenerationTests")
		return false
	
	if map1.get_layer_count() != map2.get_layer_count():
		Logger.error("Maps with same seed have different layer counts", "MapGenerationTests")
		return false
	
	# Check layer structure consistency
	for layer in range(map1.get_layer_count()):
		var nodes1: Array[MapNode] = map1.get_nodes_in_layer(layer)
		var nodes2: Array[MapNode] = map2.get_nodes_in_layer(layer)
		
		if nodes1.size() != nodes2.size():
			Logger.error("Layer %d has different node counts: %d vs %d" % [layer, nodes1.size(), nodes2.size()], "MapGenerationTests")
			return false
	
	Logger.system("✓ Deterministic generation test passed")
	return true

## Test connectivity validation catches invalid maps
static func test_connectivity_validation() -> bool:
	Logger.system("Testing connectivity validation...")
	
	# Generate multiple maps and ensure all pass validation
	for i in range(10):
		var config: Dictionary = {
			"seed": i * 1000,
			"min_nodes_per_layer": 2,
			"max_nodes_per_layer": 4,
			"intermediate_layers": 3
		}
		
		var map_data: MapData = MapGenerator.generate(config)
		if not map_data.validate_connectivity():
			Logger.error("Map %d failed connectivity validation" % i, "MapGenerationTests")
			return false
		
		# Validate no dead ends (except boss nodes)
		if not _validate_no_dead_ends(map_data):
			Logger.error("Map %d has dead ends" % i, "MapGenerationTests")
			return false
		
		# Validate all nodes reachable from start
		if not _validate_all_reachable_from_start(map_data):
			Logger.error("Map %d has unreachable nodes" % i, "MapGenerationTests")
			return false
	
	Logger.system("✓ Connectivity validation test passed")
	return true

## Test various configuration parameters
static func test_various_configurations() -> bool:
	Logger.system("Testing various configurations...")
	
	var configs: Array[Dictionary] = [
		{"min_nodes_per_layer": 1, "max_nodes_per_layer": 2, "intermediate_layers": 1},
		{"min_nodes_per_layer": 3, "max_nodes_per_layer": 6, "intermediate_layers": 4},
		{"min_nodes_per_layer": 2, "max_nodes_per_layer": 2, "intermediate_layers": 5},  # Fixed size
		{"min_nodes_per_layer": 1, "max_nodes_per_layer": 8, "intermediate_layers": 2}   # High variance
	]
	
	for config in configs:
		var map_data: MapData = MapGenerator.generate(config)
		
		if not map_data:
			Logger.error("Failed to generate map with config: %s" % str(config), "MapGenerationTests")
			return false
		
		var expected_layers: int = config.intermediate_layers + 2  # +start +boss
		if map_data.get_layer_count() != expected_layers:
			Logger.error("Wrong layer count for config %s: expected %d, got %d" % [str(config), expected_layers, map_data.get_layer_count()], "MapGenerationTests")
			return false
		
		# Validate layer node counts are within specified range
		for layer in range(1, map_data.get_layer_count() - 1):  # Skip start and boss layers
			var nodes_in_layer: Array[MapNode] = map_data.get_nodes_in_layer(layer)
			var node_count: int = nodes_in_layer.size()
			
			if node_count < config.min_nodes_per_layer or node_count > config.max_nodes_per_layer:
				Logger.error("Layer %d node count %d outside range [%d, %d]" % [layer, node_count, config.min_nodes_per_layer, config.max_nodes_per_layer], "MapGenerationTests")
				return false
	
	Logger.system("✓ Various configurations test passed")
	return true

## Test layer structure validation
static func test_layer_structure() -> bool:
	Logger.system("Testing layer structure...")
	
	var config: Dictionary = {"intermediate_layers": 3}
	var map_data: MapData = MapGenerator.generate(config)
	
	# Should have exactly 5 layers (start + 3 intermediate + boss)
	if map_data.get_layer_count() != 5:
		Logger.error("Expected 5 layers, got %d" % map_data.get_layer_count(), "MapGenerationTests")
		return false
	
	# Layer 0 should have exactly 1 start node
	var start_layer: Array[MapNode] = map_data.get_nodes_in_layer(0)
	if start_layer.size() != 1 or start_layer[0].node_type != "start":
		Logger.error("Invalid start layer structure", "MapGenerationTests")
		return false
	
	# Last layer should have exactly 1 boss node
	var boss_layer: Array[MapNode] = map_data.get_nodes_in_layer(4)
	if boss_layer.size() != 1 or boss_layer[0].node_type != "boss":
		Logger.error("Invalid boss layer structure", "MapGenerationTests")
		return false
	
	# Intermediate layers should have normal nodes
	for layer in range(1, 4):
		var layer_nodes: Array[MapNode] = map_data.get_nodes_in_layer(layer)
		for node in layer_nodes:
			if node.node_type != "normal":
				Logger.error("Layer %d has non-normal node type: %s" % [layer, node.node_type], "MapGenerationTests")
				return false
	
	Logger.system("✓ Layer structure test passed")
	return true

## Test node types are correctly assigned
static func test_node_types() -> bool:
	Logger.system("Testing node types...")
	
	var map_data: MapData = MapGenerator.generate({"intermediate_layers": 2})
	
	var start_count: int = 0
	var boss_count: int = 0
	var normal_count: int = 0
	
	for node: MapNode in map_data.nodes.values():
		match node.node_type:
			"start":
				start_count += 1
				if node.layer != 0:
					Logger.error("Start node not in layer 0", "MapGenerationTests")
					return false
			"boss":
				boss_count += 1
				if node.layer != map_data.get_layer_count() - 1:
					Logger.error("Boss node not in final layer", "MapGenerationTests")
					return false
			"normal":
				normal_count += 1
				if node.layer == 0 or node.layer == map_data.get_layer_count() - 1:
					Logger.error("Normal node in start or boss layer", "MapGenerationTests")
					return false
	
	if start_count != 1:
		Logger.error("Expected 1 start node, got %d" % start_count, "MapGenerationTests")
		return false
	
	if boss_count != 1:
		Logger.error("Expected 1 boss node, got %d" % boss_count, "MapGenerationTests")
		return false
	
	if normal_count < 2:  # Should have at least some normal nodes
		Logger.error("Expected at least 2 normal nodes, got %d" % normal_count, "MapGenerationTests")
		return false
	
	Logger.system("✓ Node types test passed")
	return true

## Test minimum valid configuration
static func test_minimum_configuration() -> bool:
	Logger.system("Testing minimum configuration...")
	
	var config: Dictionary = {
		"min_nodes_per_layer": 1,
		"max_nodes_per_layer": 1,
		"intermediate_layers": 1
	}
	
	var map_data: MapData = MapGenerator.generate(config)
	
	# Should have exactly 3 nodes (start + 1 intermediate + boss)
	if map_data.get_total_nodes() != 3:
		Logger.error("Minimum config should have 3 nodes, got %d" % map_data.get_total_nodes(), "MapGenerationTests")
		return false
	
	# Should have exactly 3 layers
	if map_data.get_layer_count() != 3:
		Logger.error("Minimum config should have 3 layers, got %d" % map_data.get_layer_count(), "MapGenerationTests")
		return false
	
	if not map_data.validate_connectivity():
		Logger.error("Minimum config failed connectivity validation", "MapGenerationTests")
		return false
	
	Logger.system("✓ Minimum configuration test passed")
	return true

## Test maximum reasonable configuration
static func test_maximum_configuration() -> bool:
	Logger.system("Testing maximum configuration...")
	
	var config: Dictionary = {
		"min_nodes_per_layer": 8,
		"max_nodes_per_layer": 10,
		"intermediate_layers": 6
	}
	
	var map_data: MapData = MapGenerator.generate(config)
	
	# Should have reasonable number of layers and nodes
	if map_data.get_layer_count() != 8:  # 6 intermediate + start + boss
		Logger.error("Maximum config should have 8 layers, got %d" % map_data.get_layer_count(), "MapGenerationTests")
		return false
	
	var total_nodes: int = map_data.get_total_nodes()
	if total_nodes < 50 or total_nodes > 80:  # Reasonable range for max config
		Logger.error("Maximum config node count out of expected range: %d" % total_nodes, "MapGenerationTests")
		return false
	
	if not map_data.validate_connectivity():
		Logger.error("Maximum config failed connectivity validation", "MapGenerationTests")
		return false
	
	Logger.system("✓ Maximum configuration test passed")
	return true

## Test edge cases and error conditions
static func test_edge_cases() -> bool:
	Logger.system("Testing edge cases...")
	
	# Test with zero intermediate layers
	var zero_config: Dictionary = {"intermediate_layers": 0}
	var zero_map: MapData = MapGenerator.generate(zero_config)
	
	if zero_map.get_layer_count() != 2:  # Only start and boss
		Logger.error("Zero intermediate layers should have 2 layers, got %d" % zero_map.get_layer_count(), "MapGenerationTests")
		return false
	
	if zero_map.get_total_nodes() != 2:
		Logger.error("Zero intermediate layers should have 2 nodes, got %d" % zero_map.get_total_nodes(), "MapGenerationTests")
		return false
	
	# Test when min equals max
	var fixed_config: Dictionary = {
		"min_nodes_per_layer": 3,
		"max_nodes_per_layer": 3,
		"intermediate_layers": 2
	}
	var fixed_map: MapData = MapGenerator.generate(fixed_config)
	
	for layer in range(1, fixed_map.get_layer_count() - 1):
		var layer_nodes: Array[MapNode] = fixed_map.get_nodes_in_layer(layer)
		if layer_nodes.size() != 3:
			Logger.error("Fixed size layer %d has %d nodes, expected 3" % [layer, layer_nodes.size()], "MapGenerationTests")
			return false
	
	Logger.system("✓ Edge cases test passed")
	return true

## Stress test: generate many maps to find edge cases
static func test_stress_generation() -> bool:
	Logger.system("Testing stress generation (100 maps)...")
	
	var generation_count: int = 100
	var configs: Array[Dictionary] = [
		{},  # Default config
		{"seed": 0, "intermediate_layers": 1},
		{"seed": 999999, "min_nodes_per_layer": 1, "max_nodes_per_layer": 6},
		{"seed": 42, "intermediate_layers": 5, "min_nodes_per_layer": 2, "max_nodes_per_layer": 4}
	]
	
	for i in range(generation_count):
		var config: Dictionary = configs[i % configs.size()].duplicate()
		if not config.has("seed"):
			config["seed"] = i
		
		var map_data: MapData = MapGenerator.generate(config)
		
		if not map_data:
			Logger.error("Stress test failed: map %d returned null" % i, "MapGenerationTests")
			return false
		
		if not map_data.validate_connectivity():
			Logger.error("Stress test failed: map %d failed connectivity" % i, "MapGenerationTests")
			return false
		
		if map_data.get_total_nodes() < 3:
			Logger.error("Stress test failed: map %d has too few nodes (%d)" % [i, map_data.get_total_nodes()], "MapGenerationTests")
			return false
		
		# Validate performance characteristics
		var start_time: int = Time.get_ticks_msec()
		var validation_result: bool = _validate_all_reachable_from_start(map_data)
		var end_time: int = Time.get_ticks_msec()
		
		if not validation_result:
			Logger.error("Stress test failed: map %d has unreachable nodes" % i, "MapGenerationTests")
			return false
		
		if end_time - start_time > 100:  # Should validate in under 100ms
			Logger.warning("Stress test: map %d validation took %dms" % [i, end_time - start_time], "MapGenerationTests")
	
	Logger.system("✓ Stress generation test passed (%d maps)" % generation_count)
	return true

## Helper: Validate no dead ends (except boss nodes)
static func _validate_no_dead_ends(map_data: MapData) -> bool:
	for node: MapNode in map_data.nodes.values():
		if node.node_type != "boss" and not node.has_outgoing_connections():
			Logger.error("Dead end found at non-boss node: %s" % node.id, "MapGenerationTests")
			return false
	return true

## Helper: Validate all nodes are reachable from start
static func _validate_all_reachable_from_start(map_data: MapData) -> bool:
	var start_node: MapNode = map_data.get_start_node()
	if not start_node:
		return false
	
	var visited: Dictionary = {}
	var queue: Array[String] = [start_node.id]
	visited[start_node.id] = true
	
	# BFS to find all reachable nodes
	while not queue.is_empty():
		var current_id: String = queue.pop_front()
		var current_node: MapNode = map_data.get_node(current_id)
		
		if current_node:
			for connection_id in current_node.outgoing_connections:
				if not visited.has(connection_id):
					visited[connection_id] = true
					queue.append(connection_id)
	
	# Check if all nodes were visited
	for node: MapNode in map_data.nodes.values():
		if not visited.has(node.id):
			Logger.error("Node %s is not reachable from start" % node.id, "MapGenerationTests")
			return false
	
	return true

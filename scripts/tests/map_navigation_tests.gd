class_name MapNavigationTests
extends RefCounted

## Comprehensive tests for map navigation system
## Tests MapNavigation with Slay the Spire rules, voting, and state management

static func run_all_tests() -> void:
	Logger.system("=== Starting Map Navigation Tests ===")
	
	var tests_passed: int = 0
	var tests_failed: int = 0
	
	# Core navigation tests
	if test_basic_navigation():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_movement_validation():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_slay_spire_rules():
		tests_passed += 1
	else:
		tests_failed += 1
	
	# State management tests
	if test_state_persistence():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_progression_unlocking():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_visited_node_tracking():
		tests_passed += 1
	else:
		tests_failed += 1
	
	# Voting system tests
	if test_voting_integration():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_voting_resolution():
		tests_passed += 1
	else:
		tests_failed += 1
	
	# Integration tests
	if test_party_progress_sync():
		tests_passed += 1
	else:
		tests_failed += 1
	
	if test_navigation_completion():
		tests_passed += 1
	else:
		tests_failed += 1
	
	Logger.system("=== Map Navigation Tests Complete ===")
	Logger.system("Tests Passed: %d, Tests Failed: %d" % [tests_passed, tests_failed])
	
	if tests_failed > 0:
		Logger.error("Some map navigation tests failed!", "MapNavigationTests")
	else:
		Logger.system("All map navigation tests passed!")

## Test basic navigation initialization and setup
static func test_basic_navigation() -> bool:
	Logger.system("Testing basic navigation...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Check initial state
	if navigation.current_node_id != "start":
		Logger.error("Navigation not initialized at start node", "MapNavigationTests")
		return false
	
	if navigation.visited_nodes.size() != 0:
		Logger.error("Visited nodes should be empty initially", "MapNavigationTests")
		return false
	
	if navigation.available_nodes.size() < 1:
		Logger.error("Should have at least start node available", "MapNavigationTests")
		return false
	
	if not navigation.can_access_node("start"):
		Logger.error("Should be able to access start node", "MapNavigationTests")
		return false
	
	Logger.system("✓ Basic navigation test passed")
	return true

## Test movement validation rules
static func test_movement_validation() -> bool:
	Logger.system("Testing movement validation...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Test valid move
	if not navigation.is_move_valid("start", "L1_N0"):
		Logger.error("Should allow valid move from start to L1_N0", "MapNavigationTests")
		return false
	
	# Test invalid source
	if navigation.is_move_valid("L1_N0", "L2_N0"):
		Logger.error("Should not allow move from non-current node", "MapNavigationTests")
		return false
	
	# Test disconnected nodes
	if navigation.is_move_valid("start", "L2_N0"):
		Logger.error("Should not allow move to disconnected node", "MapNavigationTests")
		return false
	
	# Test move to unavailable node
	if navigation.is_move_valid("start", "boss"):
		Logger.error("Should not allow move to unavailable node", "MapNavigationTests")
		return false
	
	Logger.system("✓ Movement validation test passed")
	return true

## Test Slay the Spire movement rules enforcement
static func test_slay_spire_rules() -> bool:
	Logger.system("Testing Slay the Spire rules...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Rule 1: Can only move forward (no backtracking)
	var move_success: bool = navigation.move_to_node("L1_N0")
	if not move_success:
		Logger.error("Should be able to move to L1_N0", "MapNavigationTests")
		return false
	
	# Try to move back to start (should fail)
	if navigation.is_move_valid("L1_N0", "start"):
		Logger.error("Should not allow backtracking to start", "MapNavigationTests")
		return false
	
	# Rule 2: Must progress through connected nodes only
	move_success = navigation.move_to_node("L2_N0")
	if not move_success:
		Logger.error("Should be able to move to connected L2_N0", "MapNavigationTests")
		return false
	
	# Rule 3: Cannot skip layers
	if navigation.can_access_node("boss"):
		Logger.error("Should not be able to access boss directly from L2", "MapNavigationTests")
		return false
	
	Logger.system("✓ Slay the Spire rules test passed")
	return true

## Test state persistence and restoration
static func test_state_persistence() -> bool:
	Logger.system("Testing state persistence...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Make some moves
	navigation.move_to_node("L1_N0")
	navigation.move_to_node("L2_N0")
	
	# Get current state
	var state: Dictionary = navigation.get_navigation_state()
	
	# Verify state contents
	if state.current_node != "L2_N0":
		Logger.error("State current_node incorrect: %s" % state.current_node, "MapNavigationTests")
		return false
	
	if state.visited_nodes.size() != 2:  # start and L1_N0
		Logger.error("State visited_nodes incorrect: %d" % state.visited_nodes.size(), "MapNavigationTests")
		return false
	
	if not state.can_progress:
		Logger.error("State should show progression is possible", "MapNavigationTests")
		return false
	
	# Test PartyProgressData sync
	if party_progress.current_map_node != navigation._convert_string_to_int_id("L2_N0"):
		Logger.error("PartyProgressData not synced correctly", "MapNavigationTests")
		return false
	
	Logger.system("✓ State persistence test passed")
	return true

## Test progression unlocking mechanics
static func test_progression_unlocking() -> bool:
	Logger.system("Testing progression unlocking...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Initially should only have start and immediate connections available
	var initial_available: Array[String] = navigation.available_nodes.duplicate()
	
	# Move to L1_N0 and check unlocking
	navigation.move_to_node("L1_N0")
	
	var after_move_available: Array[String] = navigation.available_nodes.duplicate()
	
	# Should have unlocked new nodes
	if after_move_available.size() <= initial_available.size():
		Logger.error("Moving should unlock new nodes", "MapNavigationTests")
		return false
	
	# Should be able to access unlocked nodes
	for node_id in after_move_available:
		if not navigation.can_access_node(node_id):
			Logger.error("Unlocked node should be accessible: %s" % node_id, "MapNavigationTests")
			return false
	
	Logger.system("✓ Progression unlocking test passed")
	return true

## Test visited node tracking
static func test_visited_node_tracking() -> bool:
	Logger.system("Testing visited node tracking...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Initially no nodes should be visited
	if navigation.visited_nodes.size() != 0:
		Logger.error("No nodes should be visited initially", "MapNavigationTests")
		return false
	
	# Move and check tracking
	navigation.move_to_node("L1_N0")
	
	# Start should be marked as visited (but not in visited_nodes per implementation)
	if "start" in navigation.visited_nodes:
		Logger.error("Start node should not be in visited_nodes", "MapNavigationTests")
		return false
	
	navigation.move_to_node("L2_N0")
	
	# L1_N0 should now be visited
	if "L1_N0" not in navigation.visited_nodes:
		Logger.error("L1_N0 should be in visited nodes", "MapNavigationTests")
		return false
	
	# Cannot return to visited nodes
	if navigation.is_move_valid("L2_N0", "L1_N0"):
		Logger.error("Should not allow return to visited node", "MapNavigationTests")
		return false
	
	Logger.system("✓ Visited node tracking test passed")
	return true

## Test voting system integration
static func test_voting_integration() -> bool:
	Logger.system("Testing voting integration...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Start voting
	var decision_index: int = navigation.start_node_voting(30)
	
	if decision_index < 0:
		Logger.error("Failed to start node voting", "MapNavigationTests")
		return false
	
	# Get available moves for voting
	var available_moves: Array[String] = navigation.get_available_moves()
	if available_moves.is_empty():
		Logger.error("No available moves for voting", "MapNavigationTests")
		return false
	
	# Test voting for valid move
	var vote_success: bool = navigation.vote_for_move(decision_index, 1, available_moves[0])
	if not vote_success:
		Logger.error("Failed to vote for valid move", "MapNavigationTests")
		return false
	
	# Test voting for invalid move
	var invalid_vote: bool = navigation.vote_for_move(decision_index, 2, "invalid_node")
	if invalid_vote:
		Logger.error("Should not allow vote for invalid node", "MapNavigationTests")
		return false
	
	Logger.system("✓ Voting integration test passed")
	return true

## Test voting resolution and execution
static func test_voting_resolution() -> bool:
	Logger.system("Testing voting resolution...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Start voting
	var decision_index: int = navigation.start_node_voting(1)  # Short deadline
	var available_moves: Array[String] = navigation.get_available_moves()
	
	# Cast some votes
	navigation.vote_for_move(decision_index, 1, available_moves[0])
	navigation.vote_for_move(decision_index, 2, available_moves[0])
	
	# Wait for voting to complete or force completion
	_wait_for_voting_complete(party_progress, decision_index)
	
	var initial_node: String = navigation.current_node_id
	
	# Resolve voting
	var resolution_success: bool = navigation.resolve_node_voting(decision_index)
	
	if not resolution_success:
		Logger.error("Failed to resolve voting", "MapNavigationTests")
		return false
	
	# Should have moved to voted node
	if navigation.current_node_id == initial_node:
		Logger.error("Navigation did not move after voting resolution", "MapNavigationTests")
		return false
	
	Logger.system("✓ Voting resolution test passed")
	return true

## Test PartyProgressData synchronization
static func test_party_progress_sync() -> bool:
	Logger.system("Testing PartyProgressData sync...")
	
	var test_map: Dictionary = _create_test_map_data()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(test_map, "start")
	
	# Check initial sync
	if party_progress.current_map_node != 0:  # Start node = 0
		Logger.error("Initial PartyProgressData sync failed", "MapNavigationTests")
		return false
	
	# Make a move and check sync
	navigation.move_to_node("L1_N0")
	
	var expected_node_id: int = navigation._convert_string_to_int_id("L1_N0")
	if party_progress.current_map_node != expected_node_id:
		Logger.error("PartyProgressData not synced after move", "MapNavigationTests")
		return false
	
	# Check nodes_completed sync
	if party_progress.nodes_completed.is_empty():
		Logger.error("PartyProgressData nodes_completed not synced", "MapNavigationTests")
		return false
	
	# Check path_taken sync
	if party_progress.path_taken.size() != 2:  # start + L1_N0
		Logger.error("PartyProgressData path_taken not synced correctly", "MapNavigationTests")
		return false
	
	Logger.system("✓ PartyProgressData sync test passed")
	return true

## Test navigation completion detection
static func test_navigation_completion() -> bool:
	Logger.system("Testing navigation completion...")
	
	var simple_map: Dictionary = _create_simple_linear_map()
	var party_progress: PartyProgressData = PartyProgressData.new()
	var navigation: MapNavigation = MapNavigation.new(party_progress)
	
	navigation.initialize_map(simple_map, "start")
	
	# Should not be complete initially
	if navigation.is_map_complete():
		Logger.error("Map should not be complete initially", "MapNavigationTests")
		return false
	
	# Move through the linear path
	navigation.move_to_node("middle")
	
	if navigation.is_map_complete():
		Logger.error("Map should not be complete at middle node", "MapNavigationTests")
		return false
	
	navigation.move_to_node("boss")
	
	# Should be complete at boss node
	if not navigation.is_map_complete():
		Logger.error("Map should be complete at boss node", "MapNavigationTests")
		return false
	
	Logger.system("✓ Navigation completion test passed")
	return true

## Helper: Create test map data structure
static func _create_test_map_data() -> Dictionary:
	return {
		"nodes": {
			"start": {"id": "start", "layer": 0, "type": "start"},
			"L1_N0": {"id": "L1_N0", "layer": 1, "type": "normal"},
			"L1_N1": {"id": "L1_N1", "layer": 1, "type": "normal"},
			"L2_N0": {"id": "L2_N0", "layer": 2, "type": "normal"},
			"L2_N1": {"id": "L2_N1", "layer": 2, "type": "normal"},
			"boss": {"id": "boss", "layer": 3, "type": "boss"}
		},
		"connections": {
			"start": ["L1_N0", "L1_N1"],
			"L1_N0": ["L2_N0", "L2_N1"],
			"L1_N1": ["L2_N0"],
			"L2_N0": ["boss"],
			"L2_N1": ["boss"]
		},
		"final_node": "boss"
	}

## Helper: Create simple linear map for completion testing
static func _create_simple_linear_map() -> Dictionary:
	return {
		"nodes": {
			"start": {"id": "start", "layer": 0, "type": "start"},
			"middle": {"id": "middle", "layer": 1, "type": "normal"},
			"boss": {"id": "boss", "layer": 2, "type": "boss"}
		},
		"connections": {
			"start": ["middle"],
			"middle": ["boss"]
		},
		"final_node": "boss"
	}

## Helper: Wait for voting to complete (simulate time passage)
static func _wait_for_voting_complete(party_progress: PartyProgressData, decision_index: int) -> void:
	# Force completion immediately for testing
	if party_progress.decisions.has(decision_index):
		party_progress.decisions[decision_index].is_complete = true

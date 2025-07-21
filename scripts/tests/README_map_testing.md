# Map Generation and Navigation Testing Suite

## Overview

This document outlines the comprehensive testing approach for the Forked Fates map generation and navigation system. The tests validate both the core functionality and edge cases to ensure robust map generation following Slay the Spire rules.

## Test Files Created

### 1. `map_generation_tests.gd`
**Comprehensive MapGenerator testing**

**Test Coverage:**
- ✅ **Basic Generation**: Validates default map generation produces valid structure
- ✅ **Deterministic Generation**: Same seed produces identical maps
- ✅ **Connectivity Validation**: All nodes properly connected, no dead ends
- ✅ **Various Configurations**: Tests different min/max nodes per layer
- ✅ **Layer Structure**: Validates proper start/intermediate/boss layer setup
- ✅ **Node Types**: Ensures correct node type assignment per layer
- ✅ **Minimum Configuration**: Tests with smallest valid parameters
- ✅ **Maximum Configuration**: Tests with large map parameters
- ✅ **Edge Cases**: Zero intermediate layers, min=max scenarios
- ✅ **Stress Testing**: Generates 100+ maps to find edge cases

**Key Validations:**
- No dead ends (except boss nodes)
- All nodes reachable from start via BFS traversal
- Layer node counts within specified ranges
- Proper node type distribution
- Performance under 100ms for large maps

### 2. `map_navigation_tests.gd` 
**Comprehensive MapNavigation testing**

**Test Coverage:**
- ✅ **Basic Navigation**: Initialization and state setup
- ✅ **Movement Validation**: Core Slay the Spire movement rules
- ✅ **No Backtracking**: Cannot return to visited nodes
- ✅ **Connection Requirements**: Can only move to connected nodes
- ✅ **State Persistence**: Current node, visited nodes, available nodes
- ✅ **Progression Unlocking**: New nodes unlock after completing current
- ✅ **Voting Integration**: Party voting for next node decisions
- ✅ **Voting Resolution**: Execute chosen moves from voting results
- ✅ **PartyProgressData Sync**: Integration with shared party state
- ✅ **Navigation Completion**: Detect when boss node reached

**Slay the Spire Rules Tested:**
1. Forward progression only (no backtracking)
2. Must move through connected nodes
3. Cannot skip layers
4. All nodes in layer must be accessible
5. Party voting for movement decisions

### 3. `map_test_runner.gd` & `temp_map_test.tscn`
**Headless test execution with UI integration**

**Features:**
- Runs all generation and navigation tests
- Integration testing with MapView component
- End-to-end flow validation
- Memory cleanup testing
- Performance validation for large maps
- Headless execution for CI/automation
- Rich text output with pass/fail indicators

**Command to run:**
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/temp_map_test.tscn --headless
```

### 4. `map_standalone_test.gd` 
**Simplified standalone testing**

**Purpose:**
- Tests core map functionality without external dependencies
- Validates map generation and basic navigation
- Stress tests with 100 map generations
- Console output for easy debugging

## Testing Strategy

### 1. **Unit Testing**
- Individual component validation
- MapGenerator.generate() with various configs
- MapNavigation movement rules
- MapData connectivity validation

### 2. **Integration Testing** 
- MapView UI component integration
- PartyProgressData synchronization
- EventBus signal handling
- Full navigation flow from start to boss

### 3. **Stress Testing**
- Generate 100+ maps with random configs
- Performance validation (generation < 1s, validation < 100ms)
- Memory cleanup verification
- Edge case discovery

### 4. **Edge Case Testing**
- Zero intermediate layers (start -> boss)
- Minimum/maximum node configurations
- Single-path linear maps
- Complex multi-branching maps

## Map Generation Validation

### Connectivity Checks
```gdscript
# Validates no dead ends except boss nodes
func validate_no_dead_ends(map_data: MapData) -> bool

# Ensures all nodes reachable from start via BFS
func validate_all_reachable_from_start(map_data: MapData) -> bool
```

### Structure Validation
- **Start Layer**: Exactly 1 start node at layer 0
- **Intermediate Layers**: 2-8 normal nodes per layer (configurable)
- **Boss Layer**: Exactly 1 boss node at final layer
- **Connections**: Every node (except boss) has outgoing connections
- **Incoming**: Every node (except start) has incoming connections

## Navigation Rules Testing

### Slay the Spire Movement Rules
1. **Forward Only**: `navigation.is_move_valid(current, visited_node) == false`
2. **Connected Only**: `navigation.is_move_valid(current, unconnected_node) == false`
3. **Available Only**: `navigation.can_access_node(locked_node) == false`
4. **Layer Progression**: Cannot skip intermediate layers

### State Management
- Current node tracking
- Visited nodes array (excluding start)
- Available nodes array (unlocked but not visited)
- PartyProgressData synchronization

## Performance Benchmarks

### Generation Performance
- **Small Maps** (3-5 layers): < 10ms
- **Medium Maps** (5-8 layers): < 50ms  
- **Large Maps** (8+ layers, 8+ nodes/layer): < 1000ms

### Validation Performance
- **Connectivity Check**: < 50ms for large maps
- **Reachability BFS**: < 100ms for complex maps
- **Navigation State**: < 1ms for any operation

## Error Scenarios Tested

### Generation Failures
- Invalid configuration parameters
- Seed-based regeneration on validation failure
- Memory constraints with very large configs

### Navigation Failures  
- Invalid move attempts
- Voting deadline handling
- State corruption recovery
- PartyProgressData sync issues

## CI/CD Integration

### Headless Testing
```bash
# Run all tests headlessly
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/temp_map_test.tscn --headless

# Expected output: All tests passed, process exits with code 0
```

### Test Results
- Console output with ✓/✗ indicators
- Pass/fail statistics
- Performance timing data
- Memory usage reports

## Future Enhancements

### Additional Test Coverage
- Visual map layout validation
- UI interaction testing
- Multiplayer synchronization
- Save/load state persistence
- A* pathfinding validation

### Performance Optimization
- Map generation caching
- Navigation state pooling  
- Large map memory optimization
- Parallel validation processing

## Dependencies

The comprehensive tests require:
- `MapGenerator` class with `generate()` method
- `MapData`, `MapNode` classes for map structure
- `MapNavigation` class for movement logic
- `PartyProgressData` for shared state
- `Logger` for debug output (optional)

## Cleanup

After testing, temporary files should be removed:
- `scenes/temp_map_test.tscn`
- `scenes/temp_standalone_map_test.tscn`
- Any generated test artifacts

The testing framework follows established patterns in the codebase and provides comprehensive validation of the map system's correctness, performance, and integration with the larger game architecture.

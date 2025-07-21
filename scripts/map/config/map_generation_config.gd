class_name MapGenerationConfig
extends Resource

@export_group("Map Structure")
@export var layer_count: int = 5  # Total layers including start and boss
@export var nodes_per_layer_range: Vector2i = Vector2i(2, 5)  # Min/max nodes per intermediate layer

@export_group("Connections")
@export var min_connections_per_node: int = 1
@export var max_connections_per_node: int = 3
@export var additional_connection_chance: float = 0.3  # Chance for extra connections beyond minimum

@export_group("Node Types")
@export var available_node_types: Array[String] = ["normal"]  # Only sudden_death minigame nodes for now
@export var special_node_weight: float = 0.0  # No special nodes for now - all sudden_death

@export_group("Generation")
@export var seed_value: int = -1  # -1 for random seed
@export var ensure_connectivity: bool = true  # Validate all paths exist
@export var max_generation_attempts: int = 10  # Max retries if validation fails

@export_group("Difficulty Scaling")
@export var scale_by_layer: bool = true
@export var difficulty_curve: Curve  # Optional curve for node difficulty by layer

## Get effective seed (generates random if not set)
func get_effective_seed() -> int:
	if seed_value <= 0:
		return randi()
	return seed_value

## Get intermediate layer count (excludes start and boss layers)
func get_intermediate_layer_count() -> int:
	return max(0, layer_count - 2)

## Get minimum nodes for a layer (handles start/boss special cases)
func get_min_nodes_for_layer(layer_index: int) -> int:
	if layer_index == 0 or layer_index == layer_count - 1:
		return 1  # Start and boss layers always have 1 node
	return nodes_per_layer_range.x

## Get maximum nodes for a layer (handles start/boss special cases)
func get_max_nodes_for_layer(layer_index: int) -> int:
	if layer_index == 0 or layer_index == layer_count - 1:
		return 1  # Start and boss layers always have 1 node
	return nodes_per_layer_range.y

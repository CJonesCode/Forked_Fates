class_name MapNode
extends Resource

@export var id: String
@export var layer: int
@export var index: int
@export var node_type: String
@export var outgoing_connections: Array[String]

func _init(p_id: String = "", p_layer: int = 0, p_index: int = 0, p_node_type: String = "normal") -> void:
	id = p_id
	layer = p_layer
	index = p_index
	node_type = p_node_type
	outgoing_connections = []

func add_connection(target_id: String) -> void:
	if target_id not in outgoing_connections:
		outgoing_connections.append(target_id)

func has_outgoing_connections() -> bool:
	return outgoing_connections.size() > 0

func has_connection(target_id: String) -> bool:
	return target_id in outgoing_connections

func get_connection_count() -> int:
	return outgoing_connections.size()

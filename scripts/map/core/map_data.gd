class_name MapData
extends Resource

@export var nodes: Dictionary = {}

func _init() -> void:
	nodes = {}

func add_node(node: MapNode) -> void:
	nodes[node.id] = node

func get_node(node_id: String) -> MapNode:
	return nodes.get(node_id) as MapNode

func get_nodes_in_layer(layer: int) -> Array[MapNode]:
	var layer_nodes: Array[MapNode] = []
	for node: MapNode in nodes.values():
		if node.layer == layer:
			layer_nodes.append(node)
	return layer_nodes

func get_start_node() -> MapNode:
	for node: MapNode in nodes.values():
		if node.node_type == "start":
			return node
	return null

func get_boss_nodes() -> Array[MapNode]:
	var boss_nodes: Array[MapNode] = []
	for node: MapNode in nodes.values():
		if node.node_type == "boss":
			boss_nodes.append(node)
	return boss_nodes

func validate_connectivity() -> bool:
	var has_incoming: Dictionary = {}
	
	# Track which nodes have incoming connections
	for node: MapNode in nodes.values():
		has_incoming[node.id] = false
	
	# Mark nodes that have incoming connections
	for node: MapNode in nodes.values():
		for connection_id: String in node.outgoing_connections:
			if connection_id in has_incoming:
				has_incoming[connection_id] = true
	
	# Check all nodes except start have incoming, all except boss have outgoing
	for node: MapNode in nodes.values():
		if node.node_type != "start" and not has_incoming[node.id]:
			Logger.system("MapData validation failed: Node %s has no incoming connections" % node.id)
			return false
		
		if node.node_type != "boss" and not node.has_outgoing_connections():
			Logger.system("MapData validation failed: Node %s has no outgoing connections" % node.id)
			return false
	
	return true

func get_total_nodes() -> int:
	return nodes.size()

func get_layer_count() -> int:
	var max_layer: int = 0
	for node: MapNode in nodes.values():
		max_layer = max(max_layer, node.layer)
	return max_layer + 1

extends Node

## Simple demonstration of the new object indicator system
## Shows how to add different types of indicators to any object

var demo_players: Array[BasePlayer] = []
var demo_timer: float = 0.0

func _ready() -> void:
	# Find players in the scene for demonstration
	_find_demo_players()
	
	# Start the demonstration
	_start_demo()

func _process(delta: float) -> void:
	demo_timer += delta
	
	# Cycle through different demonstrations every few seconds
	var cycle_time = fmod(demo_timer, 15.0)  # 15 second cycle
	
	if cycle_time < 3.0:
		_demo_leadership_indicators()
	elif cycle_time < 6.0:
		_demo_team_indicators()
	elif cycle_time < 9.0:
		_demo_buff_debuff_indicators()
	elif cycle_time < 12.0:
		_demo_temporary_indicators()
	else:
		_demo_multiple_indicators()

func _find_demo_players() -> void:
	# Find all BasePlayer nodes in the scene
	_find_players_recursive(get_tree().current_scene)
	
	Logger.debug("Found " + str(demo_players.size()) + " players for object indicator demo", "ObjectIndicatorDemo")

func _find_players_recursive(node: Node) -> void:
	if node is BasePlayer:
		demo_players.append(node as BasePlayer)
	
	for child in node.get_children():
		_find_players_recursive(child)

func _start_demo() -> void:
	if demo_players.is_empty():
		Logger.warning("No players found for object indicator demo", "ObjectIndicatorDemo")
		return
	
	Logger.system("Starting object indicator demonstration", "ObjectIndicatorDemo")

func _demo_leadership_indicators() -> void:
	# Clear all indicators first
	_clear_all_indicators()
	
	# Add leadership indicator to first player
	if demo_players.size() > 0:
		demo_players[0].add_leadership_indicator("👑", Color.GOLD)

func _demo_team_indicators() -> void:
	# Clear all indicators first
	_clear_all_indicators()
	
	# Add team indicators
	for i in range(demo_players.size()):
		var team_color = Color.RED if i % 2 == 0 else Color.BLUE
		demo_players[i].add_team_indicator(team_color)

func _demo_buff_debuff_indicators() -> void:
	# Clear all indicators first
	_clear_all_indicators()
	
	# Add various buff/debuff indicators
	for i in range(demo_players.size()):
		var player = demo_players[i]
		if i % 4 == 0:
			player.add_buff_indicator("speed", "⚡", Color.CYAN)
		elif i % 4 == 1:
			player.add_buff_indicator("strength", "💪", Color.ORANGE)
		elif i % 4 == 2:
			player.add_debuff_indicator("poison", "☠️", Color.GREEN)
		else:
			player.add_debuff_indicator("slow", "🐌", Color.PURPLE)

func _demo_temporary_indicators() -> void:
	# Clear all indicators first
	_clear_all_indicators()
	
	# Add temporary indicators that will auto-remove
	for i in range(demo_players.size()):
		var player = demo_players[i]
		player.add_temporary_indicator("temp_" + str(i), "✨", Color.YELLOW, 2.0)

func _demo_multiple_indicators() -> void:
	# Clear all indicators first
	_clear_all_indicators()
	
	# Add multiple indicators to show priority ordering
	if demo_players.size() > 0:
		var player = demo_players[0]
		
		# High priority leadership
		player.add_leadership_indicator("👑", Color.GOLD)
		
		# Medium priority team
		player.add_team_indicator(Color.RED)
		
		# Lower priority buff
		player.add_buff_indicator("shield", "🛡️", Color.BLUE)
		
		# Add custom indicator with specific priority
		var custom_data := ObjectIndicatorData.create_text("🎯", Color.WHITE, 16)
		custom_data.priority = 85  # Between team and buff
		custom_data.tooltip = "Custom Priority Indicator"
		player.add_indicator("custom", custom_data)

func _demo_object_indicators() -> void:
	"""Demonstrate indicators on non-player objects"""
	
	# Find some other objects in the scene to demonstrate on
	var other_objects = _find_demo_objects()
	
	for obj in other_objects:
		# Create indicator manager for this object
		var indicator_manager = ObjectIndicatorManager.new()
		indicator_manager.attach_to_object(obj)
		
		# Add a simple indicator
		var demo_data := ObjectIndicatorData.create_text("🔥", Color.RED, 14)
		demo_data.tooltip = "Demo Object Indicator"
		indicator_manager.add_indicator("demo", demo_data)

func _find_demo_objects() -> Array[Node]:
	# Find non-player objects that could have indicators
	var objects: Array[Node] = []
	
	# You could add logic here to find items, weapons, or other objects
	# For now, return empty array
	
	return objects

func _clear_all_indicators() -> void:
	# Clear indicators from all demo players
	for player in demo_players:
		if player and is_instance_valid(player):
			await player.clear_indicators(false)  # No animation for demo speed 
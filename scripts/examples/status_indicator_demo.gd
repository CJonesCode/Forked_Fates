extends Node

## Simple demonstration of the new status indicator system
## Shows how to add different types of indicators to players

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
	
	Logger.debug("Found " + str(demo_players.size()) + " players for status indicator demo", "StatusIndicatorDemo")

func _find_players_recursive(node: Node) -> void:
	if node is BasePlayer:
		demo_players.append(node as BasePlayer)
	
	for child in node.get_children():
		_find_players_recursive(child)

func _start_demo() -> void:
	if demo_players.is_empty():
		Logger.warning("No players found for status indicator demo", "StatusIndicatorDemo")
		return
	
	Logger.system("Starting status indicator demonstration", "StatusIndicatorDemo")

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
	
	# Add various buffs and debuffs
	for i in range(demo_players.size()):
		var player = demo_players[i]
		
		match i % 4:
			0:
				player.add_buff_indicator("speed", "⚡", Color.CYAN)
			1:
				player.add_debuff_indicator("poison", "☠️", Color.GREEN)
			2:
				player.add_buff_indicator("strength", "💪", Color.ORANGE)
			3:
				player.add_debuff_indicator("slow", "🐌", Color.PURPLE)

func _demo_temporary_indicators() -> void:
	# Clear all indicators first
	_clear_all_indicators()
	
	# Add temporary indicators that auto-remove
	for i in range(demo_players.size()):
		var player = demo_players[i]
		player.add_temporary_indicator("demo_temp_" + str(i), "+100", Color.YELLOW, 2.0)

func _demo_multiple_indicators() -> void:
	# Clear all indicators first
	_clear_all_indicators()
	
	# Show multiple indicators on the same player
	if demo_players.size() > 0:
		var player = demo_players[0]
		
		# Add leadership
		player.add_leadership_indicator("👑", Color.GOLD)
		
		# Add team indicator
		player.add_team_indicator(Color.RED)
		
		# Add buff
		player.add_buff_indicator("shield", "🛡️", Color.BLUE)
		
		# Add custom indicator
		var custom_data = StatusIndicatorData.create_text("🎯", Color.CYAN, 16)
		custom_data.tooltip = "Objective Target"
		custom_data.priority = 95
		player.add_status_indicator("objective", custom_data)

func _clear_all_indicators() -> void:
	for player in demo_players:
		await player.clear_status_indicators(false)  # No animation for quick clearing

func _on_demo_complete() -> void:
	Logger.system("Status indicator demonstration complete", "StatusIndicatorDemo") 
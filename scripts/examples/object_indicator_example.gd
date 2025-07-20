class_name ObjectIndicatorExample
extends Node

## Example demonstrating how to use the object indicator system
## Shows various ways minigames and items can add indicators to any object

func example_usage():
	# Get a player reference (this would be your actual player)
	var player: BasePlayer = get_some_player()
	if not player:
		return
	
	# Example 1: Add a leadership indicator (crown)
	player.add_leadership_indicator("👑", Color.GOLD)
	
	# Example 2: Add team indicators
	player.add_team_indicator(Color.RED)  # Red team
	
	# Example 3: Add buff indicators
	player.add_buff_indicator("speed", "⚡", Color.CYAN)  # Speed boost
	player.add_buff_indicator("strength", "💪", Color.ORANGE)  # Strength boost
	
	# Example 4: Add debuff indicators
	player.add_debuff_indicator("poison", "☠️", Color.GREEN)  # Poisoned
	player.add_debuff_indicator("slow", "🐌", Color.PURPLE)  # Slowed
	
	# Example 5: Add temporary indicators that auto-remove
	player.add_temporary_indicator("damage_taken", "+50", Color.RED, 2.0)  # Damage number
	player.add_temporary_indicator("pickup", "Item!", Color.YELLOW, 1.5)  # Item pickup
	
	# Example 5b: Add permanent indicators (infinite duration)
	var permanent_data := ObjectIndicatorData.create_permanent_indicator("VIP", Color.PURPLE, 14)
	permanent_data.tooltip = "VIP Player - Never expires (auto_remove_after = -1.0)"
	player.add_indicator("vip_status", permanent_data)
	
	# Example 5c: Add immediate removal indicator (for flash effects)
	var immediate_data := ObjectIndicatorData.create_immediate_indicator("FLASH", Color.WHITE, 12)
	player.add_indicator("flash_effect", immediate_data)
	
	# Example 6: Custom indicators using ObjectIndicatorData
	var custom_data := ObjectIndicatorData.create_text("🎯", Color.CYAN, 18)
	custom_data.tooltip = "Objective Target"
	custom_data.priority = 95
	custom_data.pulse_on_update = true
	player.add_indicator("objective_target", custom_data)

func example_minigame_usage():
	"""Example of how minigames might use object indicators"""
	var all_players = get_all_players()
	
	# Crown the leader
	var leader = get_current_leader()
	if leader:
		leader.add_leadership_indicator("👑", Color.GOLD)
	
	# Add team indicators to all players
	for i in range(all_players.size()):
		var player = all_players[i]
		var team_color = Color.RED if i % 2 == 0 else Color.BLUE
		player.add_team_indicator(team_color)
	
	# Add objective indicator to target player
	var target_player = all_players[0]  # First player as example
	target_player.add_indicator("capture_target", 
		ObjectIndicatorData.create_objective_indicator("🎯", Color.ORANGE))

func example_item_usage():
	"""Example of how items might add indicators to objects"""
	var player: BasePlayer = get_some_player()
	if not player:
		return
	
	# When player picks up a power-up
	player.add_buff_indicator("invincible", "⭐", Color.GOLD)
	
	# When player gets a weapon upgrade
	var weapon_data := ObjectIndicatorData.create_text("🔥", Color.RED, 16)
	weapon_data.tooltip = "Fire Weapon Active"
	weapon_data.auto_remove_after = 10.0  # Remove after 10 seconds
	player.add_indicator("fire_weapon", weapon_data)
	
	# When player takes damage
	player.add_temporary_indicator("damage_" + str(Time.get_ticks_msec()), 
		"-25", Color.RED, 1.0)

func example_dynamic_updates():
	"""Example of updating indicators dynamically"""
	var player: BasePlayer = get_some_player()
	if not player:
		return
	
	# Add a health indicator
	var health_data := ObjectIndicatorData.create_text("100", Color.GREEN, 14)
	health_data.category = ObjectIndicatorManager.IndicatorCategory.CUSTOM
	player.add_indicator("health_display", health_data)
	
	# Update the health indicator when health changes
	var new_health := 75
	var updated_health_data := ObjectIndicatorData.create_text(str(new_health), 
		Color.YELLOW if new_health > 50 else Color.RED, 14)
	player.update_indicator("health_display", updated_health_data)

func example_cleanup():
	"""Example of cleaning up indicators"""
	var player: BasePlayer = get_some_player()
	if not player:
		return
	
	# Remove specific indicators
	await player.remove_leadership_indicator()
	await player.remove_indicator("buff_speed")
	
	# Clear all indicators
	await player.clear_indicators()

func example_object_indicators():
	"""Example of using indicators on non-player objects"""
	
	# Get any object in the scene - could be an item, weapon, or other game object
	var item_object = get_some_item()
	if item_object:
		# Create an indicator manager for this object
		var indicator_manager = ObjectIndicatorManager.new()
		indicator_manager.attach_to_object(item_object)
		
		# Add indicators to the item
		var pickup_data := ObjectIndicatorData.create_text("📦", Color.YELLOW, 16)
		pickup_data.tooltip = "Pickup Available"
		indicator_manager.add_indicator("pickup_hint", pickup_data)
		
		# Add temporary flash effect
		var flash_data := ObjectIndicatorData.create_temporary_indicator("✨", Color.WHITE, 2.0)
		indicator_manager.add_indicator("flash", flash_data)
	
	# Example with a weapon
	var weapon_object = get_some_weapon()
	if weapon_object:
		var weapon_indicators = ObjectIndicatorManager.new()
		weapon_indicators.attach_to_object(weapon_object)
		
		# Show weapon quality
		var quality_data := ObjectIndicatorData.create_text("⭐⭐⭐", Color.GOLD, 12)
		quality_data.tooltip = "Legendary Weapon"
		weapon_indicators.add_indicator("quality", quality_data)

# Helper functions (these would be implemented in your actual code)
func get_some_player() -> BasePlayer:
	# Return an actual player reference
	return null

func get_all_players() -> Array[BasePlayer]:
	# Return array of all players
	return []

func get_current_leader() -> BasePlayer:
	# Return the player currently in the lead
	return null

func get_some_item() -> Node:
	# Return any item object in the scene
	return null

func get_some_weapon() -> Node:
	# Return any weapon object in the scene
	return null 
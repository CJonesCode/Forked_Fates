class_name StatusIndicatorExample
extends Node

## Example demonstrating how to use the status indicator system
## Shows various ways minigames and items can add status indicators to players

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
	var permanent_data := StatusIndicatorData.create_permanent_indicator("VIP", Color.PURPLE, 14)
	permanent_data.tooltip = "VIP Player - Never expires (auto_remove_after = -1.0)"
	player.add_status_indicator("vip_status", permanent_data)
	
	# Example 5c: Add immediate removal indicator (for flash effects)
	var immediate_data := StatusIndicatorData.create_immediate_indicator("FLASH", Color.WHITE, 12)
	player.add_status_indicator("flash_effect", immediate_data)
	
	# Example 6: Custom indicators using StatusIndicatorData
	var custom_data := StatusIndicatorData.create_text("🎯", Color.CYAN, 18)
	custom_data.tooltip = "Objective Target"
	custom_data.priority = 95
	custom_data.pulse_on_update = true
	player.add_status_indicator("objective_target", custom_data)
	
	# Example 7: Sprite-based indicator (if you have a texture)
	# var sprite_data := StatusIndicatorData.create_sprite(some_texture, Vector2(32, 32))
	# player.add_status_indicator("special_item", sprite_data)
	
	# Example 8: Shape-based indicator
	var shape_data := StatusIndicatorData.create_shape(Color.BLUE, Vector2(20, 20))
	shape_data.tooltip = "Shield Active"
	player.add_status_indicator("shield", shape_data)

func example_minigame_usage():
	"""Example of how a minigame might use status indicators"""
	var players: Array[BasePlayer] = get_all_players()
	
	# No need to clear indicators - fresh BasePlayer instances are created each minigame!
	
	# Add team indicators
	for i in range(players.size()):
		var team_color := Color.RED if i % 2 == 0 else Color.BLUE
		players[i].add_team_indicator(team_color)
	
	# Award leadership directly using minigame methods (no more LeadManager!)
	var leader_player := get_current_leader()
	if leader_player:
		# Simple: minigame.award_leadership(player)
		# Or with custom style: minigame.award_leadership(player, "🏆", Color.ORANGE)
		pass  # Would be called from within the minigame itself
	
	# Add objective indicators to players carrying special items
	for player in players:
		if player_has_special_item(player):
			player.add_status_indicator("carrying_objective", 
				StatusIndicatorData.create_objective_indicator("📦", Color.ORANGE))

func example_item_usage():
	"""Example of how items might add status indicators"""
	var player: BasePlayer = get_some_player()
	if not player:
		return
	
	# When player picks up a power-up
	player.add_buff_indicator("invincible", "⭐", Color.GOLD)
	
	# When player gets a weapon upgrade
	var weapon_data := StatusIndicatorData.create_text("🔥", Color.RED, 16)
	weapon_data.tooltip = "Fire Weapon Active"
	weapon_data.auto_remove_after = 10.0  # Remove after 10 seconds
	player.add_status_indicator("fire_weapon", weapon_data)
	
	# When player takes damage
	player.add_temporary_indicator("damage_" + str(Time.get_ticks_msec()), 
		"-25", Color.RED, 1.0)

func example_dynamic_updates():
	"""Example of updating indicators dynamically"""
	var player: BasePlayer = get_some_player()
	if not player:
		return
	
	# Add a health indicator
	var health_data := StatusIndicatorData.create_text("100", Color.GREEN, 14)
	health_data.category = StatusIndicatorManager.IndicatorCategory.CUSTOM
	player.add_status_indicator("health_display", health_data)
	
	# Update the health indicator when health changes
	var new_health := 75
	var updated_health_data := StatusIndicatorData.create_text(str(new_health), 
		Color.YELLOW if new_health > 50 else Color.RED, 14)
	player.update_status_indicator("health_display", updated_health_data)

func example_cleanup():
	"""Example of cleaning up indicators"""
	var player: BasePlayer = get_some_player()
	if not player:
		return
	
	# Remove specific indicators
	await player.remove_leadership_indicator()
	await player.remove_status_indicator("buff_speed")
	
	# Clear all indicators
	await player.clear_status_indicators()

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

func player_has_special_item(player: BasePlayer) -> bool:
	# Check if player has a special item
	return false 

func example_leadership_tracking():
	"""Example of how a minigame handles leadership tracking directly"""
	# This would be inside a minigame class:
	
	# Award leadership to best player
	# award_leadership(best_player, "👑", Color.GOLD)
	
	# Remove leadership 
	# remove_leadership()
	
	# Check current leader
	# var leader = get_current_leader()
	# if has_leadership(some_player):
	
	# Update leadership based on game state (automatic in PhysicsMinigame)
	# update_leadership_tracking()
	pass 
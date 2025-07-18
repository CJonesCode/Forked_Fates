class_name HealthComponent
extends BaseComponent

## Health management component
## Handles health, damage, death, and respawn logic

# Health state with typed signals
signal health_changed(new_health: int, max_health: int)
signal damage_taken(amount: int, source: Node)
signal died()
signal respawned()

# Health properties
@export var max_health: int = 3
var current_health: int : set = _set_current_health

func _initialize_component() -> void:
	# Initialize health from export value (set per minigame or player config)
	current_health = max_health
	
	# Sync with player data
	if player.player_data:
		player.player_data.max_health = max_health
		player.player_data.current_health = current_health

func _set_current_health(value: int) -> void:
	var old_health: int = current_health
	current_health = clampi(value, 0, max_health)
	
	if current_health != old_health:
		health_changed.emit(current_health, max_health)
		
		# Sync with player data
		if player.player_data:
			player.player_data.current_health = current_health
		
		if current_health <= 0 and old_health > 0:
			_handle_death()

## Set health directly (called by minigame systems)
func set_health(new_health: int) -> void:
	current_health = new_health
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "health set to: " + str(current_health), "HealthComponent")

## Take damage from a source
func take_damage(damage: int, source: Node = null) -> void:
	if current_health <= 0:
		return
		
	var old_health: int = current_health
	current_health = max(0, current_health - damage)
	
	damage_taken.emit(damage, source)
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.combat(player_name + " took " + str(damage) + " damage from " + str(source), "HealthComponent")
	
	if current_health <= 0 and old_health > 0:
		_handle_death()

## Heal the player
func heal(amount: int) -> void:
	if current_health <= 0:
		return
		
	current_health = min(max_health, current_health + amount)
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "healed for " + str(amount) + ", health now: " + str(current_health), "HealthComponent")

## Handle death logic
func _handle_death() -> void:
	died.emit()
	
	# Also emit to EventBus so respawn system can track it
	if player and player.player_data:
		EventBus.emit_player_died(player.player_data.player_id)
	
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "died", "HealthComponent")

## Handle respawn logic
func respawn() -> void:
	current_health = max_health
	respawned.emit()
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "respawned with full health", "HealthComponent")

## Get current health percentage
func get_health_percentage() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

## Check if player is alive
func is_alive() -> bool:
	return current_health > 0

## Check if player is at full health
func is_at_full_health() -> bool:
	return current_health >= max_health 
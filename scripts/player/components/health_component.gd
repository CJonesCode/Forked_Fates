class_name HealthComponent
extends BaseComponent

## Health management component
## Handles health, damage, death, and respawn logic

# Health state with typed signals
signal health_changed(new_health: int, max_health: int)
signal damage_taken(amount: int, source: Node)
signal died()
signal died_by(killer_id: int, source_name: String)  # Updated: source_name instead of weapon_name
signal respawned()

# Health properties
@export var max_health: int = 3
var current_health: int : set = _set_current_health

# Last damage tracking for kill attribution
var last_damage_source: Node = null
var last_attacker_id: int = -1
var last_source_name: String = ""  # Updated: source_name instead of weapon_name

# Death processing flag to prevent multiple death handling
var is_dead: bool = false

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
		
		# Only handle death once - prevent multiple death processing
		if current_health <= 0 and old_health > 0 and not is_dead:
			Logger.debug("💀 Triggering death handler (first time only)", "HealthComponent")
			is_dead = true  # Set flag immediately to prevent re-entry
			_handle_death()
		elif current_health <= 0 and is_dead:
			Logger.debug("💀 Death handler already called - ignoring additional health reduction", "HealthComponent")

## Set health directly (called by minigame systems)
func set_health(new_health: int) -> void:
	current_health = new_health
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "health set to: " + str(current_health), "HealthComponent")

## UNIFIED: Take damage from any source with optional attribution
## Always tracks attribution properly with sensible defaults for environmental damage
func take_damage(damage: int, source: Node = null, attacker_id: int = -1, source_name: String = "Environmental") -> void:
	if damage <= 0:
		return
	
	if current_health <= 0:
		Logger.debug("💔 Damage ignored - player already dead (health: " + str(current_health) + ", is_dead: " + str(is_dead) + ")", "HealthComponent")
		return
	
	# Store kill tracking info BEFORE applying damage
	last_damage_source = source
	last_attacker_id = attacker_id
	last_source_name = source_name
	
	var player_display: String = ""
	if player and player.player_data:
		player_display = player.player_data.player_name + " (Player " + str(player.player_data.player_id) + ")"
	else:
		player_display = "Unknown Player"
	
	var attacker_display: String = ""
	if attacker_id >= 0:
		var attacker_data: PlayerData = GameManager.get_player_data(attacker_id)
		if attacker_data:
			attacker_display = attacker_data.player_name + " (Player " + str(attacker_id) + ")"
		else:
			attacker_display = "Player (Player " + str(attacker_id) + ")"
	else:
		attacker_display = "Environment"
	
	Logger.debug("💔 Stored kill tracking info: attacker_id=" + str(attacker_id) + " source=" + source_name, "HealthComponent")
	Logger.combat("💔 DAMAGE RECEIVED: " + player_display + " taking " + str(damage) + " damage from " + attacker_display + " with " + source_name, "HealthComponent")
	
	var old_health: int = current_health
	current_health = max(0, current_health - damage)
	
	Logger.debug("💔 Health change: " + str(old_health) + " -> " + str(current_health) + " (is_dead: " + str(is_dead) + ")", "HealthComponent")
	
	damage_taken.emit(damage, source)
	
	Logger.combat("💔 " + player_display + " took " + str(damage) + " damage from " + attacker_display + " with " + source_name, "HealthComponent")
	
	# Check if this damage will cause death
	if current_health <= 0 and old_health > 0:
		Logger.combat("💀 FATAL DAMAGE: " + player_display + " killed by damage from " + attacker_display, "HealthComponent")
		# Death will be handled by _set_current_health -> _handle_death

## Track damage source for kill attribution (legacy support)
func _track_damage_source(source: Node) -> void:
	last_damage_source = source
	
	# Try to extract player info from source
	if source and source.has_method("get_owner_id"):
		last_attacker_id = source.get_owner_id()
	elif source and source.has_method("get_shooter_id"):
		last_attacker_id = source.get_shooter_id()
	elif source and source.has_method("get_holder_id"):
		last_attacker_id = source.get_holder_id()
	else:
		last_attacker_id = -1  # Environment damage
	
	# Try to extract source name
	if source and source.has_method("get_weapon_name"):
		last_source_name = source.get_weapon_name()
	elif source and source.has_method("get_item_name"):
		last_source_name = source.get_item_name()
	elif source and source.has_property("item_name"):
		last_source_name = source.item_name
	else:
		last_source_name = "Environmental"

## Heal the player
func heal(amount: int) -> void:
	if current_health <= 0:
		return
		
	current_health = min(max_health, current_health + amount)
	var player_name: String = player.player_data.player_name if player.player_data else "Unknown Player"
	Logger.player(player_name, "healed for " + str(amount) + ", health now: " + str(current_health), "HealthComponent")

## Handle death logic with killer tracking
func _handle_death() -> void:
	var player_display: String = ""
	if player and player.player_data:
		player_display = player.player_data.player_name + " (Player " + str(player.player_data.player_id) + ")"
	else:
		player_display = "Unknown Player"
	
	Logger.combat("💀 PLAYER DEATH: " + player_display + " has died", "HealthComponent")
	Logger.debug("💀 Death attribution: attacker_id=" + str(last_attacker_id) + " source=" + last_source_name, "HealthComponent")
	
	died.emit()
	
	# Emit death with killer info for kill tracking
	died_by.emit(last_attacker_id, last_source_name)
	Logger.debug("💀 Emitted died_by signal: attacker=" + str(last_attacker_id) + " source=" + last_source_name, "HealthComponent")
	
	# Also emit to EventBus for compatibility and respawn system
	if player and player.player_data:
		Logger.debug("💀 Emitting to EventBus: player_died for " + player_display, "HealthComponent")
		EventBus.emit_player_died(player.player_data.player_id)
		
		# Emit kill event with attacker info (kill feed will look up item icon)
		var attacker_display: String = ""
		if last_attacker_id >= 0:
			var attacker_data: PlayerData = GameManager.get_player_data(last_attacker_id)
			if attacker_data:
				attacker_display = attacker_data.player_name + " (Player " + str(last_attacker_id) + ")"
			else:
				attacker_display = "Player (Player " + str(last_attacker_id) + ")"
		else:
			attacker_display = "Environment"
		
		Logger.combat("💀 ✅ KILL ATTRIBUTION: " + player_display + " killed by " + attacker_display + " with " + last_source_name, "HealthComponent")
		EventBus.emit_player_killed_by(player.player_data.player_id, last_attacker_id, last_source_name)
		Logger.debug("💀 Emitted player_killed_by to EventBus", "HealthComponent")
	
	if last_attacker_id >= 0:
		var attacker_data: PlayerData = GameManager.get_player_data(last_attacker_id)
		var attacker_display: String = ""
		if attacker_data:
			attacker_display = attacker_data.player_name + " (Player " + str(last_attacker_id) + ")"
		else:
			attacker_display = "Player (Player " + str(last_attacker_id) + ")"
		Logger.combat("💀 " + player_display + " was killed by " + attacker_display + " with " + last_source_name, "HealthComponent")
	else:
		Logger.combat("💀 " + player_display + " died from " + last_source_name + " (environmental)", "HealthComponent")

## Handle respawn logic
func respawn() -> void:
	current_health = max_health
	is_dead = false  # Reset death flag for future deaths
	
	# Clear damage tracking on respawn
	last_damage_source = null
	last_attacker_id = -1
	last_source_name = ""
	
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
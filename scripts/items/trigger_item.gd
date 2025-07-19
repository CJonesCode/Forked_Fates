class_name TriggerItem
extends BaseItem

## Trigger items for environmental effects and area-based interactions
## Used for speed boosts, hazards, checkpoints, and other collision-triggered effects

# Trigger properties
@export var trigger_type: String = "speed_boost"  # "speed_boost", "hazard", "checkpoint", "bounce_pad"
@export var effect_strength: float = 1.0
@export var trigger_duration: float = 0.0  # 0 = instant, >0 = effect over time
@export var cooldown_time: float = 0.0  # Time before trigger can activate again
@export var max_uses: int = -1  # -1 = unlimited uses
@export var affected_teams: Array[String] = []  # Empty = affects all players

# State
var uses_remaining: int = -1
var last_trigger_time: float = 0.0
var players_in_area: Array[BasePlayer] = []

signal player_entered_trigger(player: BasePlayer, trigger_type: String)
signal player_exited_trigger(player: BasePlayer, trigger_type: String)
signal trigger_activated(player: BasePlayer, effect: String)
signal trigger_depleted()

func _ready() -> void:
	super()
	
	# Set up trigger-specific properties
	item_description = "An environmental trigger that affects players"
	can_be_picked_up = false  # Triggers can't be picked up
	can_be_dropped = false
	
	# Initialize uses
	if max_uses > 0:
		uses_remaining = max_uses
	
	# Set up pickup area for trigger detection
	if pickup_area:
		# Use the pickup area as the trigger area
		pickup_area.monitoring = true
		# Ensure we're using the right collision layers for triggers
		CollisionLayers.setup_pickup_area(pickup_area)
	
	Logger.item("TriggerItem " + item_name + " (" + trigger_type + ") ready", "TriggerItem")

## Override pickup to prevent normal pickup behavior
func pickup(player: BasePlayer) -> bool:
	# Triggers can't be picked up normally
	return false

## Handle player entering trigger area
func _on_pickup_area_entered(body: Node2D) -> void:
	if not body is BasePlayer:
		return
	
	var player: BasePlayer = body as BasePlayer
	
	# Check team restrictions
	if not _can_affect_player(player):
		return
	
	players_in_area.append(player)
	player_entered_trigger.emit(player, trigger_type)
	
	# Apply instant trigger effects
	_activate_trigger(player)
	
	Logger.debug(player.player_data.player_name + " entered " + trigger_type + " trigger", "TriggerItem")

## Handle player exiting trigger area
func _on_pickup_area_exited(body: Node2D) -> void:
	if not body is BasePlayer:
		return
	
	var player: BasePlayer = body as BasePlayer
	
	if player in players_in_area:
		players_in_area.erase(player)
		player_exited_trigger.emit(player, trigger_type)
		
		# End continuous effects
		_deactivate_trigger(player)
		
		Logger.debug(player.player_data.player_name + " exited " + trigger_type + " trigger", "TriggerItem")

## Check if this trigger can affect the given player
func _can_affect_player(player: BasePlayer) -> bool:
	# Check cooldown
	var current_time = Time.get_unix_time_from_system()
	if cooldown_time > 0 and (current_time - last_trigger_time) < cooldown_time:
		return false
	
	# Check uses remaining
	if max_uses > 0 and uses_remaining <= 0:
		return false
	
	# Check team restrictions
	if affected_teams.size() > 0:
		var player_team = player.player_data.team_id if player.player_data else "default"
		if str(player_team) not in affected_teams:
			return false
	
	return true

## Activate trigger effect on player
func _activate_trigger(player: BasePlayer) -> void:
	if not _can_affect_player(player):
		return
	
	# Update usage tracking
	last_trigger_time = Time.get_unix_time_from_system()
	if max_uses > 0:
		uses_remaining -= 1
		if uses_remaining <= 0:
			trigger_depleted.emit()
	
	# Apply effects based on trigger type
	match trigger_type:
		"speed_boost":
			_apply_speed_boost(player)
		"hazard":
			_apply_hazard_damage(player)
		"checkpoint":
			_activate_checkpoint(player)
		"bounce_pad":
			_apply_bounce_effect(player)
		"healing_zone":
			_apply_healing(player)
		_:
			Logger.warning("Unknown trigger type: " + trigger_type, "TriggerItem")
			return
	
	trigger_activated.emit(player, trigger_type)
	Logger.item(player.player_data.player_name + " activated " + trigger_type + " trigger", "TriggerItem")

## Deactivate continuous trigger effects
func _deactivate_trigger(player: BasePlayer) -> void:
	match trigger_type:
		"speed_boost":
			_remove_speed_boost(player)
		"healing_zone":
			_stop_healing(player)
		# Other continuous effects...

## Apply speed boost effect
func _apply_speed_boost(player: BasePlayer) -> void:
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	if movement_component:
		movement_component.apply_speed_modifier(1.0 + effect_strength)
		Logger.debug("Speed boost applied: " + str(effect_strength), "TriggerItem")

## Remove speed boost effect
func _remove_speed_boost(player: BasePlayer) -> void:
	var movement_component: MovementComponent = player.get_component(MovementComponent)
	if movement_component:
		movement_component.remove_speed_modifier()

## Apply hazard damage
func _apply_hazard_damage(player: BasePlayer) -> void:
	var damage_amount = int(effect_strength)
	EventBus.report_player_damage(
		player.player_data.player_id,
		-1,  # No specific attacker (environmental)
		damage_amount,
		"Environmental Hazard"
	)

## Activate checkpoint
func _activate_checkpoint(player: BasePlayer) -> void:
	# This would integrate with a checkpoint system
	Logger.item("Checkpoint activated by " + player.player_data.player_name, "TriggerItem")

## Apply bounce effect
func _apply_bounce_effect(player: BasePlayer) -> void:
	var bounce_force = effect_strength * 400.0  # Scale effect strength
	var bounce_direction = Vector2.UP  # Default upward bounce
	
	# Apply force to player
	player.velocity += bounce_direction * bounce_force
	Logger.debug("Bounce applied with force: " + str(bounce_force), "TriggerItem")

## Apply healing effect
func _apply_healing(player: BasePlayer) -> void:
	var health_component: HealthComponent = player.get_component(HealthComponent)
	if health_component:
		var heal_amount = int(effect_strength)
		health_component.heal(heal_amount)

## Stop continuous healing
func _stop_healing(player: BasePlayer) -> void:
	# Would stop any ongoing healing timer
	pass

## Get trigger status for debugging/UI
func get_trigger_info() -> Dictionary:
	return {
		"trigger_type": trigger_type,
		"effect_strength": effect_strength,
		"uses_remaining": uses_remaining,
		"players_in_area": players_in_area.size(),
		"last_trigger": last_trigger_time
	} 
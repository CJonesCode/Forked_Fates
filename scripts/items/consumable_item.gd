class_name ConsumableItem
extends BaseItem

## Consumable items for health, powerups, and temporary effects
## Automatically consumed on pickup or use for Mario Party-style gameplay

# Consumable properties
@export var heal_amount: int = 0
@export var speed_boost_duration: float = 0.0
@export var damage_boost_duration: float = 0.0
@export var auto_consume_on_pickup: bool = true
@export var effect_description: String = ""

# Effects
var effect_timer: float = 0.0
var effect_target: BasePlayer = null

signal effect_applied(player: BasePlayer, effect_type: String)
signal effect_expired(player: BasePlayer, effect_type: String)

func _ready() -> void:
	super()
	
	# Set default properties for consumables
	item_description = "A consumable item that provides temporary effects"
	can_be_dropped = false  # Consumables typically can't be dropped
	
	Logger.item("ConsumableItem " + item_name + " ready", "ConsumableItem")

func _process(delta: float) -> void:
	# Handle effect duration
	if effect_timer > 0 and effect_target:
		effect_timer -= delta
		if effect_timer <= 0:
			_end_effect()

## Override pickup for auto-consumption
func pickup(player: BasePlayer) -> bool:
	if not super.pickup(player):
		return false
	
	# Auto-consume if enabled
	if auto_consume_on_pickup:
		use_item()
		return true
	
	return true

## Override use implementation for consumable effects
func _use_implementation() -> bool:
	if not holder:
		return false
	
	_apply_effect(holder)
	
	# Consumables are destroyed after use
	if auto_consume_on_pickup:
		queue_free()
	
	return true

## Apply the consumable effect to the player
func _apply_effect(player: BasePlayer) -> void:
	effect_target = player
	
	# Apply healing
	if heal_amount > 0:
		var health_component: HealthComponent = player.get_component(HealthComponent)
		if health_component:
			health_component.heal(heal_amount)
			Logger.item(player.player_data.player_name + " healed for " + str(heal_amount), "ConsumableItem")
	
	# Apply speed boost
	if speed_boost_duration > 0:
		var movement_component: MovementComponent = player.get_component(MovementComponent)
		if movement_component:
			movement_component.apply_speed_modifier(1.5)  # 50% speed boost
			effect_timer = speed_boost_duration
			Logger.item(player.player_data.player_name + " gained speed boost for " + str(speed_boost_duration) + "s", "ConsumableItem")
	
	# Apply damage boost  
	if damage_boost_duration > 0:
		# This would need a damage component or weapon enhancement
		effect_timer = max(effect_timer, damage_boost_duration)
		Logger.item(player.player_data.player_name + " gained damage boost for " + str(damage_boost_duration) + "s", "ConsumableItem")
	
	effect_applied.emit(player, effect_description)

## End temporary effects
func _end_effect() -> void:
	if not effect_target:
		return
	
	# Remove speed boost
	if speed_boost_duration > 0:
		var movement_component: MovementComponent = effect_target.get_component(MovementComponent)
		if movement_component:
			movement_component.remove_speed_modifier()
			Logger.item(effect_target.player_data.player_name + " speed boost expired", "ConsumableItem")
	
	effect_expired.emit(effect_target, effect_description)
	effect_target = null
	effect_timer = 0.0 
class_name IWeaponHolder
extends RefCounted

## Interface for entities that can hold and manage weapons
## Provides weapon positioning and orientation information

## Virtual methods that must be implemented by weapon holders

## Get the world position where held weapons should be positioned
func get_weapon_hold_position() -> Vector2:
	assert(false, "get_weapon_hold_position() must be implemented by IWeaponHolder")
	return Vector2.ZERO

## Get the current facing direction (-1 for left, 1 for right)
func get_facing_direction() -> int:
	assert(false, "get_facing_direction() must be implemented by IWeaponHolder")
	return 1

## Get the unique identifier for this holder
func get_player_id() -> int:
	assert(false, "get_player_id() must be implemented by IWeaponHolder")
	return -1

## Get the player data associated with this holder
func get_player_data() -> PlayerData:
	assert(false, "get_player_data() must be implemented by IWeaponHolder")
	return null

## Get the holder's current velocity (for physics interactions)
func get_current_velocity() -> Vector2:
	assert(false, "get_current_velocity() must be implemented by IWeaponHolder")
	return Vector2.ZERO

## Check if the holder is in a valid state to hold weapons
func can_hold_weapons() -> bool:
	assert(false, "can_hold_weapons() must be implemented by IWeaponHolder")
	return false 
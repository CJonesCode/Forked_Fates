class_name InputConfig
extends Resource

## Input configuration resource for flexible player input mapping
## Supports different input devices and customizable key bindings
## Momentum-based weapon controls: fire/momentum-throw/pickup

enum InputDevice {
	KEYBOARD_WASD,
	KEYBOARD_ARROWS,
	KEYBOARD_IJKL,
	KEYBOARD_NUMPAD,
	GAMEPAD_1,
	GAMEPAD_2,
	GAMEPAD_3,
	GAMEPAD_4
}

@export var device_type: InputDevice = InputDevice.KEYBOARD_WASD
@export var move_left_action: String = "move_left"
@export var move_right_action: String = "move_right"
@export var jump_action: String = "jump"

# Momentum-based weapon actions
@export var fire_action: String = "fire"          # Fire held weapon
@export var throw_action: String = "throw"        # Throw held weapon (momentum-based: still=drop, moving=weaponize)
@export var pickup_action: String = "pickup"      # Pick up nearby weapon

## Create default input configurations for each player
static func create_default_configs() -> Array[InputConfig]:
	var configs: Array[InputConfig] = []
	
	# Player 1 - WASD (momentum-based controls)
	var p1_config = InputConfig.new()
	p1_config.device_type = InputDevice.KEYBOARD_WASD
	p1_config.move_left_action = "p1_move_left"
	p1_config.move_right_action = "p1_move_right"
	p1_config.jump_action = "p1_jump"
	p1_config.fire_action = "p1_fire"
	p1_config.throw_action = "p1_throw"
	p1_config.pickup_action = "p1_pickup"
	configs.append(p1_config)
	
	# Player 2 - Arrow Keys (momentum-based controls)
	var p2_config = InputConfig.new()
	p2_config.device_type = InputDevice.KEYBOARD_ARROWS
	p2_config.move_left_action = "p2_move_left"
	p2_config.move_right_action = "p2_move_right"
	p2_config.jump_action = "p2_jump"
	p2_config.fire_action = "p2_fire"
	p2_config.throw_action = "p2_throw"
	p2_config.pickup_action = "p2_pickup"
	configs.append(p2_config)
	

	
	return configs

## Get readable device name
func get_device_name() -> String:
	match device_type:
		InputDevice.KEYBOARD_WASD:
			return "WASD Keys"
		InputDevice.KEYBOARD_ARROWS:
			return "Arrow Keys"
		InputDevice.KEYBOARD_IJKL:
			return "IJKL Keys"
		InputDevice.KEYBOARD_NUMPAD:
			return "Numpad"
		InputDevice.GAMEPAD_1:
			return "Gamepad 1"
		InputDevice.GAMEPAD_2:
			return "Gamepad 2"
		InputDevice.GAMEPAD_3:
			return "Gamepad 3"
		InputDevice.GAMEPAD_4:
			return "Gamepad 4"
		_:
			return "Unknown Device" 
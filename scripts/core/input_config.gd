class_name InputConfig
extends Resource

## Input configuration resource for flexible player input mapping
## Supports different input devices and customizable key bindings

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
@export var use_action: String = "use"
@export var drop_action: String = "drop"

## Create default input configurations for each player
static func create_default_configs() -> Array[InputConfig]:
	var configs: Array[InputConfig] = []
	
	# Player 1 - WASD
	var p1_config = InputConfig.new()
	p1_config.device_type = InputDevice.KEYBOARD_WASD
	p1_config.move_left_action = "p1_move_left"
	p1_config.move_right_action = "p1_move_right"
	p1_config.jump_action = "p1_jump"
	p1_config.use_action = "p1_use"
	p1_config.drop_action = "p1_drop"
	configs.append(p1_config)
	
	# Player 2 - Arrow Keys
	var p2_config = InputConfig.new()
	p2_config.device_type = InputDevice.KEYBOARD_ARROWS
	p2_config.move_left_action = "p2_move_left"
	p2_config.move_right_action = "p2_move_right"
	p2_config.jump_action = "p2_jump"
	p2_config.use_action = "p2_use"
	p2_config.drop_action = "p2_drop"
	configs.append(p2_config)
	
	# Player 3 - IJKL
	var p3_config = InputConfig.new()
	p3_config.device_type = InputDevice.KEYBOARD_IJKL
	p3_config.move_left_action = "p3_move_left"
	p3_config.move_right_action = "p3_move_right"
	p3_config.jump_action = "p3_jump"
	p3_config.use_action = "p3_use"
	p3_config.drop_action = "p3_drop"
	configs.append(p3_config)
	
	# Player 4 - Numpad
	var p4_config = InputConfig.new()
	p4_config.device_type = InputDevice.KEYBOARD_NUMPAD
	p4_config.move_left_action = "p4_move_left"
	p4_config.move_right_action = "p4_move_right"
	p4_config.jump_action = "p4_jump"
	p4_config.use_action = "p4_use"
	p4_config.drop_action = "p4_drop"
	configs.append(p4_config)
	
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
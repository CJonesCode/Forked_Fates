class_name UIEventRouter
extends Node

## UI Event Router for Centralized UI Communication
## Routes UI events and manages typed signal connections

# Event routing signals - typed for better safety
signal button_pressed(button_name: String, context: Dictionary)
signal menu_item_selected(menu_name: String, item_id: String, data: Dictionary)
signal dialog_response(dialog_name: String, response: String, data: Dictionary)
signal input_field_changed(field_name: String, value: String, context: Dictionary)
signal slider_value_changed(slider_name: String, value: float, context: Dictionary)
signal checkbox_toggled(checkbox_name: String, checked: bool, context: Dictionary)
signal ui_state_changed(component_name: String, state: String, data: Dictionary)

# Event listeners registry
var event_listeners: Dictionary = {}
var signal_connections: Array[SignalConnection] = []

# Signal connection helper class
class SignalConnection:
	var source: Object
	var signal_name: String
	var target: Object
	var method: Callable
	var is_one_shot: bool
	
	func _init(src: Object, sig: String, tgt: Object, mth: Callable, one_shot: bool = false):
		source = src
		signal_name = sig
		target = tgt
		method = mth
		is_one_shot = one_shot

func _ready() -> void:
	Logger.system("UIEventRouter initialized", "UIEventRouter")

## Route a generic UI event
func route_event(event_name: String, data: Dictionary = {}) -> void:
	Logger.debug("Routing UI event: " + event_name + " with data: " + str(data), "UIEventRouter")
	
	# Route to specific typed signals based on event name
	match event_name:
		"button_pressed":
			var button_name: String = data.get("button_name", "")
			var context: Dictionary = data.get("context", {})
			button_pressed.emit(button_name, context)
		
		"menu_item_selected":
			var menu_name: String = data.get("menu_name", "")
			var item_id: String = data.get("item_id", "")
			var item_data: Dictionary = data.get("data", {})
			menu_item_selected.emit(menu_name, item_id, item_data)
		
		"dialog_response":
			var dialog_name: String = data.get("dialog_name", "")
			var response: String = data.get("response", "")
			var dialog_data: Dictionary = data.get("data", {})
			dialog_response.emit(dialog_name, response, dialog_data)
		
		"input_field_changed":
			var field_name: String = data.get("field_name", "")
			var value: String = data.get("value", "")
			var context: Dictionary = data.get("context", {})
			input_field_changed.emit(field_name, value, context)
		
		"slider_value_changed":
			var slider_name: String = data.get("slider_name", "")
			var value: float = data.get("value", 0.0)
			var context: Dictionary = data.get("context", {})
			slider_value_changed.emit(slider_name, value, context)
		
		"checkbox_toggled":
			var checkbox_name: String = data.get("checkbox_name", "")
			var checked: bool = data.get("checked", false)
			var context: Dictionary = data.get("context", {})
			checkbox_toggled.emit(checkbox_name, checked, context)
		
		"ui_state_changed":
			var component_name: String = data.get("component_name", "")
			var state: String = data.get("state", "")
			var state_data: Dictionary = data.get("data", {})
			ui_state_changed.emit(component_name, state, state_data)
		
		_:
			Logger.warning("Unknown UI event type: " + event_name, "UIEventRouter")

## Register event listener for specific event types
func register_event_listener(event_name: String, target: Object, method: Callable) -> void:
	if not event_listeners.has(event_name):
		event_listeners[event_name] = []
	
	var listener_data: Dictionary = {
		"target": target,
		"method": method
	}
	
	event_listeners[event_name].append(listener_data)
	Logger.debug("Registered event listener for: " + event_name, "UIEventRouter")

## Unregister event listener
func unregister_event_listener(event_name: String, target: Object) -> void:
	if not event_listeners.has(event_name):
		return
	
	var listeners: Array = event_listeners[event_name]
	for i in range(listeners.size() - 1, -1, -1):
		if listeners[i]["target"] == target:
			listeners.remove_at(i)
			Logger.debug("Unregistered event listener for: " + event_name, "UIEventRouter")
			break
	
	# Clean up empty event arrays
	if listeners.is_empty():
		event_listeners.erase(event_name)

## Connect signal with automatic cleanup tracking
func connect_signal_safe(source: Object, signal_name: String, target: Object, method: Callable, one_shot: bool = false) -> bool:
	if not source or not target:
		Logger.error("Cannot connect signal - invalid source or target", "UIEventRouter")
		return false
	
	if not source.has_signal(signal_name):
		Logger.error("Signal '" + signal_name + "' does not exist on source object", "UIEventRouter")
		return false
	
	# Connect the signal
	var flags: int = 0
	if one_shot:
		flags = CONNECT_ONE_SHOT
	
	var result: int = source.connect(signal_name, method, flags)
	if result != OK:
		Logger.error("Failed to connect signal: " + signal_name, "UIEventRouter")
		return false
	
	# Track the connection for cleanup
	var connection: SignalConnection = SignalConnection.new(source, signal_name, target, method, one_shot)
	signal_connections.append(connection)
	
	Logger.debug("Connected signal: " + signal_name + " from " + str(source) + " to " + str(target), "UIEventRouter")
	return true

## Disconnect signal and remove from tracking
func disconnect_signal_safe(source: Object, signal_name: String, target: Object, method: Callable) -> bool:
	if not source or not target:
		return false
	
	if source.is_connected(signal_name, method):
		source.disconnect(signal_name, method)
		
		# Remove from tracking
		for i in range(signal_connections.size() - 1, -1, -1):
			var conn: SignalConnection = signal_connections[i]
			if conn.source == source and conn.signal_name == signal_name and conn.target == target and conn.method == method:
				signal_connections.remove_at(i)
				Logger.debug("Disconnected signal: " + signal_name, "UIEventRouter")
				return true
	
	return false

## Disconnect all signals from a specific target (for cleanup)
func disconnect_all_from_target(target: Object) -> void:
	if not target:
		return
	
	for i in range(signal_connections.size() - 1, -1, -1):
		var conn: SignalConnection = signal_connections[i]
		if conn.target == target:
			if conn.source and conn.source.is_connected(conn.signal_name, conn.method):
				conn.source.disconnect(conn.signal_name, conn.method)
			signal_connections.remove_at(i)
	
	Logger.debug("Disconnected all signals from target: " + str(target), "UIEventRouter")

## Cleanup invalid signal connections
func cleanup_invalid_connections() -> void:
	for i in range(signal_connections.size() - 1, -1, -1):
		var conn: SignalConnection = signal_connections[i]
		if not conn.source or not conn.target or not conn.source.is_connected(conn.signal_name, conn.method):
			signal_connections.remove_at(i)
	
	Logger.debug("Cleaned up invalid signal connections", "UIEventRouter")

## Emit button press event
func emit_button_pressed(button_name: String, context: Dictionary = {}) -> void:
	button_pressed.emit(button_name, context)

## Emit menu item selection event
func emit_menu_item_selected(menu_name: String, item_id: String, data: Dictionary = {}) -> void:
	menu_item_selected.emit(menu_name, item_id, data)

## Emit dialog response event
func emit_dialog_response(dialog_name: String, response: String, data: Dictionary = {}) -> void:
	dialog_response.emit(dialog_name, response, data)

## Emit input field change event
func emit_input_field_changed(field_name: String, value: String, context: Dictionary = {}) -> void:
	input_field_changed.emit(field_name, value, context)

## Emit slider value change event
func emit_slider_value_changed(slider_name: String, value: float, context: Dictionary = {}) -> void:
	slider_value_changed.emit(slider_name, value, context)

## Emit checkbox toggle event
func emit_checkbox_toggled(checkbox_name: String, checked: bool, context: Dictionary = {}) -> void:
	checkbox_toggled.emit(checkbox_name, checked, context)

## Emit UI state change event
func emit_ui_state_changed(component_name: String, state: String, data: Dictionary = {}) -> void:
	ui_state_changed.emit(component_name, state, data)

## Get event statistics for debugging
func get_event_stats() -> Dictionary:
	return {
		"registered_events": event_listeners.keys(),
		"active_connections": signal_connections.size(),
		"listeners_count": event_listeners.size()
	}

func _exit_tree() -> void:
	# Clean up all signal connections
	for conn in signal_connections:
		if conn.source and conn.source.is_connected(conn.signal_name, conn.method):
			conn.source.disconnect(conn.signal_name, conn.method)
	
	signal_connections.clear()
	event_listeners.clear()
	Logger.debug("UIEventRouter cleaned up", "UIEventRouter") 
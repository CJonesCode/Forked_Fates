class_name MapStateInterface
extends Node

## Communication bridge between minigames and the persistent overworld state
## Handles state synchronization, rollback scenarios, and world effect application

# State tracking - using Dictionary structures as per standards
var pre_minigame_snapshot: Dictionary = {}
var pending_changes: Array[StateChange] = []
var committed_changes: Array[StateChange] = []
var rollback_enabled: bool = true

# Signals
signal minigame_completed(result: MinigameResult)
signal map_state_updated(changes: Array[StateChange])
signal state_change_applied(change: StateChange)
signal rollback_performed(snapshot: Dictionary)

## State change types
enum ChangeType {
	PLAYER_POSITION,
	PLAYER_INVENTORY,
	PLAYER_HEALTH,
	MAP_PROGRESSION,
	REWARDS_APPLIED,
	WORLD_EVENT
}

## Individual state change data
class StateChange:
	var change_type: ChangeType
	var affected_entities: Array[int] = []  # player_ids, territory_ids, etc.
	var old_values: Dictionary = {}
	var new_values: Dictionary = {}
	var timestamp: float
	var reversible: bool = true
	var description: String = ""
	
	func _init(type: ChangeType) -> void:
		change_type = type
		timestamp = Time.get_unix_time_from_system()

func _ready() -> void:
	Logger.system("MapStateInterface ready", "MapStateInterface")

## Proper cleanup following standards
func _exit_tree() -> void:
	# Clear all tracking data
	pending_changes.clear()
	committed_changes.clear()
	
	# Disconnect from any connected signals
	Logger.system("MapStateInterface cleanup completed", "MapStateInterface")

## Apply minigame results to the persistent world state
func apply_minigame_results(result: MinigameResult) -> void:
	Logger.game_flow("Applying minigame results to world state", "MapStateInterface")
	
	# Clear pending changes
	pending_changes.clear()
	
	# Process different types of changes
	_process_player_state_updates(result)
	_process_map_progression(result)
	_process_rewards_and_penalties(result)
	
	# Commit all changes
	_commit_pending_changes()
	
	# Emit completion signal
	minigame_completed.emit(result)
	
	Logger.system("Applied " + str(committed_changes.size()) + " state changes from minigame", "MapStateInterface")

## Get pre-minigame snapshot for rollback scenarios
func get_pre_minigame_snapshot() -> Dictionary:
	if pre_minigame_snapshot.is_empty():
		pre_minigame_snapshot = _create_current_snapshot()
	return pre_minigame_snapshot

## Create snapshot using Dictionary structure (following standards)
func _create_current_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"snapshot_timestamp": Time.get_unix_time_from_system(),
		"player_states": {},
		"map_data": {},
		"game_state": {}
	}
	# Would populate with actual game state
	return snapshot

## Rollback to pre-minigame state (for abandoned games)
func rollback_to_snapshot() -> void:
	if not rollback_enabled or pre_minigame_snapshot.is_empty():
		Logger.warning("Rollback not available", "MapStateInterface")
		return
	
	Logger.game_flow("Rolling back to pre-minigame state", "MapStateInterface")
	
	# Restore state from snapshot
	_restore_from_snapshot(pre_minigame_snapshot)
	
	# Clear tracking
	pending_changes.clear()
	committed_changes.clear()
	
	rollback_performed.emit(pre_minigame_snapshot)

## Process player state updates from minigame results
func _process_player_state_updates(result: MinigameResult) -> void:
	for player_id in result.participating_players:
		var player_data: PlayerData = GameManager.get_player_data(player_id)
		if not player_data:
			continue
		
		# Health changes that persist post-minigame
		if result.statistics.has("final_health_" + str(player_id)):
			var new_health: int = result.statistics["final_health_" + str(player_id)]
			_add_state_change(ChangeType.PLAYER_HEALTH, [player_id], 
				{"health": player_data.current_health}, {"health": new_health})
			player_data.current_health = new_health
		
		# Inventory modifications
		for item_change_dict in result.item_state_changes:
			if item_change_dict.get("player_id", -1) == player_id:
				_apply_inventory_change(player_id, item_change_dict)

## Process map progression changes
func _process_map_progression(result: MinigameResult) -> void:
	if not result.progression_data or result.progression_data.is_empty():
		return
	
	var progression_dict: Dictionary = result.progression_data
	
	# Mark current node as completed
	if progression_dict.get("current_node_completed", false):
		_add_state_change(ChangeType.MAP_PROGRESSION, [], 
			{"current_node_completed": false}, 
			{"current_node_completed": true})
	
	# Unlock new nodes
	for node_id in progression_dict.get("unlock_next_nodes", []):
		_add_state_change(ChangeType.MAP_PROGRESSION, [], 
			{"node": node_id, "available": false}, 
			{"node": node_id, "available": true})
	
	# Block nodes (for story branching)
	for node_id in progression_dict.get("block_nodes", []):
		_add_state_change(ChangeType.MAP_PROGRESSION, [], 
			{"node": node_id, "available": true}, 
			{"node": node_id, "available": false})

## Process rewards and penalties distribution
func _process_rewards_and_penalties(result: MinigameResult) -> void:
	# Apply rewards
	for reward in result.rewards_earned:
		_apply_reward(reward)
	
	# Apply penalties
	for penalty in result.penalties_applied:
		_apply_penalty(penalty)

## Apply a reward to a player
func _apply_reward(reward_dict: Dictionary) -> void:
	var player_data: PlayerData = GameManager.get_player_data(reward_dict.get("player_id", -1))
	if not player_data:
		return
	
	var reward_type: String = reward_dict.get("reward_type", "")
	var amount: int = reward_dict.get("amount", 0)
	var item_name: String = reward_dict.get("item_name", "")
	
	match reward_type:
		"currency":
			# Add currency - would need currency system
			Logger.system("Rewarded " + str(amount) + " currency to player " + str(reward_dict.get("player_id", -1)), "MapStateInterface")
		"item":
			# Add item to inventory
			var item_change_dict: Dictionary = {
				"player_id": reward_dict.get("player_id", -1),
				"item_name": item_name,
				"change_type": "gained",
				"quantity": amount
			}
			_apply_inventory_change(reward_dict.get("player_id", -1), item_change_dict)
		"health":
			# Restore health
			if player_data:
				var old_health: int = player_data.current_health
				var new_health: int = min(player_data.max_health, old_health + amount)
				_add_state_change(ChangeType.PLAYER_HEALTH, [reward_dict.get("player_id", -1)],
					{"health": old_health}, {"health": new_health})

## Apply a penalty to a player
func _apply_penalty(penalty_dict: Dictionary) -> void:
	var player_data: PlayerData = GameManager.get_player_data(penalty_dict.get("player_id", -1))
	if not player_data:
		return
	
	var penalty_type: String = penalty_dict.get("penalty_type", "")
	var amount: int = penalty_dict.get("amount", 0)
	var item_name: String = penalty_dict.get("item_name", "")
	
	match penalty_type:
		"currency_loss":
			Logger.system("Penalized " + str(amount) + " currency from player " + str(penalty_dict.get("player_id", -1)), "MapStateInterface")
		"item_loss":
			var item_change_dict: Dictionary = {
				"player_id": penalty_dict.get("player_id", -1),
				"item_name": item_name,
				"change_type": "lost",
				"quantity": amount
			}
			_apply_inventory_change(penalty_dict.get("player_id", -1), item_change_dict)
		"health_loss":
			# Damage player health
			if player_data:
				var old_health: int = player_data.current_health
				var new_health: int = max(0, old_health - amount)
				_add_state_change(ChangeType.PLAYER_HEALTH, [penalty_dict.get("player_id", -1)],
					{"health": old_health}, {"health": new_health})

## Apply inventory change
func _apply_inventory_change(player_id: int, item_change_dict: Dictionary) -> void:
	var player_data: PlayerData = GameManager.get_player_data(player_id)
	if not player_data:
		return
	
	var item_name: String = item_change_dict.get("item_name", "")
	var change_type: String = item_change_dict.get("change_type", "")
	var quantity: int = item_change_dict.get("quantity", 0)
	
	# This would interface with actual inventory system
	var old_inventory: Array = []  # Get current inventory
	var new_inventory: Array = old_inventory.duplicate()
	
	match change_type:
		"gained":
			for i in range(quantity):
				new_inventory.append(item_name)
		"lost":
			for i in range(quantity):
				new_inventory.erase(item_name)
	
	_add_state_change(ChangeType.PLAYER_INVENTORY, [player_id],
		{"inventory": old_inventory}, {"inventory": new_inventory})

## Add a state change to pending list
func _add_state_change(type: ChangeType, entities: Array[int], old_values: Dictionary, new_values: Dictionary) -> void:
	var change: StateChange = StateChange.new(type)
	change.affected_entities = entities.duplicate()
	change.old_values = old_values.duplicate()
	change.new_values = new_values.duplicate()
	change.description = _generate_change_description(change)
	
	pending_changes.append(change)
	Logger.system("Added state change: " + change.description, "MapStateInterface")

## Commit all pending changes
func _commit_pending_changes() -> void:
	for change in pending_changes:
		_apply_state_change(change)
		committed_changes.append(change)
		state_change_applied.emit(change)
	
	map_state_updated.emit(pending_changes.duplicate())
	pending_changes.clear()

## Apply a single state change
func _apply_state_change(change: StateChange) -> void:
	match change.change_type:
		ChangeType.PLAYER_HEALTH:
			# Apply health change
			var player_id: int = change.affected_entities[0]
			var new_health: int = change.new_values["health"]
			GameManager.get_player_data(player_id).current_health = new_health
		ChangeType.PLAYER_INVENTORY:
			# Apply inventory change
			var player_id: int = change.affected_entities[0]
			# Update actual inventory system when implemented
		ChangeType.MAP_PROGRESSION:
			# Apply map progression change
			# Update node availability in map system when implemented
			Logger.system("Map progression: " + str(change.new_values), "MapStateInterface")
		ChangeType.REWARDS_APPLIED:
			# Rewards have already been processed, this is just for tracking
			pass

## Generate change summary for the result
func _generate_change_summary(result: MinigameResult) -> Array[StateChange]:
	return committed_changes.duplicate()

# Removed relationship system - not needed for this game type

## Restore state from snapshot
func _restore_from_snapshot(snapshot: Dictionary) -> void:
	# This would restore all systems to snapshot state
	var timestamp: float = snapshot.get("snapshot_timestamp", 0.0)
	Logger.system("Restoring state from snapshot timestamp: " + str(timestamp), "MapStateInterface")

## Generate description for a state change
func _generate_change_description(change: StateChange) -> String:
	var type_name: String = ChangeType.keys()[change.change_type]
	var entity_list: String = str(change.affected_entities) if not change.affected_entities.is_empty() else "system"
	return type_name + " affecting " + entity_list 
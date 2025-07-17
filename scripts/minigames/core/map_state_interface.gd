class_name MapStateInterface
extends Node

## Communication bridge between minigames and the persistent overworld state
## Handles state synchronization, rollback scenarios, and world effect application

# State tracking
var pre_minigame_snapshot: MapSnapshot = null
var pending_changes: Array[StateChange] = []
var committed_changes: Array[StateChange] = []
var rollback_enabled: bool = true

# Signals
signal minigame_completed(result: MinigameResult)
signal map_state_updated(changes: Array[StateChange])
signal state_change_applied(change: StateChange)
signal rollback_performed(snapshot: MapSnapshot)

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
func get_pre_minigame_snapshot() -> MapSnapshot:
	if not pre_minigame_snapshot:
		pre_minigame_snapshot = MapSnapshot.create_current_snapshot()
	return pre_minigame_snapshot

## Rollback to pre-minigame state (for abandoned games)
func rollback_to_snapshot() -> void:
	if not rollback_enabled or not pre_minigame_snapshot:
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
		for item_change in result.item_state_changes:
			if item_change.player_id == player_id:
				_apply_inventory_change(player_id, item_change)

## Process map progression changes
func _process_map_progression(result: MinigameResult) -> void:
	if not result.progression_data:
		return
	
	var progression: ProgressionData = result.progression_data
	
	# Mark current node as completed
	if progression.current_node_completed:
		_add_state_change(ChangeType.MAP_PROGRESSION, [], 
			{"current_node_completed": false}, 
			{"current_node_completed": true})
	
	# Unlock new nodes
	for node_id in progression.unlock_next_nodes:
		_add_state_change(ChangeType.MAP_PROGRESSION, [], 
			{"node": node_id, "available": false}, 
			{"node": node_id, "available": true})
	
	# Block nodes (for story branching)
	for node_id in progression.block_nodes:
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
func _apply_reward(reward: Reward) -> void:
	var player_data: PlayerData = GameManager.get_player_data(reward.player_id)
	if not player_data:
		return
	
	match reward.reward_type:
		"currency":
			# Add currency - would need currency system
			Logger.system("Rewarded " + str(reward.amount) + " currency to player " + str(reward.player_id), "MapStateInterface")
		"item":
			# Add item to inventory
			var item_change: ItemStateChange = ItemStateChange.new()
			item_change.player_id = reward.player_id
			item_change.item_name = reward.item_name
			item_change.change_type = "gained"
			item_change.quantity = reward.amount
			_apply_inventory_change(reward.player_id, item_change)
		"health":
			# Restore health
			var player_data: PlayerData = GameManager.get_player_data(reward.player_id)
			if player_data:
				var old_health: int = player_data.current_health
				var new_health: int = min(player_data.max_health, old_health + reward.amount)
				_add_state_change(ChangeType.PLAYER_HEALTH, [reward.player_id],
					{"health": old_health}, {"health": new_health})

## Apply a penalty to a player
func _apply_penalty(penalty: Penalty) -> void:
	var player_data: PlayerData = GameManager.get_player_data(penalty.player_id)
	if not player_data:
		return
	
	match penalty.penalty_type:
		"currency_loss":
			Logger.system("Penalized " + str(penalty.amount) + " currency from player " + str(penalty.player_id), "MapStateInterface")
		"item_loss":
			var item_change: ItemStateChange = ItemStateChange.new()
			item_change.player_id = penalty.player_id
			item_change.item_name = penalty.item_name
			item_change.change_type = "lost"
			item_change.quantity = penalty.amount
			_apply_inventory_change(penalty.player_id, item_change)
		"health_loss":
			# Damage player health
			var player_data: PlayerData = GameManager.get_player_data(penalty.player_id)
			if player_data:
				var old_health: int = player_data.current_health
				var new_health: int = max(0, old_health - penalty.amount)
				_add_state_change(ChangeType.PLAYER_HEALTH, [penalty.player_id],
					{"health": old_health}, {"health": new_health})

## Apply inventory change
func _apply_inventory_change(player_id: int, item_change: ItemStateChange) -> void:
	var player_data: PlayerData = GameManager.get_player_data(player_id)
	if not player_data:
		return
	
	# This would interface with actual inventory system
	var old_inventory: Array = []  # Get current inventory
	var new_inventory: Array = old_inventory.duplicate()
	
	match item_change.change_type:
		"gained":
			for i in range(item_change.quantity):
				new_inventory.append(item_change.item_name)
		"lost":
			for i in range(item_change.quantity):
				new_inventory.erase(item_change.item_name)
	
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
func _restore_from_snapshot(snapshot: MapSnapshot) -> void:
	# This would restore all systems to snapshot state
	Logger.system("Restoring state from snapshot timestamp: " + str(snapshot.snapshot_timestamp), "MapStateInterface")

## Generate description for a state change
func _generate_change_description(change: StateChange) -> String:
	var type_name: String = ChangeType.keys()[change.change_type]
	var entity_list: String = str(change.affected_entities) if not change.affected_entities.is_empty() else "system"
	return type_name + " affecting " + entity_list 
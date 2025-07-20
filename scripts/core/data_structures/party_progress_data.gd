class_name PartyProgressData
extends Resource

## Shared party progress tracking for map view
## Tracks the party's position on the map, shared state, and recent outcomes

# Map position and progression
@export var current_map_node: int = 0  # Current node the party is on
@export var nodes_completed: Array[int] = []  # All nodes the party has finished
@export var nodes_available: Array[int] = []  # Nodes currently available to choose from
@export var total_nodes_unlocked: int = 0  # Total progression metric

# Recent winner tracking
@export var last_winner_id: int = -1  # Player ID of most recent minigame winner
@export var last_winner_name: String = ""  # Player name for display
@export var last_minigame_type: String = ""  # Type of minigame that was won
@export var consecutive_wins: Dictionary = {}  # player_id -> consecutive_wins count

# Party-wide status
@export var party_size: int = 4  # Number of players in the party
@export var active_players: int = 4  # Number of non-eliminated players
@export var session_start_time: int = 0  # Unix timestamp when session started
@export var total_minigames_played: int = 0  # Total minigames completed by party

# Shared party inventory and effects
@export var party_inventory: Array[String] = []  # Shared items/resources
@export var active_party_effects: Array[String] = []  # Global buffs/debuffs affecting all players
@export var party_achievements: Array[String] = []  # Achievements earned by the party as a whole

# Current voting/decision state
@export var pending_decisions: Array[Dictionary] = []  # Votes or choices the party needs to make
@export var decision_deadline: int = 0  # Unix timestamp when decisions must be made

# Map progression history
@export var path_taken: Array[int] = []  # Complete path of nodes taken this session
@export var major_milestones: Array[Dictionary] = []  # Important events in party history

func _init() -> void:
	current_map_node = 0
	nodes_completed = []
	nodes_available = [1]  # Start with first node available
	total_nodes_unlocked = 1
	last_winner_id = -1
	last_winner_name = ""
	last_minigame_type = ""
	consecutive_wins = {}
	party_size = 4
	active_players = 4
	session_start_time = Time.get_unix_time_from_system()
	total_minigames_played = 0
	party_inventory = []
	active_party_effects = []
	party_achievements = []
	pending_decisions = []
	decision_deadline = 0
	path_taken = []
	major_milestones = []

## Record the result of a completed minigame
func record_minigame_result(winner_id: int, winner_name: String, minigame_type: String, all_participants: Array[int]) -> void:
	last_winner_id = winner_id
	last_winner_name = winner_name
	last_minigame_type = minigame_type
	total_minigames_played += 1
	
	# Track consecutive wins
	for participant_id in all_participants:
		if participant_id == winner_id:
			consecutive_wins[participant_id] = consecutive_wins.get(participant_id, 0) + 1
		else:
			consecutive_wins[participant_id] = 0  # Reset streak for non-winners
	
	# Add to major milestones if significant
	if consecutive_wins.get(winner_id, 0) >= 3:
		add_milestone("player_streak", {
			"player_id": winner_id,
			"player_name": winner_name,
			"streak": consecutive_wins[winner_id],
			"timestamp": Time.get_unix_time_from_system()
		})

## Move the party to a new map node
func move_to_node(node_id: int) -> bool:
	if node_id not in nodes_available:
		return false  # Can't move to unavailable node
	
	# Complete current node
	if current_map_node > 0:  # Don't mark starting position as completed
		nodes_completed.append(current_map_node)
	
	# Update path taken
	path_taken.append(node_id)
	
	# Move to new node
	current_map_node = node_id
	
	# Update available nodes (placeholder logic - real logic would be map-specific)
	_update_available_nodes()
	
	# Add milestone for significant progression
	if nodes_completed.size() % 5 == 0:  # Every 5 nodes
		add_milestone("major_progression", {
			"nodes_completed": nodes_completed.size(),
			"timestamp": Time.get_unix_time_from_system()
		})
	
	return true

## Eliminate a player from the party
func eliminate_player(player_id: int, reason: String) -> void:
	active_players = max(1, active_players - 1)  # Ensure at least 1 player remains
	consecutive_wins.erase(player_id)  # Remove from streak tracking
	
	add_milestone("player_eliminated", {
		"player_id": player_id,
		"reason": reason,
		"remaining_players": active_players,
		"timestamp": Time.get_unix_time_from_system()
	})

## Add an item to the party inventory
func add_party_item(item_id: String) -> void:
	if item_id not in party_inventory:
		party_inventory.append(item_id)

## Remove an item from party inventory
func remove_party_item(item_id: String) -> bool:
	if item_id in party_inventory:
		party_inventory.erase(item_id)
		return true
	return false

## Check if party has a specific item
func has_party_item(item_id: String) -> bool:
	return item_id in party_inventory

## Apply a party-wide effect
func apply_party_effect(effect_id: String, duration_nodes: int = -1) -> void:
	var effect_data: Dictionary = {
		"effect_id": effect_id,
		"duration": duration_nodes,
		"applied_node": current_map_node
	}
	active_party_effects.append(effect_data)

## Remove a party effect
func remove_party_effect(effect_id: String) -> void:
	for i in range(active_party_effects.size() - 1, -1, -1):
		if active_party_effects[i].get("effect_id", "") == effect_id:
			active_party_effects.remove_at(i)

## Check if party has a specific effect active
func has_party_effect(effect_id: String) -> bool:
	for effect in active_party_effects:
		if effect.get("effect_id", "") == effect_id:
			return true
	return false

## Add a party achievement
func unlock_party_achievement(achievement_id: String, description: String = "") -> void:
	if achievement_id not in party_achievements:
		party_achievements.append(achievement_id)
		
		add_milestone("party_achievement", {
			"achievement_id": achievement_id,
			"description": description,
			"timestamp": Time.get_unix_time_from_system()
		})

## Add a decision that the party needs to make
func add_pending_decision(decision_type: String, options: Array[String], deadline_seconds: int = 30) -> void:
	var decision: Dictionary = {
		"type": decision_type,
		"options": options,
		"votes": {},  # player_id -> option_index
		"deadline": Time.get_unix_time_from_system() + deadline_seconds
	}
	pending_decisions.append(decision)
	decision_deadline = decision.deadline

## Vote on a pending decision
func vote_on_decision(decision_index: int, player_id: int, option_index: int) -> bool:
	if decision_index >= pending_decisions.size():
		return false
	
	var decision: Dictionary = pending_decisions[decision_index]
	if option_index >= decision["options"].size():
		return false
	
	decision["votes"][player_id] = option_index
	return true

## Add a map node voting decision
func add_node_voting(available_node_ids: Array[int], deadline_seconds: int = 30) -> int:
	var options: Array[String] = []
	for node_id in available_node_ids:
		options.append("Node " + str(node_id))
	
	add_pending_decision("node_selection", options, deadline_seconds)
	return pending_decisions.size() - 1  # Return decision index

## Vote for a map node
func vote_for_node(decision_index: int, player_id: int, node_index: int) -> bool:
	return vote_on_decision(decision_index, player_id, node_index)

## Get voting results for a decision
func get_voting_results(decision_index: int) -> Dictionary:
	if decision_index >= pending_decisions.size():
		return {}
	
	var decision: Dictionary = pending_decisions[decision_index]
	var votes: Dictionary = decision["votes"]
	var options: Array[String] = decision["options"]
	
	# Count votes for each option
	var vote_counts: Array[int] = []
	for i in range(options.size()):
		vote_counts.append(0)
	
	for vote in votes.values():
		if vote >= 0 and vote < vote_counts.size():
			vote_counts[vote] += 1
	
	# Find winning option(s)
	var max_votes: int = 0
	var winning_options: Array[int] = []
	
	for i in range(vote_counts.size()):
		if vote_counts[i] > max_votes:
			max_votes = vote_counts[i]
			winning_options = [i]
		elif vote_counts[i] == max_votes:
			winning_options.append(i)
	
	return {
		"vote_counts": vote_counts,
		"max_votes": max_votes,
		"winning_options": winning_options,
		"is_tie": winning_options.size() > 1,
		"total_voters": active_players,
		"votes_cast": votes.size(),
		"options": options
	}

## Check if voting is complete (all players voted or deadline passed)
func is_voting_complete(decision_index: int) -> bool:
	if decision_index >= pending_decisions.size():
		return true
	
	var decision: Dictionary = pending_decisions[decision_index]
	var votes_cast: int = decision["votes"].size()
	var deadline_passed: bool = Time.get_unix_time_from_system() >= decision["deadline"]
	
	return votes_cast >= active_players or deadline_passed

## Resolve a voting decision and return the chosen option
func resolve_voting(decision_index: int) -> int:
	var results: Dictionary = get_voting_results(decision_index)
	
	if results.is_empty():
		return -1  # Invalid decision index
	
	# Handle tie-breaking
	var winning_options: Array[int] = results["winning_options"]
	if winning_options.is_empty():
		return 0  # Default to first option if no votes
	elif winning_options.size() == 1:
		return winning_options[0]
	else:
		# Simple tie-breaking: random selection
		return winning_options[randi() % winning_options.size()]

## Remove a completed decision
func remove_decision(decision_index: int) -> void:
	if decision_index >= 0 and decision_index < pending_decisions.size():
		pending_decisions.remove_at(decision_index)
		
		# Update deadline if this was the active decision
		if pending_decisions.is_empty():
			decision_deadline = 0
		else:
			# Set deadline to earliest remaining decision
			var earliest_deadline: int = 0
			for decision in pending_decisions:
				var deadline: int = decision["deadline"]
				if earliest_deadline == 0 or deadline < earliest_deadline:
					earliest_deadline = deadline
			decision_deadline = earliest_deadline

## Get the most recent winner's consecutive win count
func get_winner_streak() -> int:
	if last_winner_id == -1:
		return 0
	return consecutive_wins.get(last_winner_id, 0)

## Get session duration in minutes
func get_session_duration_minutes() -> float:
	return (Time.get_unix_time_from_system() - session_start_time) / 60.0

## Add a milestone to party history
func add_milestone(milestone_type: String, data: Dictionary) -> void:
	var milestone: Dictionary = {
		"type": milestone_type,
		"data": data,
		"node": current_map_node,
		"timestamp": Time.get_unix_time_from_system()
	}
	major_milestones.append(milestone)

## Get current party status summary for UI
func get_party_summary() -> Dictionary:
	return {
		"current_node": current_map_node,
		"nodes_completed": nodes_completed.size(),
		"total_unlocked": total_nodes_unlocked,
		"active_players": active_players,
		"total_players": party_size,
		"last_winner": last_winner_name,
		"winner_streak": get_winner_streak(),
		"session_duration": "%.1f min" % get_session_duration_minutes(),
		"party_items": party_inventory.size(),
		"active_effects": active_party_effects.size(),
		"achievements": party_achievements.size(),
		"pending_decisions": pending_decisions.size()
	}

## Private helper to update available nodes based on current position
func _update_available_nodes() -> void:
	# Placeholder implementation - real logic would be map-specific
	nodes_available.clear()
	
	# Simple linear progression for now
	var next_node: int = current_map_node + 1
	nodes_available.append(next_node)
	
	# Could add branching paths, optional nodes, etc.
	total_nodes_unlocked = max(total_nodes_unlocked, next_node)

## Reset for new session but preserve achievements
func reset_for_new_session() -> void:
	current_map_node = 0
	nodes_completed.clear()
	nodes_available = [1]
	total_nodes_unlocked = 1
	last_winner_id = -1
	last_winner_name = ""
	last_minigame_type = ""
	consecutive_wins.clear()
	active_players = party_size
	session_start_time = Time.get_unix_time_from_system()
	total_minigames_played = 0
	party_inventory.clear()
	active_party_effects.clear()
	# Keep party_achievements for lifetime tracking
	pending_decisions.clear()
	decision_deadline = 0
	path_taken.clear()
	major_milestones.clear() 
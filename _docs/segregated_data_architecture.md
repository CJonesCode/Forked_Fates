# Segregated Player Data Architecture

## Overview

The player data system has been refactored to segregate duties between different data structures, each with a focused responsibility:

1. **PlayerData** - Core session identification and current minigame state
2. **MinigameStats** - Per-minigame statistics for post-game display
3. **MapProgressData** - Individual player progress tracking for map view
4. **PartyProgressData** - Shared party state and progression
5. **PlayerStatistics** - Lifetime statistics across all sessions

## Data Structure Responsibilities

### PlayerData (Core Session State)
```gdscript
# Contains only essential current state
- player_id, player_name (identification)
- current_health, max_health, current_lives (minigame state)  
- is_alive, position (temporary state)
- References to: map_progress, lifetime_stats
```

**Use Cases:**
- Current minigame mechanics (health, lives)
- Player identification and spawning
- Temporary session state that resets per minigame

### MinigameStats (Post-Game Display)
```gdscript
# Flexible per-minigame statistics
- rank, score, performance_rating (core metrics)
- stats: Dictionary (flexible - each minigame defines)
- achievements, rewards_earned (minigame-specific rewards)
- display_data: Dictionary (UI formatting hints)
```

**Use Cases:**
- Post-game statistics screen
- Showing detailed performance per minigame
- Minigame-specific achievements and rewards
- Custom stat tracking per game type

### MapProgressData (Individual Progress)
```gdscript
# Long-term session progress for each player
- total_score, minigames_won/played (session progress)
- current_rewards, recent_scores/ranks (current state)
- current_streak, best_streak (performance tracking)
- win_percentage, performance_level (calculated metrics)
```

**Use Cases:**
- Map view player panels
- Session-wide scoring and ranking
- Persistent rewards and power-ups
- Performance trends and streaks

### PartyProgressData (Shared State)  
```gdscript
# Party-wide progression and state
- current_map_node, nodes_completed (map position)
- last_winner_id, consecutive_wins (recent outcomes)
- party_inventory, active_party_effects (shared resources)
- pending_decisions, major_milestones (party events)
```

**Use Cases:**
- Map view party position and status
- Shared party resources and effects
- Decision making and voting systems
- Party-wide achievements and milestones

### PlayerStatistics (Lifetime Tracking)
```gdscript
# Cross-session lifetime statistics
- games_played/won, total_playtime (lifetime metrics)
- minigame_wins/plays, best_scores (per-game tracking)
- achievements, skill_ratings (progression)
- play_patterns, social_metrics (advanced analytics)
```

**Use Cases:**
- Player profile and lifetime achievements
- Skill-based matchmaking data
- Long-term progression systems
- Analytics and player behavior insights

## Integration Example

### Example: Sudden Death Minigame Flow

```gdscript
# 1. During Minigame - Use PlayerData for current state
func _on_player_died(player_id: int) -> void:
    var player_data: PlayerData = GameManager.get_player_data(player_id)
    player_data.current_lives -= 1
    
    if player_data.is_out_of_lives():
        respawn_manager.block_player_respawn(player_id)

# 2. End of Minigame - Create MinigameStats for post-game
func _create_elimination_stats(player_id: int, rank: int) -> MinigameStats:
    var player_data: PlayerData = GameManager.get_player_data(player_id)
    var stats: MinigameStats = MinigameStats.create_elimination_stats(
        player_id, player_data.player_name, rank, 
        eliminations_count, deaths_count, survival_time
    )
    
    # Add minigame-specific achievements
    if eliminations_count >= 3:
        stats.achievements.append("Triple Eliminator")
    
    return stats

# 3. Update Session Progress - Use MapProgressData
func _update_player_progress(player_data: PlayerData, minigame_stats: MinigameStats, was_winner: bool) -> void:
    player_data.update_from_minigame_result(minigame_stats, was_winner)
    
    # MapProgressData automatically updated with:
    # - total_score += minigame_stats.score
    # - minigames_played += 1, minigames_won += 1 (if winner)
    # - recent_scores/ranks updated for trend tracking
    # - current_streak updated

# 4. Update Party State - Use PartyProgressData
func _update_party_progress(winner_id: int, all_participants: Array[int]) -> void:
    var party_data: PartyProgressData = GameManager.get_party_progress()
    var winner_data: PlayerData = GameManager.get_player_data(winner_id)
    
    party_data.record_minigame_result(
        winner_id, winner_data.player_name, "sudden_death", all_participants
    )

# 5. Create Comprehensive Result
func end_minigame() -> void:
    var all_stats: Array[MinigameStats] = []
    var winners: Array[int] = []
    
    # Collect all player statistics
    for player_id in participating_players:
        var stats: MinigameStats = _create_elimination_stats(player_id, get_player_rank(player_id))
        all_stats.append(stats)
        
        if stats.rank == 1:  # Winner
            winners.append(player_id)
    
    # Create comprehensive result for post-game screen
    var result: MinigameResult = MinigameResult.create_detailed_result(
        MinigameResult.MinigameOutcome.VICTORY,
        winners,
        all_stats,
        "sudden_death",
        game_duration,
        GameManager.get_party_progress()
    )
    
    # Show post-game screen with detailed statistics
    UIManager.show_post_game_screen(result)
```

## UI Integration Examples

### Map View Player Panel
```gdscript
func _update_player_panel(player_id: int) -> void:
    var player_data: PlayerData = GameManager.get_player_data(player_id)
    var map_progress: MapProgressData = player_data.get_map_progress()
    
    # Display current session progress
    score_label.text = str(map_progress.total_score)
    wins_label.text = str(map_progress.minigames_won) + "/" + str(map_progress.minigames_played)
    streak_label.text = map_progress.get_streak_description()
    performance_label.text = map_progress.get_performance_level()
    
    # Show active rewards
    rewards_container.clear()
    for reward in map_progress.current_rewards:
        var reward_icon = create_reward_icon(reward)
        rewards_container.add_child(reward_icon)
```

### Post-Game Statistics Screen
```gdscript
func _display_post_game_stats(result: MinigameResult) -> void:
    var sorted_stats: Array[MinigameStats] = result.get_sorted_player_stats()
    
    for stats in sorted_stats:
        var player_panel = create_player_stats_panel()
        
        # Core performance
        player_panel.set_rank(stats.rank)
        player_panel.set_score(stats.score)
        player_panel.set_performance_rating(stats.performance_rating)
        
        # Custom statistics with formatting
        for stat_name in stats.stats.keys():
            var formatted_value = stats.get_formatted_stat(stat_name)
            var display_label = stats.get_stat_label(stat_name)
            var is_highlighted = stats.is_stat_highlighted(stat_name)
            
            player_panel.add_stat_display(display_label, formatted_value, is_highlighted)
        
        # Achievements and rewards
        for achievement in stats.achievements:
            player_panel.add_achievement(achievement)
        
        stats_container.add_child(player_panel)
```

### Party Status Display
```gdscript
func _update_party_status() -> void:
    var party_data: PartyProgressData = GameManager.get_party_progress()
    var summary: Dictionary = party_data.get_party_summary()
    
    # Current position and progress
    current_node_label.text = "Node " + str(summary.current_node)
    progress_label.text = str(summary.nodes_completed) + " nodes completed"
    
    # Recent winner display
    if summary.last_winner != "":
        last_winner_label.text = summary.last_winner + " won last game"
        if summary.winner_streak > 1:
            streak_label.text = str(summary.winner_streak) + " win streak!"
    
    # Party resources
    party_items_label.text = str(summary.party_items) + " shared items"
    active_effects_label.text = str(summary.active_effects) + " party effects"
```

## Benefits of Segregation

### 1. **Clear Separation of Concerns**
- Each data structure has a focused responsibility
- No mixing of temporary vs persistent data
- Easy to understand what data belongs where

### 2. **Flexible Minigame Statistics**
- Each minigame defines its own relevant stats
- Consistent UI formatting with display hints
- Extensible for new minigame types

### 3. **Efficient Data Management**
- Only load/save relevant data for each context
- Session data separate from lifetime data
- Party state separate from individual progress

### 4. **UI Development**
- Clear data contracts for each screen type
- Post-game screen gets MinigameStats + MinigameResult
- Map view gets MapProgressData + PartyProgressData
- Profile screen gets PlayerStatistics

### 5. **Scalability**
- Easy to add new minigame stat types
- Party mechanics can evolve independently
- Lifetime tracking can be enhanced without affecting session logic

## Migration Notes

### Existing Code Updates Needed

1. **Replace direct PlayerData usage for progression:**
```gdscript
# OLD
player_data.total_score += minigame_score

# NEW  
player_data.get_map_progress().add_minigame_result(score, rank, was_winner)
```

2. **Use MinigameStats for post-game display:**
```gdscript
# OLD
show_post_game(winner_id, basic_stats)

# NEW
var stats = MinigameStats.create_elimination_stats(...)
var result = MinigameResult.create_detailed_result(...)
UIManager.show_post_game_screen(result)
```

3. **Access party state through PartyProgressData:**
```gdscript
# OLD
GameManager.current_map_node

# NEW
GameManager.get_party_progress().current_map_node
```

This architecture provides clean separation, flexibility for different minigame types, and clear data contracts for UI development. 
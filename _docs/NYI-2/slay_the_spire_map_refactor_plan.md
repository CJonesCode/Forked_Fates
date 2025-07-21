# Slay the Spire Map System - Refactoring Plan

**Status**: Planning Phase - Not Yet Implemented  
**Estimated Effort**: ~2 development days  
**Risk Level**: Low (preserves 90% of existing code)

## Overview

This document outlines the step-by-step refactoring plan to transform our current horizontal map system into a vertical "Slay the Spire" style map while preserving all existing functionality.

---

## 1. KEEP vs. REWRITE ANALYSIS

### Keep 100% Untouched
- **MapData.gd** - Pure data container, no changes needed
- **MapNode.gd** - Core data structure remains valid
- **MapNavigation.gd** - All voting and progression logic unchanged
- **MinigameDisplayNames.gd** - Display name mapping system
- **EventBus** - All map-related signals work as-is

### Keep with Small, Mechanical Edits
- **MapGenerationConfig.gd** - Add new orientation flags and weights
- **MapGenerator.gd** - Reuse algorithms; only change coordinate calculations
- **LineDrawer.gd** - Drawing is orientation-agnostic, works unchanged
- **map_navigation_controller.gd** - No changes needed

### Rewrite / Heavily Edit
- **MapRenderer.gd** - Swap axes, add scroll support, new positioning
- **map_view.tscn + map_view.gd** - Container becomes ScrollContainer, auto-scrolling
- **map_visual_config.gd** - Add orientation and column spacing properties

### New Files Required
- **scripts/map/layout/map_layout_helper.gd** - Single source of truth for positioning
- **scripts/ui/map/map_tooltip.gd** - Hover tooltip system
- **tests/map_vertical_layout_test.gd** - Verify vertical layout correctness

---

## 2. IMPLEMENTATION PHASES

### PHASE 0 - Branch & Scaffolding
**Goal**: Prepare infrastructure without breaking existing functionality

**Tasks**:
- [ ] Create git branch `vertical-map`
- [ ] Add `MapLayoutHelper` with static `compute_positions(map_data, config)`
- [ ] Initially copy existing horizontal algorithm for bit-exact compatibility
- [ ] Write unit test verifying horizontal rendering matches current master

**Deliverable**: Working horizontal layout through new helper system

---

### PHASE 1 - Config & Orientation Flag
**Goal**: Add configuration support for vertical orientation

**Files to Modify**:
- `scripts/map/config/map_visual_config.gd`

**Changes**:
```gdscript
@export_enum("horizontal", "vertical") var orientation: String = "vertical"
@export var column_spacing: float = 120.0  # distance between nodes in same row
# Keep layer_spacing as distance between layers (y-axis in vertical mode)
```

**Testing**: Config loads correctly, defaults to vertical

---

### PHASE 2 - Swap Axes in Layout Helper
**Goal**: Implement vertical positioning mathematics

**File**: `scripts/map/layout/map_layout_helper.gd`

**Key Algorithm**:
```gdscript
static func compute_positions(map_data: MapData, config: MapVisualConfig, container_size: Vector2) -> Dictionary:
    var positions = {}
    
    if config.orientation == "horizontal":
        # Keep existing horizontal math
        return _compute_horizontal_positions(map_data, config, container_size)
    else:
        # New vertical math
        for node in map_data.nodes.values():
            var x = margin + (container_size.x - total_row_width) * 0.5 + node.col * config.column_spacing
            var y = container_size.y - margin - node.row * config.layer_spacing
            positions[node.id] = Vector2(x + node_size.x/2, y - node_size.y/2)
    
    return positions
```

**Testing**: Generate test maps, verify Y increases with row number

---

### PHASE 3 - MapGenerator Adaptation
**Goal**: Update generator to use new positioning system

**File**: `scripts/map/core/map_generator.gd`

**Changes**:
- [ ] Replace private `_calculate_node_positions` with call to `MapLayoutHelper`
- [ ] Pass fake container size (800×600) for intersection detection
- [ ] No other logic changes - all existing algorithms preserved

**Key Edit**:
```gdscript
# OLD:
var current_positions = _calculate_node_positions(current_layer_nodes, layer_index, layer_counts)

# NEW:
var fake_config = visual_config.duplicate()
fake_config.orientation = "vertical"  # Force vertical for generation
var positions = MapLayoutHelper.compute_positions(temp_map_data, fake_config, Vector2(800, 600))
var current_positions = {}
for node in current_layer_nodes:
    current_positions[node.id] = positions[node.id]
```

**Testing**: Run existing connectivity tests, verify no regressions

---

### PHASE 4 - MapRenderer Refactor
**Goal**: Update visual rendering to use vertical layout

**File**: `scripts/ui/map/map_renderer.gd`

**Major Changes**:
- [ ] Delete `_calculate_layer_positions` and `_create_node_buttons` spacing code
- [ ] Replace with single call to `MapLayoutHelper.compute_positions`
- [ ] Remove `_apply_dashed_effect` (LineDrawer handles this)
- [ ] Add public getters: `get_node_button(id)`, `get_node_screen_pos(id)`

**Key Algorithm Update**:
```gdscript
func render(map_data: MapData, container: Control) -> void:
    # ... existing setup ...
    
    # NEW: Single source of positioning truth
    var positions = MapLayoutHelper.compute_positions(map_data, visual_config, container.size)
    
    # Create buttons at computed positions
    for node_id in positions:
        var node = map_data.get_node(node_id)
        var button = _create_node_button(node, positions[node_id])
        container.add_child(button)
        _node_buttons[node_id] = button
```

**Testing**: Visual regression tests, ensure nodes appear correctly

---

### PHASE 5 - Scroll Container & Auto-Scroll
**Goal**: Add vertical scrolling and smooth navigation

**Files**:
- `scenes/ui/map_view.tscn`
- `scripts/ui/map_view.gd`

**Scene Changes** (`map_view.tscn`):
```
MapView (Control)
└── Background (ColorRect)
└── ScrollRoot (ScrollContainer)           # NEW
    └── MapContainer (Control)             # MOVED INSIDE
└── UIContainer (VBoxContainer)
```

**Script Changes** (`map_view.gd`):
```gdscript
@onready var scroll_container: ScrollContainer = $ScrollRoot
@onready var map_container: Control = $ScrollRoot/MapContainer

func _initialize_or_load_map() -> void:
    # ... existing code ...
    map_renderer.render(current_map_data, map_container)
    
    # NEW: Start at bottom (like Slay the Spire)
    scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value
    
    # NEW: Connect auto-scroll
    map_renderer.node_selected.connect(_center_on_node)

func _center_on_node(node_id: String) -> void:
    var button = map_renderer.get_node_button(node_id)
    if button:
        scroll_container.ensure_control_visible(button)
```

**Testing**: Manual scroll test, auto-scroll on node selection

---

### PHASE 6 - Node Types & Polish
**Goal**: Add proper Slay the Spire node types and visual polish

**Files to Update**:
- `scripts/map/config/map_generation_config.gd`
- `scripts/map/config/minigame_display_names.gd`
- `scripts/ui/map/map_renderer.gd`

**New Node Type System**:
```gdscript
# In map_generation_config.gd
@export var node_type_weights: Dictionary = {
    "normal": 0.50,    # Standard battles
    "elite": 0.08,     # Harder encounters
    "event": 0.15,     # Random events
    "shop": 0.05,      # Upgrade shops
    "rest": 0.10,      # Recovery/buffs
    "mystery": 0.12    # Random outcomes
}

@export var guaranteed_node_rows: Dictionary = {
    "shop": [7],           # Shop on row 7
    "rest": [4, 10, 14],   # Rest sites spread out
    "elite": [6, 12]       # Elite encounters
}
```

**Display Names Update**:
```gdscript
# In minigame_display_names.gd
static var NODE_TYPE_MAPPING = {
    "start": "START",
    "normal": "BATTLE", 
    "elite": "ELITE",
    "event": "EVENT",
    "shop": "SHOP",
    "rest": "REST",
    "mystery": "?",
    "boss": "BOSS"
}
```

**Testing**: Generate maps with new node types, verify distribution

---

### PHASE 7 - Hover Tooltips
**Goal**: Add informative hover tooltips like Slay the Spire

**New File**: `scripts/ui/map/map_tooltip.gd`

**Basic Tooltip System**:
```gdscript
extends PanelContainer
class_name MapTooltip

@onready var title_label: Label = $VBox/TitleLabel
@onready var description_label: Label = $VBox/DescriptionLabel
@onready var voters_label: Label = $VBox/VotersLabel

func show_for_node(node: MapNode, global_pos: Vector2) -> void:
    title_label.text = MinigameDisplayNames.get_display_name(node.node_type)
    description_label.text = _get_node_description(node)
    
    # Show in multiplayer voting context
    if GameManager.is_voting_active():
        voters_label.text = _get_voting_info(node.id)
    
    position = global_pos + Vector2(10, -50)  # Offset from cursor
    show()

func _get_node_description(node: MapNode) -> String:
    match node.node_type:
        "normal": return "Standard battle encounter"
        "elite": return "Challenging battle with better rewards"
        "event": return "Random event - outcomes vary"
        "shop": return "Spend points on upgrades"
        "rest": return "Recover health and gain buffs"
        "mystery": return "Unknown encounter type"
        "boss": return "Final boss battle"
        _: return "Unknown"
```

**Integration in MapRenderer**:
```gdscript
# In _create_node_button
button.mouse_entered.connect(_on_node_hover_start.bind(node))
button.mouse_exited.connect(_on_node_hover_end)

func _on_node_hover_start(node: MapNode) -> void:
    if not tooltip:
        tooltip = MapTooltip.new()
        get_viewport().add_child(tooltip)
    tooltip.show_for_node(node, get_global_mouse_position())

func _on_node_hover_end() -> void:
    if tooltip:
        tooltip.hide()
```

**Testing**: Hover over nodes, verify tooltip content and positioning

---

## 3. RISK AREAS & MITIGATION

### Risk 1: Intersection Detection Assumptions
**Issue**: Line intersection logic assumes certain coordinate ranges
**Mitigation**: 
- Test with 1000+ random seeds after coordinate swap
- Assert no overlapping lines in generated maps
- Keep fallback to simple grid if advanced placement fails

### Risk 2: Scroll Performance on Large Maps
**Issue**: Many nodes and lines could impact frame rate
**Mitigation**:
- Cap line counts at 300 total
- Use LineDrawer's batch drawing system
- Pool tooltip instances

### Risk 3: Save Game Compatibility  
**Issue**: Existing saves might break with data structure changes
**Mitigation**:
- No changes to data schema, only visual rendering
- Keep `layer`/`index` fields as aliases to `row`/`col`
- Test loading existing save files

### Risk 4: Event Signal Flow
**Issue**: ScrollContainer wrapper might interfere with button signals
**Mitigation**:
- Buttons remain direct children of MapContainer
- Test all interaction flows: selection, voting, navigation
- Manual QA for all map interactions

---

## 4. TESTING STRATEGY

### Unit Tests
```gdscript
# test_map_layout_vertical.gd
func test_vertical_positioning():
    var map_data = MapGenerator.generate()
    var positions = MapLayoutHelper.compute_positions(map_data, config, Vector2(800, 600))
    
    # Assert start nodes at bottom
    var start_nodes = map_data.get_nodes_in_row(0)
    var boss_nodes = map_data.get_boss_nodes()
    
    for start in start_nodes:
        for boss in boss_nodes:
            assert(positions[start.id].y > positions[boss.id].y, "Start should be below boss")

func test_no_line_overlaps():
    for i in range(100):  # Test many random seeds
        var map_data = MapGenerator.generate()
        var overlaps = MapLayoutHelper.detect_overlapping_lines(map_data, config)
        assert(overlaps.is_empty(), "No lines should overlap")
```

### Visual Regression Tests
```gdscript
# test_map_visual_regression.gd  
func test_vertical_layout_golden_image():
    var map_data = _create_deterministic_map()
    map_renderer.render(map_data, test_container)
    
    var screenshot = get_viewport().get_texture().get_image()
    var golden = load("res://tests/golden_images/vertical_map.png")
    
    assert_images_similar(screenshot, golden, 0.05)  # 5% tolerance
```

### Integration Tests
```gdscript
# test_map_interaction_flow.gd
func test_scroll_and_select():
    # Generate map, scroll to top, click boss node
    # Verify voting system still works
    # Ensure auto-scroll functions correctly
```

### Manual QA Checklist
- [ ] Mouse wheel scrolling feels natural
- [ ] Drag scrolling works on mobile
- [ ] Starting position is at bottom (row 0)
- [ ] Tooltips appear on hover and disappear on exit
- [ ] Node selection triggers proper voting/navigation
- [ ] Multiplayer voting percentages display correctly
- [ ] Path highlighting works on hover
- [ ] Auto-scroll centers selected nodes
- [ ] Performance remains smooth with large maps (18 rows, 150+ nodes)

---

## 5. ROLLBACK PLAN

If critical issues arise during implementation:

### Quick Rollback (30 minutes)
- [ ] Revert to `master` branch
- [ ] Set `orientation = "horizontal"` in MapVisualConfig 
- [ ] All existing functionality preserved

### Partial Rollback (2 hours)
- [ ] Keep new MapLayoutHelper but use horizontal mode
- [ ] Remove ScrollContainer, restore original scene structure
- [ ] Disable new node types, use existing system

### Data Recovery
- [ ] No data migration needed - save files remain compatible
- [ ] Configuration changes are non-destructive
- [ ] All existing maps can be re-rendered in horizontal mode

---

## 6. SUCCESS METRICS

### Technical Metrics
- [ ] All existing unit tests pass (map generation, navigation, voting)
- [ ] Visual regression tests pass with <5% difference
- [ ] Performance: 60fps with 200+ node maps
- [ ] Memory: No leaks during map regeneration
- [ ] Load time: <500ms for largest maps

### User Experience Metrics  
- [ ] Intuitive bottom-to-top progression
- [ ] Smooth scrolling on all target devices
- [ ] Clear visual hierarchy (start → progress → boss)
- [ ] Informative tooltips aid decision making
- [ ] Multiplayer voting system remains usable

### Compatibility Metrics
- [ ] All existing save files load correctly
- [ ] Multiplayer sessions work across old/new clients (if gradual rollout)
- [ ] Configuration hot-swapping works (horizontal ↔ vertical)

---

## 7. POST-IMPLEMENTATION

### Cleanup Tasks
- [ ] Remove deprecated `layer`/`index` properties (after save compatibility confirmed)
- [ ] Archive old horizontal-specific code 
- [ ] Update documentation and architecture diagrams
- [ ] Performance profiling and optimization

### Future Enhancements
- [ ] Pinch-to-zoom support
- [ ] Controller/gamepad navigation
- [ ] Animated transitions between nodes
- [ ] Particle effects for path completion
- [ ] Sound effects for scrolling and selection

---

## Summary

This refactoring plan preserves 90% of the existing codebase while delivering a complete Slay the Spire map experience. The phased approach minimizes risk and allows for early testing of each component.

**Key Success Factors**:
1. **MapLayoutHelper abstraction** centralizes all positioning logic
2. **Gradual coordinate system migration** maintains existing algorithms  
3. **ScrollContainer integration** provides smooth vertical navigation
4. **Comprehensive testing** ensures no regressions in core functionality

The result will be a polished, vertical map system that feels native to Slay the Spire players while maintaining all of Forked Fates' unique multiplayer features.

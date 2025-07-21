# Forked Fates – "Slay-the-Spire" Map System Design Document

**Version 0.1** – Created via Oracle Analysis  
**Status**: Design Phase - Not Yet Implemented

## Overview

This document outlines the design for transforming Forked Fates' current horizontal map system into a vertical scrolling map that closely mimics Slay the Spire's distinctive progression mechanics while maintaining our multiplayer voting system.

---

## 0. Goal & Non-Goals

### Goals
- Replace the current horizontal, four-row DAG with a vertically scrolling, multi-row, branching map that feels immediately familiar to Slay the Spire players
- Maintain support for Forked Fates' multiplayer voting layer
- Re-use as much of the existing `MapData`, `MapNode`, generator, and renderer scaffolding as possible
- Focus on coordinate system, generation constraints, rendering orientation, and UX polish

### Non-Goals
- New minigame content
- Fancy iconography (we use text circles)
- Persistence/storage changes (those remain unchanged)

---

## 1. Visual Layout

### 1.1 Orientation & Camera
- **Map is taller than the viewport**; player scrolls *upwards* (mouse wheel, drag, game-pad)
- **Row 0 (starts) is at the bottom**; Boss row is at the **top**
- A `ScrollContainer` wraps the `MapContainer` for free kinetic scrolling; `MapRenderer` places nodes using absolute positions
- As in StS, the camera initially shows only the first 4–5 rows; scrolling reveals future choices, creating anticipation

### 1.2 Grid & Coordinates
```gdscript
row_spacing   = 170 # px - vertical distance between rows
col_spacing   = 140 # px - horizontal distance between columns
node_radius   = 32  # px - circles with text
margin_v      = 120 # px - top/bottom breathing room
```

- Each node has integer `(row, col)` plus a computed `Vector2 pos`:
  ```gdscript
  pos = Vector2(col * col_spacing, TotalHeight - row * row_spacing)
  ```
- `TotalHeight = (row_count-1)*row_spacing + margin_v*2`
- Unlike our current system, *row* replaces *layer* (same field in MapNode; only semantics change)

### 1.3 Branch Density Recommendations
- **15–18 rows** for a "run" (~45s of scrolling)
- **1-3 starting nodes**
- **7-10 nodes per middle row**
- **Average 1.8 outgoing edges / node**; guarantee 1 in-edge / node
- Keep lateral drift per edge **≤ 2 columns** to preserve readable paths

---

## 2. Node Types & Behaviour

We replicate StS categories but map them to FF minigames/mechanics. Icons are replaced by colored text inside circles.

| Type    | Text Label | Purpose / Minigame            | Color    |
|---------|------------|-------------------------------|----------|
| Start   | "START"    | Current sudden_death prot.    | Gray     |
| Monster | "BATTLE"   | Standard competitive game     | Red      |
| Elite   | "ELITE"    | Harder variant / bonus pts    | Purple   |
| Event   | "EVENT"    | Skipable RNG micro game       | Blue     |
| Shop    | "SHOP"     | Point spending / power-ups    | Green    |
| Rest    | "REST"     | Recovery or team buff         | Orange   |
| Mystery | "?"        | 50% Event, 50% Monster        | White    |
| Boss    | "BOSS"     | Final multi-round fight       | Dark Red |

### Color Configuration
Colors handled by `MapVisualConfig`:
- Start = visitedColor
- Monster = lockedColor  
- Elite = purple
- Event = blue
- Shop = green
- Rest = orange
- Mystery = white
- Boss = red
- Alpha lowered when disabled

### Node Behavior Extensions
Node behaviour flags to add into MapNode:
```gdscript
@export var reward_pack : RewardDefinition
@export var can_skip    : bool = false   # e.g. Events
```
*Note: These are optional for v0; structure is future-proofed.*

---

## 3. Path Progression Rules

### 3.1 DAG Semantics
- **Edges always point from lower row to higher row** (row+1 .. row+3)
- **No cross-overs that visually intersect** – reuse existing `_lines_intersect` logic
- From a given node players may pick any *child* node
- **Multiplayer rule**: current voting logic stays unchanged – consumes `available_moves` computed from outgoing edges

### 3.2 Generation Algorithm Changes
1. Replace `layer_counts` with `row_counts` (same array)
2. **WHERE TO EDIT**: `map_generator.gd::_calculate_node_positions` and connection functions – compute X from `index`, Y from `row`
3. **Limit lateral jump** when selecting sources/targets: `abs(target.col - source.col) <= 2`
4. **Ensure variability**: for each row guarantee at least:
   - One Rest every 3 rows
   - One Event or Mystery every 3 rows
   - One Shop in rows 5-10
   - One Elite per Act
   - Weights defined in GenerationConfig

### 3.3 Termination
- Player reaches any boss node → run ends
- Dead ends forbidden by connectivity validation (already exists)

---

## 4. Interactive Elements

### 4.1 Hover Feedback
On `mouse_entered` of node button:
- **Show floating Panel (Tooltip)** near cursor with:
  - Node type, expected minigame, potential reward snippet
  - List of teammates who already voted for that node (multiplayer)
- **Highlight the whole path** from current node to hovered node (grey → yellow)
- **Implementation**: DFS on MapData edges storing path ids; LineDrawer recolors those segments

### 4.2 Selection
- **Disabled nodes can't be pressed**
- **Clicking enabled node** immediately calls existing voting or direct move logic (`MapView._on_node_selected`)
- **While voting**, nodes show % votes inside the circle

### 4.3 Scrolling & Zoom
- ScrollContainer as discussed (pinch-zoom optional future work)

### 4.4 Controller Support (Future)
- D-pad up/down selects next row's nearest column
- Left/right cycles within row

---

## 5. Data Structures

Existing classes are sufficient; only small additions needed.

### MapNode.gd Updates
```gdscript
@export var row        : int      # rename layer→row for clarity
@export var col        : int      # was index
@export var node_type  : String   # as listed above
@export var metadata   : Dictionary = {}  # rewards, text, etc.
```
*Note: Keep old `layer`/`index` exported for save compatibility but set them from new fields to avoid disk-breaking; mark as deprecated.*

### MapData.gd Updates
- Add helper `get_nodes_in_row(row:int)` mirroring old API
- `validate_connectivity()` unchanged

### GenerationConfig (TOML/JSON)
```json
{
  "rows": 18,
  "min_nodes_per_row": 5,
  "max_nodes_per_row": 11,
  "special_weights": {
    "event": 0.15,
    "elite": 0.08,
    "shop": 0.05,
    "rest": 0.10,
    "mystery": 0.10
  },
  "ensure_shop_rows": [7],
  "ensure_rest_rows": [4, 10, 14]
}
```
These drive `_get_node_type`.

---

## 6. Rendering Approach

### 6.1 Node Rendering
- Continue using `UIFactory` to spawn `Button` with:
  - `shape_mode = BUTTON_SHAPE_CIRCLE` (Godot 4 supports circle style), or keep rectangular `StyleBoxFlat` with corner_radius = 32
- Center short text label (`type`) inside
- MapRenderer `_get_node_display_text` updated to use new mapping

### 6.2 Positioning
- Replace `layer_spacing` (X) with `col_spacing`
- Y-coord uses `row * row_spacing`; invert so Row 0 is bottom:
  ```gdscript
  y = container_height - margin_v - row * row_spacing
  ```
- MapRenderer recalculates container min_size to `TotalHeight` so the ScrollContainer knows scroll limits

### 6.3 Lines
- Use current `LineDrawer.add_line(...)`
- Dotted for unexplored, solid for visited, highlighted yellow on hover
- Line intersection avoidance works untouched – we just changed points

### 6.4 Performance
- 200–300 lines + 200 nodes < 0.1ms on desktop
- Keep LineDrawer batch drawing
- Recalculate positions only on window resize / map regen

---

## 7. Implementation Phases

### Phase 1: Foundation
- [ ] Create MapLayoutHelper abstraction
- [ ] Add orientation flag to MapVisualConfig
- [ ] Preserve existing horizontal behavior as fallback

### Phase 2: Coordinate System
- [ ] Implement vertical positioning math
- [ ] Update MapGenerator to use new coordinate system
- [ ] Maintain line intersection detection

### Phase 3: Rendering
- [ ] Update MapRenderer for vertical layout
- [ ] Add ScrollContainer to scene
- [ ] Implement auto-scroll functionality

### Phase 4: Node Types
- [ ] Implement new node type system
- [ ] Add proper text labels and colors
- [ ] Update generation weights

### Phase 5: Interactivity
- [ ] Add hover tooltips
- [ ] Implement path highlighting
- [ ] Add voting percentage display

### Phase 6: Polish
- [ ] Performance optimization
- [ ] Controller support
- [ ] QA and testing

**Estimated engineering effort**: 4–5 person-days

---

## References

- [Current Map System Implementation](/Users/cj/Documents/GitHub/Forked_Fates/_docs/mvp_map_system_implementation.md)
- [Slay the Spire Map Analysis](https://steamcommunity.com/sharedfiles/filedetails/?id=1595284439)
- [Godot ScrollContainer Documentation](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html)

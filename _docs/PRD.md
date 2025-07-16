# Forked Fates - Product Requirements Document

## Executive Summary

**Product Name:** Forked Fates  
**Version:** 1.0  
**Target Platform:** PC (Godot 4.4)  
**Genre:** Multiplayer Party Game / Roguelike Progression  

Forked Fates is a networked multiplayer party game that combines Duck Game's chaotic ragdoll physics combat with Slay the Spire's branching map progression system. Players navigate through randomly generated campaigns, competing in various minigames while collecting passive upgrades and earning points toward ultimate victory.

## Product Vision

Create an endlessly replayable party game where every campaign feels unique through random map generation, diverse minigames, and meaningful progression choices that fundamentally alter gameplay through passive upgrades and mutators.

## Target Audience

**Primary:** 16-35 year old gamers who enjoy:
- Local and online multiplayer party games (Gang Beasts, Fall Guys)
- Roguelike progression systems (Risk of Rain, Binding of Isaac)
- Physics-based combat games (Duck Game, Stick Fight)

**Secondary:** Streamers and content creators seeking engaging multiplayer content with high replay value

## Core Game Loop

1. **Campaign Start:** Players begin a new campaign run
2. **Map Navigation:** Vote on next path through branching map
3. **Minigame Execution:** Compete in selected minigame with potential mutators
4. **Reward Distribution:** Winner receives rewards, all players earn points
5. **Progression:** Purchase upgrades, receive random rewards
6. **Repeat:** Continue until campaign completion
7. **Leaderboard:** Final point totals determine campaign winner

## Core Features

### 1. Campaign Progression System

#### 1.1 Branching Map Navigation
- **Randomly generated** Slay the Spire-style maps with branching paths
- **Node types:** Minigames, Shops, Random Events, Boss encounters
- **Democratic voting** system for path selection
- **Winner exclusion:** Previous minigame winner cannot vote on next node
- **Visual progression** showing current position and available paths

#### 1.2 Campaign Structure
- **Session-based:** Complete campaign in single session (30-60 minutes)
- **Escalating difficulty:** Later nodes more challenging
- **Meaningful choices:** Path selection affects available rewards and challenges

### 2. Minigame System

#### 2.1 Core Minigames
- **Sudden Death:** Last-person-standing combat with 3 lives per player
- **Shop:** Physical exploration shop using Binding of Isaac-style layout
- **Extensible framework** for future minigame additions

#### 2.2 Minigame Features
- **Custom arenas** defined per minigame
- **Flexible win conditions** (elimination, scoring, survival, etc.)
- **Dynamic item spawning** with minigame-specific items
- **NPC integration** with configurable AI difficulty and objectives

#### 2.3 Mutator System
- **Minigame-defined mutators** that alter gameplay:
  - **Visual:** Color palette swaps, sprite overrides, lighting changes
  - **Physics:** Low gravity, high speed, bouncy surfaces
  - **Control:** Inverted controls, limited inputs, auto-run
  - **Mechanical:** Modified health, infinite ammo, item restrictions
- **Random application** based on map node or player choice
- **Stackable effects** for compound gameplay changes

### 3. Player Progression

#### 3.1 Passive Upgrade System
- **Binding of Isaac/Risk of Rain inspired** item collection
- **Persistent effects** throughout campaign
- **Stackable upgrades** with synergistic combinations
- **Visual indicators** on player character showing acquired upgrades
- **Categories:**
  - **Combat:** Damage bonuses, attack speed, range improvements
  - **Movement:** Speed boosts, jump height, dash abilities
  - **Defensive:** Health increases, damage reduction, regeneration
  - **Utility:** Item magnetism, faster reload, multi-shot

#### 3.2 Points System
- **Accrual methods** defined by individual minigames:
  - Elimination points, survival time, objective completion
  - Style bonuses, combo multipliers, special achievements
- **Campaign tracking** with persistent point accumulation
- **Multiple currencies** potential (points, special tokens)
- **Leaderboard determination** via final campaign point totals

#### 3.3 Reward Systems
- **Winner rewards:** Minigame victors receive guaranteed high-value rewards
- **Participation rewards:** All players receive baseline progression
- **Random reward events:** Unexpected bonuses throughout campaign
- **Shop purchases:** Spend points for guaranteed upgrades/items
- **Risk/reward balance:** Higher risk paths offer better rewards

### 4. Combat & Physics System

#### 4.1 Player Mechanics
- **Ragdoll physics** with Duck Game-style chaos
- **3-life system** for elimination-based minigames
- **Contextual interactions** with environment and items
- **Responsive controls** with dedicated AI input handling

#### 4.2 Item System
- **Handheld items** that occupy player hands
- **Physics-based** dropping when ragdolled
- **Diverse categories:**
  - **Ranged weapons:** Pistol, shotgun, rifle variants
  - **Melee weapons:** Bat, sword, hammer variants
  - **Utility items:** Grappling hook, shield, throwables
- **Upgrade compatibility** with passive improvement system

#### 4.3 Environmental Interaction
- **Destructible elements** in arenas
- **Interactive objects:** Buttons, platforms, hazards
- **Physics simulation** for emergent gameplay moments

### 5. Shop System

#### 5.1 Physical Shop Minigame
- **Binding of Isaac inspired** 2D exploration space
- **Point-based currency** for purchases
- **Multiple shop layouts** with procedural generation
- **Item categories:**
  - Passive upgrades with immediate effect
  - Temporary campaign bonuses
  - Cosmetic customizations
  - Information/map reveals

#### 5.2 Shop Mechanics
- **Limited time** or interaction-based shopping
- **Dynamic pricing** based on item rarity and player performance
- **Exclusive items** only available in shops
- **Competition elements** for limited stock items

### 6. Voting & Democracy System

#### 6.1 Path Selection Voting
- **Majority rule** determines next map node
- **Winner exclusion:** Previous minigame winner sits out vote
- **Tie-breaking mechanics** via random selection or special conditions
- **Visual voting interface** showing all player choices
- **Time limits** to prevent analysis paralysis

#### 6.2 Democratic Elements
- **Minigame selection** when multiple options available
- **Mutator activation** voting for optional challenges
- **Campaign settings** decided by group consensus

### 7. Network Architecture (Future)

#### 7.1 Multiplayer Foundation
- **4-8 player support** with scalable architecture
- **Dedicated server** model for consistent experience
- **Cross-platform compatibility** consideration
- **Spectator mode** for eliminated players

#### 7.2 Social Features
- **Campaign replay sharing** with unique run IDs
- **Global leaderboards** for various metrics
- **Achievement system** for special accomplishments
- **Friend systems** and party creation

## Technical Requirements

### 8.1 Performance Targets
- **60 FPS** stable with maximum player count
- **<100ms input latency** for responsive controls
- **Deterministic physics** for network synchronization
- **Efficient memory usage** for extended campaign sessions

### 8.2 Platform Specifications
- **Godot 4.4** engine with GDScript
- **Modular architecture** supporting easy content addition
- **Signal-based communication** for clean code separation
- **Resource streaming** for large campaign content

### 8.3 Accessibility
- **Colorblind-friendly** UI and visual design
- **Customizable controls** with multiple input methods
- **Clear visual feedback** for all game state changes
- **Audio cues** for important events

## User Stories

### Core Gameplay
- **As a player,** I want to vote on campaign paths so I can influence the experience
- **As a winner,** I want exclusive rewards so victory feels meaningful
- **As a participant,** I want progression even when losing so I stay engaged
- **As a strategist,** I want to see upgrade synergies so I can plan builds

### Progression
- **As a collector,** I want diverse passive upgrades so each run feels unique
- **As a competitor,** I want point accumulation so I can track my performance
- **As a shopper,** I want spending choices so I can customize my experience
- **As a team player,** I want to influence others' success through voting

### Social
- **As a party host,** I want quick setup so we can start playing immediately
- **As a streamer,** I want spectator features so audiences can follow along
- **As a completionist,** I want tracking systems so I can see my progress

## Success Metrics

### Engagement
- **Session length:** Average campaign duration of 45-60 minutes
- **Retention:** 80% completion rate for started campaigns
- **Replayability:** Average 10+ campaigns per player per month

### Social
- **Party size:** Average 3.5 players per campaign
- **Friend engagement:** 60% of sessions with known players
- **Content sharing:** 20% of campaigns generate shareable moments

### Technical
- **Performance:** 95% of sessions maintain target framerate
- **Stability:** <1% crash rate during campaigns
- **Network:** <50ms average latency in multiplayer sessions

## Monetization Strategy (Future Consideration)

### Cosmetic Content
- **Character customization** options
- **Weapon skins** and visual effects
- **Arena themes** and environmental variants

### Content Expansion
- **Season passes** with new minigames and upgrades
- **Campaign themes** with unique progression paths
- **Premium mutators** and advanced customization

## Risk Assessment

### Technical Risks
- **Physics complexity** may impact performance with multiple players
- **Network synchronization** challenges with ragdoll physics
- **Balance complexity** with numerous interacting upgrade systems

### Design Risks
- **Analysis paralysis** from too many upgrade choices
- **Runaway leaders** dominating through early advantage
- **Session length** potentially too long for casual players

### Mitigation Strategies
- **Iterative testing** with focus groups throughout development
- **Modular implementation** allowing feature adjustment
- **Comprehensive analytics** to track player behavior patterns

## Development Phases

### Phase 1: Core Framework (v0.1)
- Basic game loop without networking
- Simple sudden death minigame
- Foundation systems for all major features

### Phase 2: Content Expansion (v0.2)
- Additional minigames and items
- Complete upgrade system implementation
- Shop system and voting mechanics

### Phase 3: Multiplayer Integration (v0.3)
- Network implementation
- Social features and matchmaking
- Performance optimization

### Phase 4: Polish & Launch (v1.0)
- Content balancing and testing
- Accessibility improvements
- Launch preparation and marketing

## Appendix: Feature Priorities

### Must Have (MVP)
- ✅ Sudden death minigame
- ✅ Basic upgrade system
- ✅ Map progression
- ✅ Voting system
- ✅ Points tracking

### Should Have
- 🎯 Shop system
- 🎯 Multiple minigames
- 🎯 Mutator system
- 🎯 Random rewards
- 🎯 Comprehensive upgrades

### Could Have
- 💭 Advanced AI
- 💭 Spectator mode
- 💭 Replay system
- 💭 Achievement system
- 💭 Cosmetic customization

### Won't Have (v1.0)
- ❌ Persistent progression between campaigns
- ❌ Ranked matchmaking
- ❌ User-generated content
- ❌ Mobile platform support 
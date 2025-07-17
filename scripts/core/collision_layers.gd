class_name CollisionLayers

## Collision Layer Management System
## Centralizes all collision layer and mask definitions for consistent physics setup

# Physics Layer Assignments (bit positions 1-32)
enum Layer {
	NONE = 0,           # No collision layer (for disabling collisions)
	ENVIRONMENT = 1,    # Static world geometry (platforms, walls, ground)
	PLAYERS = 2,        # Player characters (alive and ragdolled)
	ITEMS = 4,          # Pickup items (weapons, consumables)
	PROJECTILES = 8,    # Bullets, grenades, thrown objects
	TRIGGERS = 16,      # Area2D triggers for events, pickups, damage zones
	DESTRUCTIBLES = 32, # Breakable objects in the environment
	# Available slots: 64, 128, 256, 512, 1024, etc.
}

# Common Collision Mask Combinations
enum Mask {
	ENVIRONMENT_ONLY = Layer.ENVIRONMENT,
	PLAYERS_AND_ENVIRONMENT = Layer.ENVIRONMENT | Layer.PLAYERS,
	ITEMS_INTERACTION = Layer.ENVIRONMENT | Layer.PLAYERS,
	PROJECTILE_TARGETS = Layer.ENVIRONMENT | Layer.PLAYERS | Layer.DESTRUCTIBLES,
	ITEM_DETECTION = Layer.ITEMS,
	PLAYER_DETECTION = Layer.PLAYERS,
	ALL_PHYSICS = Layer.ENVIRONMENT | Layer.PLAYERS | Layer.ITEMS | Layer.PROJECTILES | Layer.DESTRUCTIBLES
}

## Set collision layer using enum value
static func set_layer(body: CollisionObject2D, layer: Layer) -> void:
	body.collision_layer = layer

## Set collision mask using enum value(s)
static func set_mask(body: CollisionObject2D, mask: int) -> void:
	body.collision_mask = mask

## Add a layer to existing collision layer
static func add_layer(body: CollisionObject2D, layer: Layer) -> void:
	body.collision_layer |= layer

## Remove a layer from existing collision layer
static func remove_layer(body: CollisionObject2D, layer: Layer) -> void:
	body.collision_layer &= ~layer

## Check if body is on specific layer
static func has_layer(body: CollisionObject2D, layer: Layer) -> bool:
	return (body.collision_layer & layer) != 0

## Add a mask to existing collision mask
static func add_mask(body: CollisionObject2D, mask: int) -> void:
	body.collision_mask |= mask

## Remove a mask from existing collision mask  
static func remove_mask(body: CollisionObject2D, mask: int) -> void:
	body.collision_mask &= ~mask

## Check if body can collide with specific layer
static func can_collide_with(body: CollisionObject2D, layer: Layer) -> bool:
	return (body.collision_mask & layer) != 0

## Disable all collision detection (for cleanup/destruction)
static func disable_all_collisions(body: CollisionObject2D) -> void:
	set_layer(body, Layer.NONE)
	set_mask(body, Layer.NONE)
	
	# Also disable contact monitoring for RigidBody2D (deferred to avoid callback conflicts)
	if body is RigidBody2D:
		var rigid_body: RigidBody2D = body as RigidBody2D
		rigid_body.call_deferred("set_contact_monitor", false)

## Setup player collision (alive state)
static func setup_player(player: CharacterBody2D) -> void:
	set_layer(player, Layer.PLAYERS)
	set_mask(player, Mask.PLAYERS_AND_ENVIRONMENT)

## Setup ragdoll collision (physics body state)
static func setup_ragdoll(ragdoll: RigidBody2D) -> void:
	set_layer(ragdoll, Layer.PLAYERS)
	set_mask(ragdoll, Mask.ENVIRONMENT_ONLY)  # Only collide with environment, not other players

## Setup item collision (world state)
static func setup_item(item: RigidBody2D) -> void:
	set_layer(item, Layer.ITEMS)
	set_mask(item, Mask.ITEMS_INTERACTION)

## Setup projectile collision
static func setup_projectile(projectile: RigidBody2D) -> void:
	set_layer(projectile, Layer.PROJECTILES)
	set_mask(projectile, Mask.PROJECTILE_TARGETS)

## Setup pickup area (Area2D for item detection)
static func setup_pickup_area(area: Area2D) -> void:
	set_layer(area, Layer.NONE)  # Areas don't need layers, only masks
	set_mask(area, Mask.ITEM_DETECTION)

## Setup attack area (Area2D for weapon attacks)
static func setup_attack_area(area: Area2D) -> void:
	set_layer(area, Layer.NONE)
	set_mask(area, Mask.PLAYER_DETECTION)

## Get human-readable layer names for debugging
static func get_layer_name(layer: int) -> String:
	var names: Array[String] = []
	
	if layer & Layer.ENVIRONMENT:
		names.append("ENVIRONMENT")
	if layer & Layer.PLAYERS:
		names.append("PLAYERS")
	if layer & Layer.ITEMS:
		names.append("ITEMS")
	if layer & Layer.PROJECTILES:
		names.append("PROJECTILES")
	if layer & Layer.TRIGGERS:
		names.append("TRIGGERS")
	if layer & Layer.DESTRUCTIBLES:
		names.append("DESTRUCTIBLES")
	
	return " | ".join(names) if names.size() > 0 else "NONE"

## Debug collision setup
static func debug_collision_setup(body: CollisionObject2D, name: String = "") -> void:
	var body_name: String = name if name != "" else str(body)
	Logger.debug("Collision Debug for " + body_name, "CollisionLayers")
	Logger.debug("Layer: " + get_layer_name(body.collision_layer) + " (" + str(body.collision_layer) + ")", "CollisionLayers")
	Logger.debug("Mask: " + get_layer_name(body.collision_mask) + " (" + str(body.collision_mask) + ")", "CollisionLayers") 

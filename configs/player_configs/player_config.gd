class_name PlayerConfig
extends Resource
 
@export var player_name: String = ""
@export var player_scene: PackedScene
@export var special_abilities: Array[String] = []

# Health settings - basic properties instead of separate class
@export_group("Health Settings")
@export var max_health: int = 3
@export var regen_rate: float = 0.0
@export var damage_resistance: float = 0.0

# Movement settings - basic properties instead of separate class  
@export_group("Movement Settings")
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0 
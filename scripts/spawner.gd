extends Node3D

const SPAWN_INTERVAL := 1.5
const MAX_ENEMIES := 200

var player: Node3D
var enemy_paths: Array = []
var timer: float = 0.0
var elapsed_time: float = 0.0

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	elapsed_time += delta
	timer += delta
	var interval := maxf(0.45, SPAWN_INTERVAL - elapsed_time * 0.005)
	if timer < interval:
		return
	timer = 0.0
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.size() >= MAX_ENEMIES:
		return
	_spawn_one()

func _spawn_one() -> void:
	if enemy_paths.is_empty():
		print("spawner: no enemy paths")
		return
	var idx := randi() % enemy_paths.size()
	var scene := load(enemy_paths[idx]) as PackedScene
	if not scene:
		return
	var body := CharacterBody3D.new()
	body.position = _random_edge_position()
	var visual: Node3D = scene.instantiate() as Node3D
	visual.scale = Vector3(2.5, 2.5, 2.5)
	body.add_child(visual)
	body.set_script(load("res://scripts/zombie.gd"))
	body.set("speed_scale", minf(1.8, 1.0 + elapsed_time * 0.002))
	add_child(body)
	body.add_to_group("enemy")
	body.set("target", player)

func _random_edge_position() -> Vector3:
	var angle := randf_range(0.0, TAU)
	var distance := randf_range(20.0, 27.0)
	var spawn_position := player.global_position + Vector3(cos(angle), 0, sin(angle)) * distance
	spawn_position.x = clampf(spawn_position.x, -185.0, 185.0)
	spawn_position.z = clampf(spawn_position.z, -185.0, 185.0)
	return spawn_position
extends Node3D

var direction := Vector3.FORWARD
var damage := 10
var tint := Color.WHITE
var projectile_speed := 18.0
var hit_radius := 0.8
var source_player: Node3D
var lifetime := 4.0

func _ready() -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	orb.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	orb.material_override = material
	add_child(orb)

func _physics_process(delta: float) -> void:
	global_position += direction * projectile_speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var enemy := enemy_node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue
		var hit_position := enemy.global_position + Vector3(0, 1.0, 0)
		if global_position.distance_to(hit_position) > hit_radius:
			continue
		if enemy.has_method("take_damage"):
			var defeated: bool = enemy.take_damage(damage)
			if is_instance_valid(source_player):
				source_player.call("register_kill", defeated)
		queue_free()
		return

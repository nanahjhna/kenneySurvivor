extends CharacterBody3D

const SPEED := 4.5
var target: Node3D

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	add_child(col)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := (target.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.1:
		dir = dir.normalized()
		velocity = dir * SPEED
		move_and_slide()
		look_at(global_position + dir, Vector3.UP)

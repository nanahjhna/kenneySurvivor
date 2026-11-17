extends CharacterBody3D

const SPEED := 3.5

var target: Node3D
var speed_scale := 1.0
var hp := 30
var max_hp := 30
var xp_value := 5
var is_dead := false
var animation_player: AnimationPlayer
var action_timer := 0.0
var active_animation := ""

func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 3.2
	col.shape = cap
	col.position = Vector3(0, 0.8, 0)
	add_child(col)

	var animation_nodes := find_children("*", "AnimationPlayer", true, false)
	if not animation_nodes.is_empty():
		animation_player = animation_nodes[0] as AnimationPlayer
		_play_animation("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	action_timer = maxf(0.0, action_timer - delta)
	if action_timer > 0.0:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not is_instance_valid(target):
		_play_animation("idle")
		return

	var direction := target.global_position - global_position
	direction.y = 0
	if direction.length() <= 0.1:
		velocity = Vector3.ZERO
		_play_animation("idle")
		return

	var distance := direction.length()
	direction = direction.normalized()
	velocity = direction * SPEED * speed_scale
	move_and_slide()
	look_at(global_position + direction, Vector3.UP)
	if distance < 10.0 or speed_scale > 1.3:
		_play_animation("sprint")
	else:
		_play_animation("walk", 0.85)

func _play_animation(animation_name: String, speed: float = 1.0, restart: bool = false) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	if not restart and active_animation == animation_name and animation_player.is_playing():
		return
	if restart:
		animation_player.stop()
	active_animation = animation_name
	animation_player.play(animation_name, 0.08, speed)

func _play_action(animation_name: String, duration: float, speed: float = 1.0) -> void:
	action_timer = duration
	_play_animation(animation_name, speed, true)

func attack_player() -> void:
	if not is_dead:
		_play_action("attack-melee-right", 0.45, 1.2)

func take_damage(amount: int) -> bool:
	if is_dead:
		return false
	hp -= amount
	if hp <= 0:
		die()
		return true
	_play_action("fall", 0.25, 1.4)
	return false

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	if animation_player and animation_player.has_animation("die"):
		_play_animation("die", 1.0, true)
		await get_tree().create_timer(animation_player.get_animation("die").length).timeout
	_drop_xp_gem()
	queue_free()

func _drop_xp_gem() -> void:
	var gem := MeshInstance3D.new()
	gem.mesh = SphereMesh.new()
	(gem.mesh as SphereMesh).radius = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	gem.material_override = mat
	var body := StaticBody3D.new()
	body.add_child(gem)
	body.position = global_position + Vector3(0, 0.5, 0)
	body.add_to_group("xp_gem")
	body.set_meta("value", xp_value)
	get_parent().add_child(body)

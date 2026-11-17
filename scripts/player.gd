extends CharacterBody3D

signal hp_changed(hp, max_hp)
signal xp_changed(xp, xp_to_next, level)
signal kills_changed(kills)
signal stamina_changed(stamina, max_stamina)
signal died

const WALK_SPEED := 4.0
const RUN_SPEED := 8.0
const SPRINT_SPEED := 13.0
const WORLD_LIMIT := 190.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 32.0
const STAMINA_RECOVERY := 24.0
const SKILL_COOLDOWN := 8.0
const BOLT_COOLDOWN := 2.4
const VOLLEY_COOLDOWN := 5.0
const SKILL_PROJECTILE := preload("res://scripts/skill_projectile.gd")
const ANIMATIONS := {
	"idle": "Breathing_Idle_RT",
	"walk": "Walking_RT",
	"run": "Running_RT",
	"sprint": "Sprint_Forward_RT",
	"attack": "Great_Sword_Attack_RT",
	"cast": "Standing_2H_Magic_Area_Attack_02_RT",
	"bolt": "Standing_1H_Magic_Attack_01_RT",
	"volley": "Standing_1H_Magic_Attack_03_RT",
	"hit": "Getting_Hit_RT",
	"die": "Death_A_RT",
}

var hp := 100
var max_hp := 100
var xp := 0
var level := 1
var xp_to_next := 20
var kills := 0
var attack_damage := 10
var attack_radius := 2.5
var attack_cooldown := 0.5
var attack_timer := 0.0
var invuln := 0.0
var is_dead := false
var stamina := MAX_STAMINA
var skill_cooldown := 0.0
var bolt_cooldown := 0.0
var volley_cooldown := 0.0
var animation_player: AnimationPlayer
var action_timer := 0.0
var knockback_velocity := Vector3.ZERO
var active_animation := ""
var active_animation_speed := 1.0
var skill_key_state: Dictionary = {}

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

	var wscene := load(
		"res://assets/kenney_mini-characters/Models/GLB format/weapon-sword.glb"
	) as PackedScene
	if wscene:
		var weapon := wscene.instantiate() as Node3D
		weapon.position = Vector3(0.6, 1.0, 0)
		weapon.rotation_degrees = Vector3(0, 0, -45)
		add_child(weapon)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	action_timer = maxf(0.0, action_timer - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	bolt_cooldown = maxf(0.0, bolt_cooldown - delta)
	volley_cooldown = maxf(0.0, volley_cooldown - delta)
	if invuln > 0.0:
		invuln = maxf(0.0, invuln - delta)

	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input.z += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input.z -= 1
	if input.length() > 0:
		input = input.normalized()

	var locked := action_timer > 0.0
	var walking := Input.is_key_pressed(KEY_CTRL)
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and not walking and stamina > 0.0
	var move_speed := 0.0
	var move_animation := "idle"
	if input.length() > 0 and not locked:
		if sprinting:
			move_speed = SPRINT_SPEED
			move_animation = "sprint"
		elif walking:
			move_speed = WALK_SPEED
			move_animation = "walk"
		else:
			move_speed = RUN_SPEED
			move_animation = "run"

	var previous_stamina := stamina
	if sprinting and input.length() > 0 and not locked:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
	else:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_RECOVERY * delta)
	if int(previous_stamina) != int(stamina):
		stamina_changed.emit(stamina, MAX_STAMINA)

	velocity = input * move_speed + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 18.0 * delta)
	global_position.x = clampf(global_position.x, -WORLD_LIMIT, WORLD_LIMIT)
	global_position.z = clampf(global_position.z, -WORLD_LIMIT, WORLD_LIMIT)
	if input.length() > 0 and not locked:
		look_at(global_position + input, Vector3.UP)
	if action_timer <= 0.0:
		_play_locomotion(move_animation)

	var cast_shockwave := _key_just_pressed(KEY_Q)
	var cast_bolt := _key_just_pressed(KEY_E)
	var cast_volley := _key_just_pressed(KEY_R)
	if cast_shockwave and skill_cooldown <= 0.0:
		_cast_skill()
	elif cast_bolt and bolt_cooldown <= 0.0:
		_cast_bolt()
	elif cast_volley and volley_cooldown <= 0.0:
		_cast_volley()

	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_cooldown
		_do_attack()

	_collect_xp()
	_check_zombie_contact()

func _play_animation(animation_name: String, speed: float = 1.0, restart: bool = false) -> void:
	var clip_name: String = ANIMATIONS.get(animation_name, animation_name)
	if animation_player == null or not animation_player.has_animation(clip_name):
		return
	if not restart and active_animation == animation_name and animation_player.is_playing():
		if is_equal_approx(active_animation_speed, speed):
			return
	if restart:
		animation_player.stop()
	elif active_animation == animation_name:
		animation_player.stop()
	active_animation = animation_name
	active_animation_speed = speed
	animation_player.play(clip_name, 0.08, speed)

func _play_locomotion(state: String) -> void:
	match state:
		"idle":
			_play_animation("idle")
		"walk":
			_play_animation("walk", 0.75)
		"run":
			_play_animation("run")
		"sprint":
			_play_animation("sprint", 1.15)

func _play_action(animation_name: String, duration: float, speed: float = 1.0) -> void:
	action_timer = duration
	_play_animation(animation_name, speed, true)

func _do_attack() -> void:
	if action_timer > 0.0:
		return
	var nearest: Node3D
	var nearest_distance := attack_radius
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var enemy := enemy_node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := enemy.global_position.distance_to(global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest and nearest.has_method("take_damage"):
		_play_action("attack", 0.55, 1.1)
		register_kill(nearest.take_damage(attack_damage))

func _cast_skill() -> void:
	skill_cooldown = SKILL_COOLDOWN
	_play_action("cast", 0.8)
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var enemy := enemy_node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) <= 6.0:
			if enemy.has_method("take_damage"):
				register_kill(enemy.take_damage(25 + level * 2))

func _cast_bolt() -> void:
	bolt_cooldown = BOLT_COOLDOWN
	_play_action("bolt", 0.55, 1.1)
	_launch_projectile(
		_aim_direction(),
		28 + level * 4,
		Color(0.35, 0.8, 1.0),
		22.0,
		0.9
	)

func _cast_volley() -> void:
	volley_cooldown = VOLLEY_COOLDOWN
	_play_action("volley", 0.7, 1.1)
	var direction := _aim_direction()
	for angle in [-28.0, -14.0, 0.0, 14.0, 28.0]:
		_launch_projectile(
			direction.rotated(Vector3.UP, deg_to_rad(angle)),
			14 + level * 2,
			Color(1.0, 0.48, 0.16),
			17.0,
			0.65
		)

func _aim_direction() -> Vector3:
	var nearest: Node3D
	var nearest_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var enemy := enemy_node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead"):
			continue
		var distance := enemy.global_position.distance_to(global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	var direction := -global_basis.z
	if nearest:
		direction = nearest.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.0 else Vector3.FORWARD

func _launch_projectile(
	direction: Vector3,
	damage: int,
	tint: Color,
	projectile_speed: float,
	hit_radius: float
) -> void:
	var projectile := SKILL_PROJECTILE.new() as Node3D
	projectile.set("direction", direction.normalized())
	projectile.set("damage", damage)
	projectile.set("tint", tint)
	projectile.set("projectile_speed", projectile_speed)
	projectile.set("hit_radius", hit_radius)
	projectile.set("source_player", self)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector3(0, 1.1, 0) + direction * 0.8

func _key_just_pressed(keycode: int) -> bool:
	var pressed := Input.is_key_pressed(keycode)
	var was_pressed: bool = skill_key_state.get(keycode, false)
	skill_key_state[keycode] = pressed
	return pressed and not was_pressed

func register_kill(defeated: bool) -> void:
	if defeated:
		kills += 1
		kills_changed.emit(kills)

func _collect_xp() -> void:
	for gem_node in get_tree().get_nodes_in_group("xp_gem"):
		var gem := gem_node as Node3D
		if gem == null or not is_instance_valid(gem):
			continue
		if gem.global_position.distance_to(global_position) < 2.0:
			xp += int(gem.get_meta("value", 5))
			gem.queue_free()
			_check_levelup()

func _check_levelup() -> void:
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.5)
		attack_damage += 3
		attack_cooldown = maxf(0.2, attack_cooldown - 0.05)
		max_hp += 5
		hp = mini(max_hp, hp + 20)
	xp_changed.emit(xp, xp_to_next, level)
	hp_changed.emit(hp, max_hp)

func _check_zombie_contact() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		var enemy := enemy_node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) >= 1.2 or invuln > 0.0:
			continue
		if enemy.has_method("attack_player"):
			enemy.attack_player()
		hp = maxi(0, hp - 10)
		invuln = 1.0
		hp_changed.emit(hp, max_hp)
		if hp <= 0:
			_die()
			return
		var knockback := global_position - enemy.global_position
		knockback.y = 0
		if knockback.length_squared() > 0.0:
			knockback_velocity = knockback.normalized() * 6.0
		_play_action("hit", 0.35, 1.4)

func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	var death_clip: String = ANIMATIONS["die"]
	if animation_player and animation_player.has_animation(death_clip):
		_play_animation("die", 1.0, true)
		await get_tree().create_timer(animation_player.get_animation(death_clip).length).timeout
	died.emit()

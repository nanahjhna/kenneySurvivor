extends Node3D

## 3D mobile defense prototype. GLB actors are real Node3D instances in one world.

const START_GOLD := 180
const START_HP := 100
const TRACK_HALF_X := 6.25
const TRACK_HALF_Z := 9.8
const TRACK_WIDTH := 2.2
const ROUTE_OFFSET := 0.59735
const SLOT_COLUMNS := 3
const SLOT_ROWS := 4
const SLOT_SPACING_X := 2.9
const SLOT_SPACING_Z := 3.6
const SLOT_SIZE := 2.45
const MODEL_PATHS := {
	"turret": "res://assets/kenney_tower-defense-kit/Models/GLB format/weapon-turret.glb",
	"cannon": "res://assets/kenney_tower-defense-kit/Models/GLB format/weapon-cannon.glb",
	"catapult": "res://assets/kenney_tower-defense-kit/Models/GLB format/weapon-catapult.glb",
	"ballista": "res://assets/kenney_tower-defense-kit/Models/GLB format/weapon-ballista.glb",
	"zombie": "res://assets/kenney_mini-characters/Models/GLB format/character-zombie.glb",
}
const TURRETS := {
	"기관총": {"model": "turret", "cost": 70, "range": 5.6, "damage": 8.0, "rate": 0.42, "color": Color("#ffb347")},
	"곡사포": {"model": "cannon", "cost": 110, "range": 7.1, "damage": 27.0, "rate": 1.55, "color": Color("#ff6b6b")},
	"투석기": {"model": "catapult", "cost": 100, "range": 6.7, "damage": 22.0, "rate": 1.25, "color": Color("#e6a867")},
	"발리스타": {"model": "ballista", "cost": 90, "range": 6.3, "damage": 17.0, "rate": 0.9, "color": Color("#80c8ef")},
}

var gold := START_GOLD
var base_hp := START_HP
var wave := 0
var kills := 0
var phase := "ready"
var spawn_left := 0
var spawn_clock := 0.0
var intermission := 0.0
var zombies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var slots: Array[Dictionary] = []
var hero: Node3D
var hero_marker: MeshInstance3D
var hero_progress := 0.28
var hero_attack_clock := 0.0
var hero_skill_clock := 0.0
var selected_slot := -1
var camera: Camera3D
var world_root: Node3D
var hud_layer: CanvasLayer
var gold_label: Label
var wave_label: Label
var status_label: Label
var hp_bar: ProgressBar
var build_panel: PanelContainer
var manage_row: HBoxContainer
var result_overlay: Control
var zombie_scene: PackedScene
var turret_scenes: Dictionary = {}
var phase_clock := 0.0
var outcome := ""

func _ready() -> void:
	_setup_environment()
	_setup_battlefield()
	_setup_scenery()
	_load_models()
	_setup_slots()
	_setup_hero()
	_setup_camera()
	_setup_hud()
	_begin_wave()

func _process(delta: float) -> void:
	if not outcome.is_empty():
		return
	_update_zombies(delta)
	_update_turrets(delta)
	_update_projectiles(delta)
	_update_hero(delta)
	_update_waves(delta)
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if not outcome.is_empty():
		return
	if event is InputEventScreenTouch and event.pressed:
		_handle_world_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_world_tap(event.position)

func _setup_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111923")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b7c8d8")
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	add_child(environment_node)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-56, -28, 0)
	sunlight.light_energy = 1.35
	sunlight.shadow_enabled = true
	add_child(sunlight)

func _setup_battlefield() -> void:
	world_root = Node3D.new()
	world_root.name = "Battlefield"
	add_child(world_root)
	_add_box(world_root, Vector3(0, -0.43, 0), Vector3(40, 0.2, 40), Color("#111923"))
	_add_rounded_platform_rect(world_root, Vector3(0, -0.14, 0), Vector2(15.0, 24.5), 0.42, 1.35, Color("#1d2939"))
	_add_rounded_outline_rect(Vector2(15.0, 24.5), 1.35, 0.035, Color("#3b4c60"), 0.10)
	# Four paved sides and dotted lane markings form one continuous loop.
	_add_box(world_root, Vector3(0, 0.095, -TRACK_HALF_Z), Vector3(TRACK_HALF_X * 2.0, 0.08, TRACK_WIDTH), Color("#3a4149"))
	_add_box(world_root, Vector3(0, 0.095, TRACK_HALF_Z), Vector3(TRACK_HALF_X * 2.0, 0.08, TRACK_WIDTH), Color("#3a4149"))
	_add_box(world_root, Vector3(-TRACK_HALF_X, 0.095, 0), Vector3(TRACK_WIDTH, 0.08, TRACK_HALF_Z * 2.0), Color("#3a4149"))
	_add_box(world_root, Vector3(TRACK_HALF_X, 0.095, 0), Vector3(TRACK_WIDTH, 0.08, TRACK_HALF_Z * 2.0), Color("#3a4149"))
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_add_cylinder(world_root, Vector3(x_side * TRACK_HALF_X, 0.095, z_side * TRACK_HALF_Z), Vector3(TRACK_WIDTH, 0.08, TRACK_WIDTH), Color("#3a4149"))
	for i in range(11):
		var step_x := -TRACK_HALF_X + 0.55 + float(i) * (TRACK_HALF_X * 2.0 - 1.1) / 10.0
		var step_z := -TRACK_HALF_Z + 0.55 + float(i) * (TRACK_HALF_Z * 2.0 - 1.1) / 10.0
		for z_side in [-1.0, 1.0]:
			_add_box(world_root, Vector3(step_x, 0.145, z_side * TRACK_HALF_Z), Vector3(0.22, 0.025, 0.035), Color("#65717a"))
		for x_side in [-1.0, 1.0]:
			_add_box(world_root, Vector3(x_side * TRACK_HALF_X, 0.145, step_z), Vector3(0.035, 0.025, 0.22), Color("#65717a"))
	# The raised tower yard meets the road's inner curb so there is no dead strip.
	_add_rounded_platform_rect(world_root, Vector3(0, 0.12, 0), Vector2(10.3, 17.4), 0.30, 0.52, Color("#0e151e"))
	_add_rounded_platform_rect(world_root, Vector3(0, 0.29, 0), Vector2(10.0, 17.1), 0.22, 0.38, Color("#192638"))
	_add_rounded_outline_rect(Vector2(9.9, 17.0), 0.38, 0.035, Color("#937c4e"), 0.43)
	_add_box(world_root, Vector3(0, 0.43, 0), Vector3(9.4, 0.06, 16.5), Color("#111b2a"))
	# Red exit gate on the lower edge of the circuit.
	for side in [-1.0, 1.0]:
		_add_cylinder(world_root, Vector3(side * 0.42, 0.45, TRACK_HALF_Z + 0.62), Vector3(0.18, 0.9, 0.18), Color("#dc6671"))
	_add_box(world_root, Vector3(0, 0.9, TRACK_HALF_Z + 0.62), Vector3(0.95, 0.13, 0.16), Color("#ef7781"))

func _load_models() -> void:
	zombie_scene = load(MODEL_PATHS.zombie) as PackedScene
	for key in ["turret", "cannon", "catapult", "ballista"]:
		turret_scenes[key] = load(MODEL_PATHS[key]) as PackedScene
	if zombie_scene == null:
		push_error("character-zombie.glb를 불러오지 못했습니다.")
	for key in turret_scenes:
		if turret_scenes[key] == null:
			push_error("포탑 GLB 로드 실패: %s" % MODEL_PATHS[key])

func _setup_scenery() -> void:
	var house_paths := [
		"res://assets/kenney_city-kit-suburban_20/Models/GLB format/building-type-a.glb",
		"res://assets/kenney_city-kit-suburban_20/Models/GLB format/building-type-f.glb",
		"res://assets/kenney_city-kit-suburban_20/Models/GLB format/building-type-m.glb",
		"res://assets/kenney_city-kit-suburban_20/Models/GLB format/building-type-r.glb",
	]
	var house_positions := [
		Vector3(-4.1, 0.08, -11.55), Vector3(4.1, 0.08, -11.55),
		Vector3(-4.1, 0.08, 11.55), Vector3(4.1, 0.08, 11.55),
	]
	for i in range(house_positions.size()):
		_place_glb(house_paths[i], house_positions[i], Vector3.ONE * 1.3, [0.0, PI, PI * 0.5, -PI * 0.5][i])
	# Street trees and lamps break up the empty side margins.
	var tree_path := "res://assets/kenney_city-kit-suburban_20/Models/GLB format/tree-large.glb"
	var tree_positions := [
		Vector3(-6.95, 0.08, -11.65), Vector3(6.95, 0.08, -11.65),
		Vector3(-6.95, 0.08, 11.65), Vector3(6.95, 0.08, 11.65),
	]
	for i in range(tree_positions.size()):
		_place_glb(tree_path, tree_positions[i], Vector3.ONE * 3.0, float(i) * 0.7)
	var lamp_path := "res://assets/kenney_city-kit-roads/Models/GLB format/light-curved.glb"
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_place_glb(lamp_path, Vector3(x_side * 5.75, 0.08, z_side * 11.5), Vector3.ONE * 3.3, 0.0 if x_side < 0 else PI)
	# Low fencing outlines the enlarged tower yard without blocking its 12 pads.
	var fence_path := "res://assets/kenney_city-kit-suburban_20/Models/GLB format/fence-low.glb"
	for x_side in [-1.0, 1.0]:
		for z in [-5.4, -2.7, 0.0, 2.7, 5.4]:
			_place_glb(fence_path, Vector3(x_side * 4.78, 0.47, z), Vector3.ONE * 0.82, PI * 0.5)
	for z_side in [-1.0, 1.0]:
		for x in [-2.7, 0.0, 2.7]:
			_place_glb(fence_path, Vector3(x, 0.47, z_side * 8.18), Vector3.ONE * 0.82, 0.0)
	# A few roadworks props and rubble make the circuit feel like a defended city block.
	var barrier_path := "res://assets/kenney_city-kit-roads/Models/GLB format/road-side-barrier.glb"
	for x in [-2.2, 2.2]:
		_place_glb(barrier_path, Vector3(x, 0.15, -10.95), Vector3.ONE * 1.15, 0.0)
		_place_glb(barrier_path, Vector3(x, 0.15, 10.95), Vector3.ONE * 1.15, PI)
	var sign_path := "res://assets/kenney_city-kit-roads/Models/GLB format/road-sign-warning.glb"
	_place_glb(sign_path, Vector3(-1.2, 0.14, 11.75), Vector3.ONE * 2.3, 0.0)
	var rubble_path := "res://assets/kenney_tower-defense-kit/Models/GLB format/detail-rocks.glb"
	for p in [Vector3(-4.85, 0.55, -7.4), Vector3(4.85, 0.55, -7.4), Vector3(-4.85, 0.55, 7.4), Vector3(4.85, 0.55, 7.4)]:
		_place_glb(rubble_path, p, Vector3.ONE * 0.45, 0.2)

func _place_glb(path: String, pos: Vector3, model_scale: Vector3, yaw: float) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("장식 에셋을 불러오지 못했습니다: %s" % path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_warning("3D 에셋이 Node3D가 아닙니다: %s" % path)
		return null
	instance.position = pos
	instance.scale = model_scale
	instance.rotation.y = yaw
	world_root.add_child(instance)
	return instance

func _setup_slots() -> void:
	for i in range(SLOT_COLUMNS * SLOT_ROWS):
		var col := i % SLOT_COLUMNS
		var row := int(i / SLOT_COLUMNS)
		var pos := Vector3((float(col) - 1.0) * SLOT_SPACING_X, 0, (float(row) - 1.5) * SLOT_SPACING_Z)
		var reserved_core := false
		var unlocked := i in [1, 4, 7, 10]
		var pad := _add_box(world_root, pos + Vector3(0, 0.51, 0), Vector3(SLOT_SIZE, 0.12, SLOT_SIZE), Color("#172333") if unlocked or reserved_core else Color("#202a36"))
		var edge := _add_box(world_root, pos + Vector3(0, 0.45, 0), Vector3(SLOT_SIZE + 0.10, 0.055, SLOT_SIZE + 0.10), Color("#35475c"))
		var plus_root := Node3D.new()
		plus_root.position = pos + Vector3(0, 0.60, 0)
		world_root.add_child(plus_root)
		_add_box(plus_root, Vector3(0, 0, 0), Vector3(0.42, 0.045, 0.055), Color("#56677a") if unlocked else Color("#313e4c"))
		_add_box(plus_root, Vector3(0, 0, 0), Vector3(0.055, 0.045, 0.42), Color("#56677a") if unlocked else Color("#313e4c"))
		plus_root.visible = not reserved_core
		slots.append({"position": pos, "unlocked": unlocked, "reserved": reserved_core, "turret": null, "pad": pad, "edge": edge, "plus": plus_root})

func _setup_hero() -> void:
	hero = Node3D.new()
	hero.name = "Guardian"
	world_root.add_child(hero)
	var body := CapsuleMesh.new()
	body.radius = 0.25
	body.height = 1.05
	var body_node := MeshInstance3D.new()
	body_node.mesh = body
	body_node.position.y = 0.55
	body_node.material_override = _material(Color("#45d8a7"), 0.2)
	hero.add_child(body_node)
	var head := _add_sphere(hero, Vector3(0, 1.18, 0), 0.22, Color("#def4dc"))
	var weapon := _add_box(hero, Vector3(0.32, 0.65, 0), Vector3(0.12, 0.72, 0.12), Color("#d4e4ef"))
	hero_marker = _add_ring_mesh(world_root, Vector3.ZERO, 0.55, 0.07, Color("#58f0e9"))
	_update_hero_transform()

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FixedPortraitCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 26.0
	camera.position = Vector3(0, 22, 18)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

func _setup_hud() -> void:
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(root)
	var top := PanelContainer.new()
	top.anchor_left = 0.04
	top.anchor_right = 0.96
	top.anchor_top = 0.018
	top.anchor_bottom = 0.145
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.09, 0.10, 0.92)))
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 2)
	top.add_child(top_box)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top_box.add_child(top_row)
	wave_label = _label("WAVE 1 / 5", 17, Color("#f3d789"))
	top_row.add_child(wave_label)
	gold_label = _label("◆ %d" % gold, 16, Color("#f3d789"))
	top_row.add_child(gold_label)
	status_label = _label("준비", 12, Color("#cfdae5"))
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(status_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 14)
	hp_bar.max_value = START_HP
	hp_bar.value = START_HP
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", _flat_style(Color("#263342"), 7))
	hp_bar.add_theme_stylebox_override("fill", _flat_style(Color("#ed6a67"), 7))
	top_box.add_child(hp_bar)
	top_box.add_child(_label("기지 내구도", 10, Color("#aebbc9")))
	build_panel = PanelContainer.new()
	build_panel.anchor_left = 0.035
	build_panel.anchor_right = 0.965
	build_panel.anchor_top = 0.825
	build_panel.anchor_bottom = 0.965
	build_panel.visible = false
	build_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.09, 0.10, 0.96)))
	root.add_child(build_panel)
	var build_box := VBoxContainer.new()
	build_box.add_theme_constant_override("separation", 4)
	build_panel.add_child(build_box)
	build_box.add_child(_label("포탑 선택", 14, Color("#f3d789")))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 5)
	build_box.add_child(cards)
	for turret_name in TURRETS:
		var data: Dictionary = TURRETS[turret_name]
		var button := Button.new()
		button.text = "%s\n%dG" % [turret_name, data.cost]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 55)
		button.pressed.connect(_build_selected.bind(turret_name))
		cards.add_child(button)
	manage_row = HBoxContainer.new()
	manage_row.anchor_left = 0.04
	manage_row.anchor_right = 0.96
	manage_row.anchor_top = 0.84
	manage_row.anchor_bottom = 0.96
	manage_row.visible = false
	manage_row.add_theme_constant_override("separation", 8)
	root.add_child(manage_row)
	var upgrade := Button.new()
	upgrade.text = "강화"
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade.pressed.connect(_upgrade_selected)
	manage_row.add_child(upgrade)
	var sell := Button.new()
	sell.text = "판매"
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.pressed.connect(_sell_selected)
	manage_row.add_child(sell)
	var hint := _label("슬롯 터치: 건설  ·  도로 터치: 영웅 이동", 10, Color("#c8d3df"))
	hint.anchor_left = 0.03
	hint.anchor_right = 0.97
	hint.anchor_top = 0.967
	hint.anchor_bottom = 0.998
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	result_overlay = _make_result_overlay(root)

func _make_result_overlay(parent: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.01, 0.02, 0.04, 0.82)
	overlay.visible = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := _label("", 24, Color("#f3d789"))
	title.name = "ResultTitle"
	box.add_child(title)
	var restart := Button.new()
	restart.text = "다시 시작"
	restart.pressed.connect(_restart)
	box.add_child(restart)
	return overlay

func _handle_world_tap(screen_pos: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if point == null:
		_close_panels()
		selected_slot = -1
		return
	var p: Vector3 = point
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		if slot.reserved:
			continue
		if Vector2(p.x, p.z).distance_to(Vector2(slot.position.x, slot.position.z)) < SLOT_SIZE * 0.42:
			_select_slot(i)
			return
	var on_horizontal_road := absf(absf(p.z) - TRACK_HALF_Z) < TRACK_WIDTH and absf(p.x) < TRACK_HALF_X + TRACK_WIDTH
	var on_vertical_road := absf(absf(p.x) - TRACK_HALF_X) < TRACK_WIDTH and absf(p.z) < TRACK_HALF_Z + TRACK_WIDTH
	if on_horizontal_road or on_vertical_road:
		hero_progress = _nearest_path_progress(Vector2(p.x, p.z))
		_update_hero_transform()
		_close_panels()
		selected_slot = -1
		return
	# Any world tap outside a slot or the road dismisses the open action panel.
	_close_panels()
	selected_slot = -1

func _select_slot(index: int) -> void:
	_close_panels()
	selected_slot = index
	var slot: Dictionary = slots[index]
	if not slot.unlocked:
		if gold >= 50:
			gold -= 50
			slot.unlocked = true
			slot.pad.material_override = _material(Color("#172333"))
			slot.plus.visible = true
		else:
			status_label.text = "슬롯 확장에 50G 필요"
			return
	if slot.turret == null:
		build_panel.visible = true
	else:
		manage_row.visible = true
		var ring: MeshInstance3D = slot.turret.range_node
		ring.visible = true
	status_label.text = "포탑 사거리 표시 중"

func _build_selected(turret_name: String) -> void:
	if selected_slot < 0:
		return
	var spec: Dictionary = TURRETS[turret_name]
	if gold < int(spec.cost):
		status_label.text = "골드가 부족합니다"
		return
	var slot: Dictionary = slots[selected_slot]
	if slot.turret != null:
		return
	gold -= int(spec.cost)
	var root := Node3D.new()
	root.name = "%s_%02d" % [turret_name, selected_slot]
	root.position = slot.position + Vector3(0, 0.62, 0)
	world_root.add_child(root)
	var model_scene: PackedScene = turret_scenes[spec.model]
	var model := model_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * 2.2
	root.add_child(model)
	var range_node := _make_range_ring(float(spec.range), spec.color)
	range_node.position = Vector3(slot.position.x, 0.16, slot.position.z)
	world_root.add_child(range_node)
	var turret_data := {"name": turret_name, "model": spec.model, "root": root, "range_node": range_node, "range": float(spec.range), "damage": float(spec.damage), "rate": float(spec.rate), "cooldown": 0.2, "level": 1, "invested": int(spec.cost), "color": spec.color}
	slot.turret = turret_data
	slot.plus.visible = false
	build_panel.visible = false
	status_label.text = "%s 포탑 건설 완료" % turret_name
	_refresh_hud()

func _upgrade_selected() -> void:
	if selected_slot < 0:
		return
	var t: Dictionary = slots[selected_slot].turret
	if t == null or t.level >= 3:
		status_label.text = "최대 강화 단계입니다"
		return
	var cost: int = 55 * int(t.level)
	if gold < cost:
		status_label.text = "강화에는 %dG가 필요합니다" % cost
		return
	gold -= cost
	t.invested += cost
	t.level += 1
	t.damage *= 1.55
	t.range += 0.45
	t.rate *= 0.88
	var torus := t.range_node.mesh as TorusMesh
	torus.inner_radius = t.range - 0.06
	torus.outer_radius = t.range
	_refresh_hud()

func _sell_selected() -> void:
	if selected_slot < 0:
		return
	var slot: Dictionary = slots[selected_slot]
	var t: Dictionary = slot.turret
	if t == null:
		return
	gold += int(floor(float(t.invested) * 0.65))
	t.root.queue_free()
	t.range_node.queue_free()
	slot.turret = null
	slot.plus.visible = true
	_close_panels()
	_refresh_hud()

func _close_panels() -> void:
	if is_instance_valid(build_panel):
		build_panel.visible = false
	if is_instance_valid(manage_row):
		manage_row.visible = false
	for slot in slots:
		if slot.turret != null:
			slot.turret.range_node.visible = false

func _begin_wave() -> void:
	wave += 1
	phase = "spawning"
	spawn_left = 7 + wave * 3 + (1 if wave == 5 else 0)
	spawn_clock = 0.3

func _spawn_zombie(boss: bool = false) -> void:
	var heavy := not boss and wave >= 3 and randi() % 4 == 0
	var multiplier := 1.0 + float(wave - 1) * 0.28
	var hp := (260.0 if boss else (92.0 if heavy else 50.0)) * multiplier
	var actor := Node3D.new()
	actor.name = "BossZombie" if boss else "Zombie"
	var model := zombie_scene.instantiate() as Node3D
	model.scale = Vector3.ONE * (2.05 if boss else 1.8)
	actor.add_child(model)
	world_root.add_child(actor)
	var start := _path_position(0.0)
	actor.position = Vector3(start.x, 0.10, start.y)
	zombies.append({"node": actor, "progress": 0.0, "hp": hp, "max_hp": hp, "speed": 1.18 if boss else (1.65 if heavy else 1.9 + wave * 0.04), "reward": 90 if boss else (18 if heavy else 12 + wave), "damage": 28 if boss else 10, "slow": 0.0, "boss": boss, "heavy": heavy})

func _update_zombies(delta: float) -> void:
	for i in range(zombies.size() - 1, -1, -1):
		var z: Dictionary = zombies[i]
		z.slow = maxf(0.0, z.slow - delta)
		z.progress += float(z.speed) * (0.58 if z.slow > 0 else 1.0) * delta / _path_length()
		if z.progress >= 1.0:
			base_hp = maxi(0, base_hp - int(z.damage))
			z.node.queue_free()
			zombies.remove_at(i)
			if base_hp <= 0:
				_finish_game(false)
			continue
		var p := _path_position(float(z.progress))
		z.node.position = Vector3(p.x, 0.10, p.y)
		var next := _path_position(float(z.progress) + 0.004)
		z.node.look_at(Vector3(next.x, z.node.position.y, next.y), Vector3.UP)

func _update_turrets(delta: float) -> void:
	for slot in slots:
		if slot.turret == null:
			continue
		var t: Dictionary = slot.turret
		t.cooldown = maxf(0.0, t.cooldown - delta)
		var target: Dictionary = _best_target(t.root.global_position, float(t.range))
		if target.is_empty():
			t.root.rotate_y(delta * 0.45)
			continue
		var target_pos: Vector3 = target.node.global_position
		var aim := Vector3(target_pos.x, t.root.global_position.y, target_pos.z)
		t.root.look_at(aim, Vector3.UP)
		if t.cooldown <= 0.0:
			t.cooldown = t.rate
			_fire_projectile(t, target)

func _best_target(from: Vector3, range_value: float) -> Dictionary:
	var best: Dictionary = {}
	var best_progress := -1.0
	for enemy in zombies:
		if from.distance_to(enemy.node.global_position) <= range_value and enemy.progress > best_progress:
			best = enemy
			best_progress = enemy.progress
	return best

func _fire_projectile(turret: Dictionary, target: Dictionary) -> void:
	var shot := _add_sphere(world_root, turret.root.global_position + Vector3(0, 0.85, 0), 0.12, turret.color, true)
	projectiles.append({"node": shot, "target": target, "speed": 10.0, "damage": turret.damage, "slow": 0.0, "ttl": 2.0})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p.ttl -= delta
		if p.ttl <= 0.0 or not is_instance_valid(p.target.node):
			p.node.queue_free()
			projectiles.remove_at(i)
			continue
		var destination: Vector3 = p.target.node.global_position + Vector3(0, 0.65, 0)
		var offset: Vector3 = destination - p.node.global_position
		var travel: float = float(p.speed) * delta
		if offset.length() <= travel:
			_damage_zombie(p.target, float(p.damage))
			p.node.queue_free()
			projectiles.remove_at(i)
		else:
			p.node.position += offset.normalized() * travel

func _update_hero(delta: float) -> void:
	hero_attack_clock -= delta
	hero_skill_clock -= delta
	var hero_pos := hero.global_position
	var target: Dictionary = {}
	for enemy in zombies:
		if Vector2(hero_pos.x, hero_pos.z).distance_to(Vector2(enemy.node.position.x, enemy.node.position.z)) < 1.1:
			target = enemy
			break
	if not target.is_empty() and hero_attack_clock <= 0.0:
		hero_attack_clock = 0.72
		_damage_zombie(target, 15.0)
	if hero_skill_clock <= 0.0:
		hero_skill_clock = 5.5
		for enemy in zombies.duplicate():
			if Vector2(hero_pos.x, hero_pos.z).distance_to(Vector2(enemy.node.position.x, enemy.node.position.z)) < 1.8:
				_damage_zombie(enemy, 25.0)
	var p := _path_position(hero_progress)
	var target_pos := Vector3(p.x, 0.10, p.y)
	hero.position = hero.position.lerp(target_pos, 1.0 - exp(-delta * 4.0))
	hero_marker.position = Vector3(p.x, 0.15, p.y)
	var enemy_target := _best_target(hero.global_position, 2.5)
	if not enemy_target.is_empty():
		var e: Vector3 = enemy_target.node.global_position
		hero.look_at(Vector3(e.x, hero.position.y, e.z), Vector3.UP)

func _damage_zombie(enemy: Dictionary, damage: float) -> void:
	if not zombies.has(enemy):
		return
	enemy.hp -= damage
	if enemy.hp <= 0:
		gold += int(enemy.reward)
		kills += 1
		enemy.node.queue_free()
		zombies.erase(enemy)

func _update_waves(delta: float) -> void:
	if phase == "spawning":
		spawn_clock -= delta
		if spawn_left > 0 and spawn_clock <= 0.0:
			var boss := wave == 5 and spawn_left == 1
			_spawn_zombie(boss)
			spawn_left -= 1
			spawn_clock = 0.95
		if spawn_left == 0 and zombies.is_empty():
			if wave >= 5:
				_finish_game(true)
			else:
				phase = "intermission"
				phase_clock = 6.0
				gold += 35 + wave * 10
	elif phase == "intermission":
		phase_clock -= delta
		if phase_clock <= 0.0:
			_begin_wave()

func _finish_game(won: bool) -> void:
	outcome = "win" if won else "lose"
	var title := result_overlay.get_node("CenterContainer/PanelContainer/VBoxContainer/ResultTitle") as Label
	title.text = "기지 방어 성공!" if won else "기지가 함락되었습니다"
	result_overlay.visible = true
	get_tree().paused = true

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _refresh_hud() -> void:
	if not is_instance_valid(gold_label):
		return
	gold_label.text = "◆ %d" % gold
	wave_label.text = "WAVE %d / 5" % mini(wave, 5)
	hp_bar.value = base_hp
	if phase == "intermission":
		status_label.text = "다음 웨이브 %.0f초" % phase_clock
	else:
		status_label.text = "처치 %d · 남은 적 %d" % [kills, zombies.size() + spawn_left]

func _update_hero_transform() -> void:
	if not is_instance_valid(hero):
		return
	var p := _path_position(hero_progress)
	hero.position = Vector3(p.x, 0.10, p.y)
	if is_instance_valid(hero_marker):
		hero_marker.position = Vector3(p.x, 0.15, p.y)

func _path_position(progress: float) -> Vector2:
	var points: Array[Vector2] = [Vector2(-TRACK_HALF_X, -TRACK_HALF_Z), Vector2(TRACK_HALF_X, -TRACK_HALF_Z), Vector2(TRACK_HALF_X, TRACK_HALF_Z), Vector2(-TRACK_HALF_X, TRACK_HALF_Z)]
	var lengths: Array[float] = [TRACK_HALF_X * 2.0, TRACK_HALF_Z * 2.0, TRACK_HALF_X * 2.0, TRACK_HALF_Z * 2.0]
	var total := _path_length()
	var d := fposmod(progress + ROUTE_OFFSET, 1.0) * total
	for i in range(4):
		if d <= lengths[i]:
			return points[i].lerp(points[(i + 1) % 4], d / lengths[i])
		d -= lengths[i]
	return points[0]

func _path_length() -> float:
	return (TRACK_HALF_X + TRACK_HALF_Z) * 4.0

func _nearest_path_progress(p: Vector2) -> float:
	var points: Array[Vector2] = [Vector2(-TRACK_HALF_X, -TRACK_HALF_Z), Vector2(TRACK_HALF_X, -TRACK_HALF_Z), Vector2(TRACK_HALF_X, TRACK_HALF_Z), Vector2(-TRACK_HALF_X, TRACK_HALF_Z), Vector2(-TRACK_HALF_X, -TRACK_HALF_Z)]
	var best_progress := 0.0
	var best_distance := INF
	var travelled := 0.0
	for i in range(4):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segment := b - a
		var t := clampf((p - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var projected := a + segment * t
		var distance := p.distance_squared_to(projected)
		if distance < best_distance:
			best_distance = distance
			best_progress = (travelled + segment.length() * t) / _path_length()
		travelled += segment.length()
	return fposmod(best_progress - ROUTE_OFFSET, 1.0)

func _add_rounded_platform(parent: Node, pos: Vector3, width: float, height: float, corner: float, color: Color) -> void:
	_add_box(parent, pos, Vector3(width - 2.0 * corner, height, width), color)
	_add_box(parent, pos, Vector3(width, height, width - 2.0 * corner), color)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_add_cylinder(parent, pos + Vector3(x_side * (width * 0.5 - corner), 0, z_side * (width * 0.5 - corner)), Vector3(corner * 2.0, height, corner * 2.0), color)

func _add_rounded_platform_rect(parent: Node, pos: Vector3, size: Vector2, height: float, corner: float, color: Color) -> void:
	_add_box(parent, pos, Vector3(size.x - 2.0 * corner, height, size.y), color)
	_add_box(parent, pos, Vector3(size.x, height, size.y - 2.0 * corner), color)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_add_cylinder(parent, pos + Vector3(x_side * (size.x * 0.5 - corner), 0, z_side * (size.y * 0.5 - corner)), Vector3(corner * 2.0, height, corner * 2.0), color)

func _add_rounded_outline(width: float, corner: float, thickness: float, color: Color, y: float) -> void:
	var half := width * 0.5 - corner
	var line_material := _material(color)
	_add_box(world_root, Vector3(0, y, -width * 0.5), Vector3(width - corner * 2.0, thickness, thickness), color)
	_add_box(world_root, Vector3(0, y, width * 0.5), Vector3(width - corner * 2.0, thickness, thickness), color)
	_add_box(world_root, Vector3(-width * 0.5, y, 0), Vector3(thickness, thickness, width - corner * 2.0), color)
	_add_box(world_root, Vector3(width * 0.5, y, 0), Vector3(thickness, thickness, width - corner * 2.0), color)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_add_torus(world_root, Vector3(x_side * half, y, z_side * half), corner, thickness, color)

func _add_rounded_outline_rect(size: Vector2, corner: float, thickness: float, color: Color, y: float) -> void:
	var half_x := size.x * 0.5 - corner
	var half_z := size.y * 0.5 - corner
	_add_box(world_root, Vector3(0, y, -size.y * 0.5), Vector3(size.x - 2.0 * corner, thickness, thickness), color)
	_add_box(world_root, Vector3(0, y, size.y * 0.5), Vector3(size.x - 2.0 * corner, thickness, thickness), color)
	_add_box(world_root, Vector3(-size.x * 0.5, y, 0), Vector3(thickness, thickness, size.y - 2.0 * corner), color)
	_add_box(world_root, Vector3(size.x * 0.5, y, 0), Vector3(thickness, thickness, size.y - 2.0 * corner), color)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_add_torus(world_root, Vector3(x_side * half_x, y, z_side * half_z), corner, thickness, color)

func _make_range_ring(radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.06
	torus.outer_radius = radius
	torus.rings = 4
	torus.ring_segments = 80
	node.mesh = torus
	var mat := _material(Color(color, 0.55))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	node.visible = false
	return node

func _add_ring_mesh(parent: Node, pos: Vector3, radius: float, width: float, color: Color) -> MeshInstance3D:
	return _add_torus(parent, pos, radius, width, color)

func _add_torus(parent: Node, pos: Vector3, radius: float, width: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width * 0.5
	mesh.outer_radius = radius + width * 0.5
	mesh.rings = 4
	mesh.ring_segments = 64
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _add_box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _add_cylinder(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = size.x * 0.5
	mesh.bottom_radius = size.z * 0.5
	mesh.height = size.y
	mesh.radial_segments = 24
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color)
	parent.add_child(node)
	return node

func _add_sphere(parent: Node, pos: Vector3, radius: float, color: Color, emissive: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, 0.0 if emissive else 0.8, emissive)
	parent.add_child(node)
	return node

func _material(color: Color, roughness: float = 0.8, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material

func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _flat_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := _flat_style(color, 12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.border_color = Color(0.38, 0.50, 0.61, 0.75)
	style.set_border_width_all(1)
	return style

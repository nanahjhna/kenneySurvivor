extends CanvasLayer

signal closed

const HERO_SCENE: PackedScene = null
const DEFAULT_ANIMATION := "Breathing_Idle_RT"

var animation_player: AnimationPlayer
var animation_names: Array[String] = []
var visible_animation_names: Array[String] = []
var selected_animation := ""
var animation_list: ItemList
var search_field: LineEdit
var count_label: Label
var selected_label: Label
var play_button: Button
var repeat_check: CheckBox
var speed_slider: HSlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_preview()
	_build_interface()
	_load_animation_list()

func _build_preview() -> void:
	var viewport_container := SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	viewport_container.add_child(viewport)

	var environment := WorldEnvironment.new()
	var environment_settings := Environment.new()
	environment_settings.background_mode = Environment.BG_COLOR
	environment_settings.background_color = Color(0.035, 0.05, 0.075)
	environment_settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_settings.ambient_light_color = Color(0.68, 0.73, 0.86)
	environment_settings.ambient_light_energy = 0.8
	environment.environment = environment_settings
	viewport.add_child(environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.4
	viewport.add_child(light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(16, 16)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.08, 0.1, 0.14)
	floor.material_override = floor_material
	floor.position.y = -0.035
	viewport.add_child(floor)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.05, 4.2)
	camera.current = true
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0), Vector3.UP)

	if HERO_SCENE == null:
		push_error("hero01_textured.tscn missing")
		return
	var hero := HERO_SCENE.instantiate() as Node3D
	hero.scale = Vector3(2.5, 2.5, 2.5)
	viewport.add_child(hero)
	var animation_nodes := hero.find_children("*", "AnimationPlayer", true, false)
	if animation_nodes.is_empty():
		push_error("hero01_textured.tscn does not contain an AnimationPlayer")
		return
	animation_player = animation_nodes[0] as AnimationPlayer
	animation_player.animation_finished.connect(_on_animation_finished)
	if animation_player.has_animation(DEFAULT_ANIMATION):
		selected_animation = DEFAULT_ANIMATION
		animation_player.play(DEFAULT_ANIMATION)

func _build_interface() -> void:
	var interface_root := Control.new()
	interface_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(interface_root)

	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 424
	panel.offset_bottom = -16
	interface_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = "HERO01 애니메이션"
	heading.add_theme_font_size_override("font_size", 22)
	content.add_child(heading)

	count_label = Label.new()
	content.add_child(count_label)

	search_field = LineEdit.new()
	search_field.placeholder_text = "애니메이션 이름 검색..."
	search_field.text_changed.connect(_on_search_changed)
	content.add_child(search_field)

	var playback_row := HBoxContainer.new()
	content.add_child(playback_row)

	play_button = Button.new()
	play_button.text = "일시정지"
	play_button.pressed.connect(_toggle_playback)
	playback_row.add_child(play_button)

	var stop_button := Button.new()
	stop_button.text = "정지"
	stop_button.pressed.connect(_stop_playback)
	playback_row.add_child(stop_button)

	repeat_check = CheckBox.new()
	repeat_check.text = "반복"
	repeat_check.button_pressed = true
	playback_row.add_child(repeat_check)

	var speed_row := HBoxContainer.new()
	content.add_child(speed_row)
	var speed_label := Label.new()
	speed_label.text = "속도"
	speed_row.add_child(speed_label)

	speed_slider = HSlider.new()
	speed_slider.min_value = 0.25
	speed_slider.max_value = 2.0
	speed_slider.step = 0.05
	speed_slider.value = 1.0
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.value_changed.connect(_on_speed_changed)
	speed_row.add_child(speed_slider)

	selected_label = Label.new()
	selected_label.text = selected_animation
	selected_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(selected_label)

	animation_list = ItemList.new()
	animation_list.select_mode = ItemList.SELECT_SINGLE
	animation_list.allow_reselect = true
	animation_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	animation_list.custom_minimum_size = Vector2(0, 300)
	animation_list.item_selected.connect(_on_animation_selected)
	content.add_child(animation_list)

	var close_button := Button.new()
	close_button.text = "게임으로 돌아가기"
	close_button.pressed.connect(_close_gallery)
	content.add_child(close_button)

func _load_animation_list() -> void:
	if animation_player == null:
		return
	animation_names.assign(animation_player.get_animation_list())
	animation_names.sort()
	_refresh_animation_list()
	if animation_names.has(selected_animation):
		var idle_index := animation_names.find(selected_animation)
		animation_list.select(idle_index)

func _refresh_animation_list() -> void:
	animation_list.clear()
	visible_animation_names.clear()
	var query := search_field.text.strip_edges().to_lower()
	for animation_name in animation_names:
		if query.is_empty() or animation_name.to_lower().contains(query):
			visible_animation_names.append(animation_name)
			animation_list.add_item(animation_name)
	count_label.text = "%d / %d개 애니메이션" % [
		visible_animation_names.size(),
		animation_names.size(),
	]

func _on_search_changed(_text: String) -> void:
	_refresh_animation_list()

func _on_animation_selected(index: int) -> void:
	if index < 0 or index >= visible_animation_names.size():
		return
	selected_animation = visible_animation_names[index]
	selected_label.text = selected_animation
	_play_selected_animation()

func _play_selected_animation() -> void:
	if animation_player == null or selected_animation.is_empty():
		return
	animation_player.stop()
	animation_player.speed_scale = speed_slider.value
	animation_player.play(selected_animation, 0.1)
	play_button.text = "일시정지"

func _toggle_playback() -> void:
	if animation_player == null:
		return
	if animation_player.is_playing():
		animation_player.pause()
		play_button.text = "재생"
	else:
		_play_selected_animation()

func _stop_playback() -> void:
	if animation_player:
		animation_player.stop()
	play_button.text = "재생"

func _on_speed_changed(value: float) -> void:
	if animation_player:
		animation_player.speed_scale = value

func _on_animation_finished(animation_name: StringName) -> void:
	if repeat_check.button_pressed and str(animation_name) == selected_animation:
		_play_selected_animation()
	else:
		play_button.text = "재생"

func resume_preview() -> void:
	if animation_player and not animation_player.is_playing():
		_play_selected_animation()

func pause_preview() -> void:
	if animation_player:
		animation_player.pause()

func _close_gallery() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_gallery()
		get_viewport().set_input_as_handled()

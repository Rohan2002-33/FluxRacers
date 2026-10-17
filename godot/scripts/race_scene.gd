extends Node3D

signal telemetry_changed(speed_kmh: float, distance_m: float)
signal race_exit_requested

const ROAD_WIDTH := 12.0
const ROAD_SEGMENT_LENGTH := 30.0
const ROAD_SEGMENT_COUNT := 18
const TELEMETRY_INTERVAL := 0.1

var _road_segments: Array[Node3D] = []
var _wheels: Array[MeshInstance3D] = []
var _touch_actions: Dictionary = {
	"accelerate": false,
	"brake": false,
	"left": false,
	"right": false,
}
var _vehicle: RaceVehicleModel = RaceVehicleModel.new()
var _car: Node3D
var _camera: Camera3D
var _telemetry_elapsed := 0.0
var _speed_label: Label
var _distance_label: Label
var _pause_panel: PanelContainer


func _ready() -> void:
	_create_environment()
	_create_road()
	_create_car()
	_create_camera()
	_create_hud()
	telemetry_changed.emit(0.0, 0.0)


func _physics_process(delta: float) -> void:
	_update_vehicle(delta)
	_update_road(delta)
	_update_camera(delta)
	_update_hud(delta)


func set_control(action: String, pressed: bool) -> void:
	if not _touch_actions.has(action):
		push_warning("Ignoring unknown race control: %s" % action)
		return
	_touch_actions[action] = pressed


func set_race_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_panel.visible = paused


func _update_vehicle(delta: float) -> void:
	var accelerating: bool = bool(_touch_actions["accelerate"]) or _key_pressed(KEY_W, KEY_UP)
	var braking: bool = bool(_touch_actions["brake"]) or _key_pressed(KEY_S, KEY_DOWN)

	var steering: float = float(_touch_actions["right"]) - float(_touch_actions["left"])
	if _key_pressed(KEY_D, KEY_RIGHT):
		steering += 1.0
	if _key_pressed(KEY_A, KEY_LEFT):
		steering -= 1.0
	steering = clampf(steering, -1.0, 1.0)

	_vehicle.update(delta, accelerating, braking, steering)
	_car.position.x = _vehicle.lateral_position
	if steering != 0.0 and _vehicle.speed_mps > 0.1:
		_car.rotation.z = lerpf(_car.rotation.z, -steering * 0.07, 5.0 * delta)
	else:
		_car.rotation.z = lerpf(_car.rotation.z, 0.0, 4.0 * delta)

	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.UP, _vehicle.speed_mps * delta / 0.38)


func _key_pressed(primary: Key, secondary: Key) -> bool:
	return Input.is_physical_key_pressed(primary) or Input.is_physical_key_pressed(secondary)


func _update_road(delta: float) -> void:
	var scroll_distance: float = _vehicle.speed_mps * delta
	for segment in _road_segments:
		segment.position.z += scroll_distance
		if segment.position.z > ROAD_SEGMENT_LENGTH:
			segment.position.z -= ROAD_SEGMENT_LENGTH * ROAD_SEGMENT_COUNT


func _update_camera(delta: float) -> void:
	var lateral := _car.position.x
	var desired_position := Vector3(lateral * 0.38, 6.2, 10.5)
	_camera.position = _camera.position.lerp(desired_position, 1.0 - exp(-3.5 * delta))
	_camera.look_at(Vector3(lateral * 0.22, 1.0, -14.0), Vector3.UP)


func _update_hud(delta: float) -> void:
	_speed_label.text = "%03d KM/H" % roundi(_vehicle.speed_kmh)
	_distance_label.text = "DISTANCE  %05d M" % floori(_vehicle.distance_m)
	_telemetry_elapsed += delta
	if _telemetry_elapsed >= TELEMETRY_INTERVAL:
		_telemetry_elapsed = 0.0
		telemetry_changed.emit(_vehicle.speed_kmh, _vehicle.distance_m)


func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("132b42")
	sky_material.sky_horizon_color = Color("d18b59")
	sky_material.ground_bottom_color = Color("15271e")
	sky_material.ground_horizon_color = Color("61765b")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	sunlight.light_energy = 1.15
	sunlight.shadow_enabled = true
	add_child(sunlight)

	var ground_material := _material(Color("263d2b"), 0.0, 1.0)
	_add_box(
		self,
		Vector3(900.0, 0.4, 2200.0),
		Vector3(0.0, -0.35, -900.0),
		ground_material
	)
	_create_hills()


func _create_hills() -> void:
	var hill_materials := [
		_material(Color("334d43"), 0.0, 1.0),
		_material(Color("405947"), 0.0, 1.0),
		_material(Color("586347"), 0.0, 1.0),
	]
	for index in range(9):
		var hill := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 10
		mesh.rings = 6
		hill.mesh = mesh
		hill.material_override = hill_materials[index % hill_materials.size()]
		var side := -1.0 if index % 2 == 0 else 1.0
		hill.position = Vector3(
			side * (34.0 + float(index % 3) * 9.0),
			4.0,
			-35.0 - index * 34.0
		)
		hill.scale = Vector3(12.0 + index % 4 * 3.0, 7.0 + index % 3 * 2.0, 15.0)
		add_child(hill)


func _create_road() -> void:
	var asphalt := _material(Color("292d33"), 0.05, 0.92)
	var white := _material(Color("e7e5dd"), 0.0, 0.7)
	var red := _material(Color("e34e38"), 0.0, 0.75)
	var lane_material := _material(Color("f1df9c"), 0.0, 0.7)

	for index in range(ROAD_SEGMENT_COUNT):
		var segment := Node3D.new()
		segment.position.z = -float(index) * ROAD_SEGMENT_LENGTH
		add_child(segment)
		_road_segments.append(segment)

		_add_box(
			segment,
			Vector3(ROAD_WIDTH, 0.16, ROAD_SEGMENT_LENGTH),
			Vector3(0.0, -0.04, 0.0),
			asphalt
		)
		var curb_material: Material = red if index % 2 == 0 else white
		for side in [-1.0, 1.0]:
			_add_box(
				segment,
				Vector3(0.44, 0.2, ROAD_SEGMENT_LENGTH),
				Vector3(side * (ROAD_WIDTH * 0.5 + 0.2), 0.0, 0.0),
				curb_material
			)
		for dash_index in range(4):
			var dash_z := -11.0 + dash_index * 7.0
			_add_box(
				segment,
				Vector3(0.16, 0.025, 3.2),
				Vector3(0.0, 0.055, dash_z),
				lane_material
			)
		for lane_x in [-2.0, 2.0]:
			_add_box(
				segment,
				Vector3(0.09, 0.02, ROAD_SEGMENT_LENGTH),
				Vector3(lane_x, 0.05, 0.0),
				white
			)


func _create_car() -> void:
	_car = Node3D.new()
	_car.name = "RiftRunner"
	_car.position = Vector3(0.0, 0.0, 0.0)
	add_child(_car)

	var body := _material(Color("06cfe0"), 0.72, 0.24)
	var trim := _material(Color("111820"), 0.3, 0.5)
	var glass := _material(Color("152b38"), 0.35, 0.18)
	var tire := _material(Color("101214"), 0.0, 0.93)
	var alloy := _material(Color("a9c2c7"), 0.82, 0.27)
	var headlight := _material(Color("e9fdff"), 0.1, 0.2, Color("b8f8ff"))
	var taillight := _material(Color("e34335"), 0.1, 0.3, Color("b61d18"))

	_add_box(_car, Vector3(1.9, 0.48, 4.35), Vector3(0.0, 0.62, 0.0), body)
	_add_box(_car, Vector3(1.72, 0.26, 1.15), Vector3(0.0, 0.82, -1.43), body)
	_add_box(_car, Vector3(1.48, 0.68, 1.82), Vector3(0.0, 1.12, 0.05), glass)
	_add_box(_car, Vector3(0.92, 0.12, 0.92), Vector3(0.0, 1.52, 0.0), body)
	_add_box(_car, Vector3(1.82, 0.2, 0.22), Vector3(0.0, 0.39, -2.18), trim)
	_add_box(_car, Vector3(0.68, 0.22, 0.08), Vector3(0.0, 0.48, -2.31), trim)
	_add_box(_car, Vector3(1.42, 0.11, 0.06), Vector3(0.0, 0.72, -2.31), headlight)
	_add_box(_car, Vector3(1.52, 0.08, 0.06), Vector3(0.0, 0.73, 2.2), taillight)
	_add_box(_car, Vector3(0.16, 0.62, 0.16), Vector3(-0.62, 1.35, 1.86), trim)
	_add_box(_car, Vector3(0.16, 0.62, 0.16), Vector3(0.62, 1.35, 1.86), trim)
	_add_box(_car, Vector3(2.1, 0.12, 0.5), Vector3(0.0, 1.69, 1.86), body)
	_add_box(_car, Vector3(0.16, 0.16, 3.4), Vector3(-0.98, 0.46, 0.0), trim)
	_add_box(_car, Vector3(0.16, 0.16, 3.4), Vector3(0.98, 0.46, 0.0), trim)

	for x in [-0.98, 0.98]:
		for z in [-1.4, 1.42]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.39
			wheel_mesh.bottom_radius = 0.39
			wheel_mesh.height = 0.3
			wheel_mesh.radial_segments = 20
			wheel.mesh = wheel_mesh
			wheel.material_override = tire
			wheel.position = Vector3(x, 0.39, z)
			wheel.rotation.z = PI * 0.5
			_car.add_child(wheel)
			_wheels.append(wheel)

			var hub := MeshInstance3D.new()
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.2
			hub_mesh.bottom_radius = 0.2
			hub_mesh.height = 0.32
			hub.mesh = hub_mesh
			hub.material_override = alloy
			hub.position = wheel.position
			hub.rotation.z = PI * 0.5
			_car.add_child(hub)


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "RaceCamera"
	_camera.position = Vector3(0.0, 6.2, 10.5)
	_camera.current = true
	_camera.fov = 68.0
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.0, -14.0), Vector3.UP)


func _create_hud() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var speed_panel := PanelContainer.new()
	speed_panel.position = Vector2(22.0, 20.0)
	speed_panel.custom_minimum_size = Vector2(246.0, 88.0)
	layer.add_child(speed_panel)
	var speed_box := VBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 2)
	speed_panel.add_child(speed_box)

	_speed_label = Label.new()
	_speed_label.text = "000 KM/H"
	_speed_label.add_theme_font_size_override("font_size", 30)
	_speed_label.add_theme_color_override("font_color", Color("08d9e8"))
	speed_box.add_child(_speed_label)
	_distance_label = Label.new()
	_distance_label.text = "DISTANCE  00000 M"
	_distance_label.add_theme_font_size_override("font_size", 15)
	_distance_label.add_theme_color_override("font_color", Color("e1e9ea"))
	speed_box.add_child(_distance_label)

	var controls := HBoxContainer.new()
	controls.anchor_left = 0.025
	controls.anchor_top = 0.79
	controls.anchor_right = 0.975
	controls.anchor_bottom = 0.98
	controls.add_theme_constant_override("separation", 12)
	layer.add_child(controls)
	controls.add_child(_make_hold_button("◀", "left", Color("06cfe0")))
	controls.add_child(_make_hold_button("▶", "right", Color("06cfe0")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	controls.add_child(_make_hold_button("BRAKE", "brake", Color("ef4b3f")))
	controls.add_child(_make_hold_button("GAS", "accelerate", Color("f18a32")))

	var pause_button := Button.new()
	pause_button.text = "Ⅱ"
	pause_button.position = Vector2(-86.0, 20.0)
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.custom_minimum_size = Vector2(64.0, 58.0)
	pause_button.add_theme_font_size_override("font_size", 26)
	pause_button.pressed.connect(func() -> void: set_race_paused(true))
	layer.add_child(pause_button)

	_pause_panel = PanelContainer.new()
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -180.0
	_pause_panel.offset_top = -125.0
	_pause_panel.offset_right = 180.0
	_pause_panel.offset_bottom = 125.0
	_pause_panel.visible = false
	layer.add_child(_pause_panel)

	var pause_content := VBoxContainer.new()
	pause_content.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_content.add_theme_constant_override("separation", 16)
	_pause_panel.add_child(pause_content)
	var pause_title := Label.new()
	pause_title.text = "RACE PAUSED"
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 28)
	pause_content.add_child(pause_title)

	var resume_button := Button.new()
	resume_button.text = "RESUME"
	resume_button.custom_minimum_size = Vector2(240.0, 52.0)
	resume_button.pressed.connect(func() -> void: set_race_paused(false))
	pause_content.add_child(resume_button)
	var quit_button := Button.new()
	quit_button.text = "RETURN TO MENU"
	quit_button.custom_minimum_size = Vector2(240.0, 52.0)
	quit_button.pressed.connect(_request_exit)
	pause_content.add_child(quit_button)


func _make_hold_button(text: String, action: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132.0, 82.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_style(color, 0.65))
	button.add_theme_stylebox_override("hover", _button_style(color, 0.82))
	button.add_theme_stylebox_override("pressed", _button_style(color, 1.0))
	button.button_down.connect(func() -> void: set_control(action, true))
	button.button_up.connect(func() -> void: set_control(action, false))
	return button


func _button_style(color: Color, alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, alpha)
	style.border_color = Color("06d5e7")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _request_exit() -> void:
	set_race_paused(false)
	race_exit_requested.emit()
	if race_exit_requested.get_connections().is_empty():
		get_tree().quit()


func _material(
	color: Color,
	metallic: float,
	roughness: float,
	emission_color: Color = Color.BLACK
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission_color != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 1.6
	return material


func _add_box(
	parent: Node3D,
	box_size: Vector3,
	box_position: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	instance.mesh = box
	instance.position = box_position
	instance.material_override = material
	parent.add_child(instance)
	return instance
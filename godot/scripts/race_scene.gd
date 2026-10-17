extends Node3D

signal telemetry_changed(speed_kmh: float, distance_m: float)
signal race_exit_requested

const ROAD_WIDTH := 12.0
const ROAD_SEGMENT_LENGTH := 30.0
const ROAD_SEGMENT_COUNT := 18
const TELEMETRY_INTERVAL := 0.1
const CAR_FORWARD := Vector3.FORWARD

var _road_segments: Array[Node3D] = []
var _wheels: Array[Node3D] = []
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

	for wheel in _wheels:
		if wheel.position.z < 0.0:
			wheel.rotation.y = steering * 0.18
		wheel.rotate_object_local(Vector3.RIGHT, _vehicle.speed_mps * delta / 0.39)


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
	_car.rotation = Vector3.ZERO
	add_child(_car)

	var body := _material(Color("05bdd0"), 0.62, 0.22)
	var body_edge := _material(Color("087f91"), 0.58, 0.3)
	var trim := _material(Color("101820"), 0.25, 0.38)
	var glass := _material(Color("102c3a"), 0.48, 0.16)
	var tire := _material(Color("101214"), 0.0, 0.94)
	var alloy := _material(Color("b7c9cb"), 0.9, 0.2)
	var headlight := _material(Color("e9fdff"), 0.1, 0.18, Color("a7f5ff"))
	var taillight := _material(Color("f34c3e"), 0.1, 0.25, Color("a41f19"))
	var dark_glass := glass.duplicate() as StandardMaterial3D
	dark_glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body_profiles: Array[Vector4] = [
		Vector4(2.24, 0.035, 0.79, 0.035),
		Vector4(2.05, 0.65, 0.72, 0.29),
		Vector4(1.55, 0.88, 0.68, 0.35),
		Vector4(0.9, 0.91, 0.66, 0.34),
		Vector4(0.0, 0.86, 0.63, 0.31),
		Vector4(-0.9, 0.91, 0.62, 0.26),
		Vector4(-1.55, 0.83, 0.61, 0.22),
		Vector4(-2.05, 0.68, 0.6, 0.17),
		Vector4(-2.25, 0.035, 0.59, 0.03),
	]
	_add_profile_mesh(_car, "SculptedBody", body_profiles, body, 28)

	_add_box(
		_car,
		Vector3(1.56, 0.16, 3.38),
		Vector3(0.0, 0.39, 0.0),
		trim
	)
	_add_box(
		_car,
		Vector3(1.7, 0.11, 0.55),
		Vector3(0.0, 0.39, 1.92),
		body_edge
	)
	_add_box(
		_car,
		Vector3(1.72, 0.1, 0.42),
		Vector3(0.0, 0.37, -1.95),
		body_edge
	)

	_add_profile_mesh(
		_car,
		"CoupeGreenhouse",
		[
			Vector4(1.23, 0.025, 1.02, 0.025),
			Vector4(1.06, 0.59, 1.08, 0.22),
			Vector4(0.54, 0.56, 1.35, 0.25),
			Vector4(0.32, 0.53, 1.48, 0.12),
			Vector4(-0.47, 0.53, 1.48, 0.12),
			Vector4(-0.76, 0.58, 1.27, 0.28),
			Vector4(-1.2, 0.63, 1.0, 0.035),
		],
		body_edge,
		24
	)

	_add_quad(
		_car,
		"FrontWindshield",
		PackedVector3Array([
			Vector3(-0.54, 1.48, -0.54),
			Vector3(0.54, 1.48, -0.54),
			Vector3(0.62, 1.04, -1.14),
			Vector3(-0.62, 1.04, -1.14),
		]),
		dark_glass
	)
	_add_quad(
		_car,
		"RearWindow",
		PackedVector3Array([
			Vector3(-0.54, 1.48, 0.38),
			Vector3(0.54, 1.48, 0.38),
			Vector3(0.61, 1.04, 1.12),
			Vector3(-0.61, 1.04, 1.12),
		]),
		dark_glass
	)
	for side in [-1.0, 1.0]:
		_add_quad(
			_car,
			"SideWindow",
			PackedVector3Array([
				Vector3(side * 0.55, 1.44, -0.48),
				Vector3(side * 0.55, 1.44, 0.28),
				Vector3(side * 0.62, 1.07, 0.93),
				Vector3(side * 0.62, 1.07, -0.96),
			]),
			dark_glass
		)

	for side in [-1.0, 1.0]:
		for wheel_z in [-1.38, 1.38]:
			var arch := MeshInstance3D.new()
			var arch_mesh := SphereMesh.new()
			arch_mesh.radial_segments = 20
			arch_mesh.rings = 12
			arch.mesh = arch_mesh
			arch.material_override = body
			arch.position = Vector3(side * 0.84, 0.52, wheel_z)
			arch.scale = Vector3(0.2, 0.43, 0.53)
			_car.add_child(arch)

		var mirror := MeshInstance3D.new()
		var mirror_mesh := SphereMesh.new()
		mirror_mesh.radial_segments = 16
		mirror_mesh.rings = 8
		mirror.mesh = mirror_mesh
		mirror.material_override = body_edge
		mirror.position = Vector3(side * 0.8, 1.04, -0.82)
		mirror.scale = Vector3(0.2, 0.11, 0.16)
		_car.add_child(mirror)

	_add_ellipsoid(_car, "Roof", Vector3(0.0, 1.51, -0.08), Vector3(0.53, 0.12, 0.43), body)
	_add_ellipsoid(_car, "FrontLampLeft", Vector3(-0.57, 0.79, -2.12), Vector3(0.28, 0.075, 0.07), headlight)
	_add_ellipsoid(_car, "FrontLampRight", Vector3(0.57, 0.79, -2.12), Vector3(0.28, 0.075, 0.07), headlight)
	_add_ellipsoid(_car, "RearLampLeft", Vector3(-0.61, 0.79, 2.12), Vector3(0.25, 0.08, 0.07), taillight)
	_add_ellipsoid(_car, "RearLampRight", Vector3(0.61, 0.79, 2.12), Vector3(0.25, 0.08, 0.07), taillight)
	_add_box(_car, Vector3(1.38, 0.12, 0.08), Vector3(0.0, 0.55, -2.21), trim)
	_add_box(_car, Vector3(1.2, 0.06, 0.08), Vector3(0.0, 0.59, 2.2), trim)

	for side in [-1.0, 1.0]:
		for wheel_z in [-1.38, 1.38]:
			var wheel := _create_wheel(side, wheel_z, tire, alloy, trim)
			_car.add_child(wheel)
			_wheels.append(wheel)


func _create_wheel(
	side: float,
	wheel_z: float,
	tire_material: Material,
	alloy_material: Material,
	trim_material: Material
) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "FrontWheel" if wheel_z < 0.0 else "RearWheel"
	pivot.position = Vector3(side * 1.0, 0.43, wheel_z)

	var tire := MeshInstance3D.new()
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = 0.39
	tire_mesh.bottom_radius = 0.39
	tire_mesh.height = 0.3
	tire_mesh.radial_segments = 32
	tire.mesh = tire_mesh
	tire.material_override = tire_material
	tire.rotation.z = PI * 0.5
	pivot.add_child(tire)

	for face in [-1.0, 1.0]:
		var rim := MeshInstance3D.new()
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = 0.16
		rim_mesh.outer_radius = 0.25
		rim_mesh.rings = 8
		rim_mesh.ring_segments = 20
		rim.mesh = rim_mesh
		rim.material_override = alloy_material
		rim.position.x = face * 0.16
		rim.rotation.z = PI * 0.5
		pivot.add_child(rim)

		var hub := MeshInstance3D.new()
		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = 0.12
		hub_mesh.bottom_radius = 0.12
		hub_mesh.height = 0.33
		hub_mesh.radial_segments = 20
		hub.mesh = hub_mesh
		hub.material_override = alloy_material
		hub.rotation.z = PI * 0.5
		pivot.add_child(hub)

		for spoke_index in range(5):
			var spoke := MeshInstance3D.new()
			var spoke_mesh := BoxMesh.new()
			spoke_mesh.size = Vector3(0.045, 0.035, 0.31)
			spoke.mesh = spoke_mesh
			spoke.material_override = trim_material
			var angle := TAU * float(spoke_index) / 5.0
			spoke.position = Vector3(
				face * 0.175,
				cos(angle) * 0.085,
				sin(angle) * 0.085
			)
			spoke.rotation.x = -angle
			pivot.add_child(spoke)

	return pivot


func _add_profile_mesh(
	parent: Node3D,
	mesh_name: String,
	profiles: Array[Vector4],
	material: Material,
	radial_segments: int
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for profile in profiles:
		for segment in range(radial_segments):
			var angle := TAU * float(segment) / float(radial_segments)
			surface.add_vertex(
				Vector3(
					cos(angle) * profile.y,
					profile.z + sin(angle) * profile.w,
					profile.x
				)
			)

	for profile_index in range(profiles.size() - 1):
		for segment in range(radial_segments):
			var next_segment := (segment + 1) % radial_segments
			var current := profile_index * radial_segments + segment
			var next_profile := (profile_index + 1) * radial_segments
			surface.add_index(current)
			surface.add_index(next_profile + segment)
			surface.add_index(next_profile + next_segment)
			surface.add_index(current)
			surface.add_index(next_profile + next_segment)
			surface.add_index(profile_index * radial_segments + next_segment)
	surface.generate_normals()

	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = surface.commit()
	parent.add_child(instance)
	return instance


func _add_quad(
	parent: Node3D,
	mesh_name: String,
	points: PackedVector3Array,
	material: Material
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	surface.add_vertex(points[0])
	surface.add_vertex(points[1])
	surface.add_vertex(points[2])
	surface.add_vertex(points[0])
	surface.add_vertex(points[2])
	surface.add_vertex(points[3])
	surface.generate_normals()

	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = surface.commit()
	parent.add_child(instance)
	return instance


func _add_ellipsoid(
	parent: Node3D,
	mesh_name: String,
	mesh_position: Vector3,
	mesh_scale: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	var sphere := SphereMesh.new()
	sphere.radial_segments = 24
	sphere.rings = 12
	instance.mesh = sphere
	instance.material_override = material
	instance.position = mesh_position
	instance.scale = mesh_scale
	parent.add_child(instance)
	return instance


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
extends Node3D

signal telemetry_changed(speed_kmh: float, distance_m: float)
signal race_exit_requested

const ROAD_WIDTH := 12.0
const ROAD_SEGMENT_LENGTH := 30.0
const ROAD_SEGMENT_COUNT := 8
const TELEMETRY_INTERVAL := 0.1
const VEHICLE_SCENE_PATH := "res://assets/models/car_concept/CarConcept.glb"
const VEHICLE_WHEEL_NAMES := ["WheelFrontL", "WheelFrontR", "WheelRearL", "WheelRearR"]
const PALM_TREE_GENERATOR := preload("res://scripts/race_palm_tree.gd")
const TREE_STATION_COUNT := 5
const TREE_STATION_SPACING := 42.0
const SHRUB_RECYCLE_DISTANCE := 238.0
const TREE_RECYCLE_DISTANCE := TREE_STATION_COUNT * TREE_STATION_SPACING
const ROAD_ALBEDO := preload("res://assets/textures/asphalt_track/asphalt_track_diff_1k.jpg")
const ROAD_NORMAL := preload("res://assets/textures/asphalt_track/asphalt_track_nor_gl_1k.jpg")
const ROAD_ROUGHNESS := preload("res://assets/textures/asphalt_track/asphalt_track_rough_1k.jpg")
const TERRAIN_ALBEDO := preload(
	"res://assets/textures/aerial_grass_rock/aerial_grass_rock_diff_1k.jpg"
)
const TERRAIN_NORMAL := preload(
	"res://assets/textures/aerial_grass_rock/aerial_grass_rock_nor_gl_1k.jpg"
)
const TERRAIN_ROUGHNESS := preload(
	"res://assets/textures/aerial_grass_rock/aerial_grass_rock_rough_1k.jpg"
)
const SHRUB_SCENE_PATHS := [
	"res://assets/models/shrub_03/shrub_03_1k.gltf",
	"res://assets/models/shrub_04/shrub_04_1k.gltf",
]

var _road_batches: Array[MultiMeshInstance3D] = []
var _road_instance_transforms: Array[Transform3D] = []
var _wheels: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _road_material: StandardMaterial3D
var _terrain_material: StandardMaterial3D
var _vegetation: Array[Node3D] = []
var _shrub_batches: Array[MultiMeshInstance3D] = []
var _shrub_instance_transforms: Array[Transform3D] = []
var _tree_batches: Array[MultiMeshInstance3D] = []
var _tree_instance_transforms: Array[Transform3D] = []
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
var _vehicle_status_label: Label
var _terrain_scroll_distance := 0.0
var _road_scroll_distance := 0.0
var _vehicle_model_ready := false


func _ready() -> void:
	_create_environment()
	_create_road()
	_create_car()
	_create_camera()
	_create_hud()
	call_deferred("_load_roadside_vegetation")
	call_deferred("_load_vehicle_model")
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
	if _car != null:
		_car.position.x = _vehicle.lateral_position

	for wheel in _wheels:
		if _front_wheels.has(wheel):
			wheel.rotation.y = steering * 0.18
		wheel.rotate_object_local(Vector3.RIGHT, _vehicle.speed_mps * delta / 0.39)


func _key_pressed(primary: Key, secondary: Key) -> bool:
	return Input.is_physical_key_pressed(primary) or Input.is_physical_key_pressed(secondary)


func _update_road(delta: float) -> void:
	var scroll_distance: float = _vehicle.speed_mps * delta
	if is_zero_approx(scroll_distance):
		return
	_terrain_scroll_distance = fposmod(
		_terrain_scroll_distance + scroll_distance * 112.0 / 4400.0,
		1.0
	)
	_road_scroll_distance = fposmod(
		_road_scroll_distance + scroll_distance * 16.0 / ROAD_SEGMENT_LENGTH,
		1.0
	)
	_terrain_material.uv1_offset.y = _terrain_scroll_distance
	_road_material.uv1_offset.y = _road_scroll_distance
	_advance_road_batches(scroll_distance)
	_advance_roadside_objects(_vegetation, scroll_distance, SHRUB_RECYCLE_DISTANCE)
	_advance_shrub_instances(scroll_distance)
	_advance_palm_instances(scroll_distance)


func _advance_shrub_instances(scroll_distance: float) -> void:
	var transform_offset := 0
	for shrub_batch in _shrub_batches:
		var multimesh := shrub_batch.multimesh
		if multimesh == null:
			push_error("Roadside shrub batch is missing its MultiMesh")
			return
		var batch_distance: float = shrub_batch.position.z + scroll_distance
		var recycle_count := floori(batch_distance / SHRUB_RECYCLE_DISTANCE)
		shrub_batch.position.z = fposmod(batch_distance, SHRUB_RECYCLE_DISTANCE)
		var transform_shift := recycle_count * SHRUB_RECYCLE_DISTANCE
		for index in range(multimesh.instance_count):
			var transform_index := transform_offset + index
			var transform := _shrub_instance_transforms[transform_index]
			var transform_changed := recycle_count > 0
			if transform_changed:
				transform.origin.z += transform_shift
			while transform.origin.z + shrub_batch.position.z > 28.0:
				transform.origin.z -= SHRUB_RECYCLE_DISTANCE
				transform_changed = true
			if transform_changed:
				_shrub_instance_transforms[transform_index] = transform
				multimesh.set_instance_transform(index, transform)
		transform_offset += multimesh.instance_count


func _advance_road_batches(scroll_distance: float) -> void:
	for batch_index in range(_road_batches.size()):
		var road_batch := _road_batches[batch_index]
		var multimesh := road_batch.multimesh
		if multimesh == null:
			push_error("Road render batch is missing its MultiMesh")
			return

		var batch_distance: float = road_batch.position.z + scroll_distance
		var recycle_count := floori(batch_distance / (ROAD_SEGMENT_LENGTH * ROAD_SEGMENT_COUNT))
		road_batch.position.z = fposmod(
			batch_distance,
			ROAD_SEGMENT_LENGTH * ROAD_SEGMENT_COUNT
		)
		var transform_shift := recycle_count * ROAD_SEGMENT_LENGTH * ROAD_SEGMENT_COUNT
		var transform_offset := batch_index * ROAD_SEGMENT_COUNT
		for index in range(multimesh.instance_count):
			var transform_index := transform_offset + index
			var transform := _road_instance_transforms[transform_index]
			var transform_changed := recycle_count > 0
			if transform_changed:
				transform.origin.z += transform_shift
			while transform.origin.z + road_batch.position.z > ROAD_SEGMENT_LENGTH:
				transform.origin.z -= ROAD_SEGMENT_LENGTH * ROAD_SEGMENT_COUNT
				transform_changed = true
			if transform_changed:
				_road_instance_transforms[transform_index] = transform
				multimesh.set_instance_transform(index, transform)


func _advance_roadside_objects(
	objects: Array[Node3D],
	scroll_distance: float,
	recycle_distance: float
) -> void:
	for roadside_object in objects:
		roadside_object.position.z += scroll_distance
		while roadside_object.position.z > 28.0:
			roadside_object.position.z -= recycle_distance


func _update_camera(delta: float) -> void:
	var lateral := _vehicle.lateral_position
	var desired_position := Vector3(lateral * 0.38, 6.2, 10.5)
	_camera.position = _camera.position.lerp(desired_position, 1.0 - exp(-3.5 * delta))
	_camera.look_at(Vector3(lateral * 0.22, 1.0, -14.0), Vector3.UP)


func _update_hud(delta: float) -> void:
	_telemetry_elapsed += delta
	if _telemetry_elapsed < TELEMETRY_INTERVAL:
		return
	_telemetry_elapsed = fposmod(_telemetry_elapsed, TELEMETRY_INTERVAL)
	_speed_label.text = "%03d KM/H" % roundi(_vehicle.speed_kmh)
	_distance_label.text = "DISTANCE  %05d M" % floori(_vehicle.distance_m)
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
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	world.environment = environment
	add_child(world)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-34.0, -24.0, 0.0)
	sunlight.light_energy = 1.0
	sunlight.shadow_enabled = OS.get_name() != "Android"
	add_child(sunlight)

	_terrain_material = _textured_material(
		TERRAIN_ALBEDO,
		TERRAIN_NORMAL,
		null,
		Vector3(46.0, 112.0, 1.0)
	)
	var terrain := MeshInstance3D.new()
	terrain.name = "TiledNaturalTerrain"
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2(1800.0, 4400.0)
	terrain.mesh = terrain_mesh
	terrain.material_override = _terrain_material
	terrain.position = Vector3(0.0, -0.13, -900.0)
	add_child(terrain)

	_create_distant_ridges()


func _create_distant_ridges() -> void:
	var ridge_colors := [
		Color("59675d"),
		Color("6c7668"),
		Color("858675"),
	]
	for ridge_index in range(ridge_colors.size()):
		var ridge := MeshInstance3D.new()
		ridge.name = "DistantRidge%d" % ridge_index
		ridge.mesh = _build_ridge_mesh(ridge_index)
		var ridge_material := _material(ridge_colors[ridge_index], 0.0, 1.0)
		ridge_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ridge.material_override = ridge_material
		ridge.position.z = -145.0 - ridge_index * 92.0
		add_child(ridge)


func _build_ridge_mesh(ridge_index: int) -> ArrayMesh:
	const WIDTH := 340.0
	const DEPTH := 54.0
	const CROSS_SECTION_COUNT := 5
	const WIDTH_SEGMENTS := 56
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(CROSS_SECTION_COUNT):
		for sample in range(WIDTH_SEGMENTS + 1):
			var along := float(sample) / float(WIDTH_SEGMENTS)
			var x := (along - 0.5) * WIDTH
			var envelope := pow(sin(PI * along), 0.72)
			var main_peak := pow(
				maxf(0.0, sin(PI * (along * 2.6 + ridge_index * 0.17))),
				2.1
			)
			var smaller_peaks := pow(
				maxf(0.0, sin(PI * (along * 5.1 + ridge_index * 0.29))),
				3.0
			)
			var ridge_height := envelope * (5.0 + 19.0 * main_peak + 7.0 * smaller_peaks)
			var row_depth := DEPTH * float(row) / float(CROSS_SECTION_COUNT - 1)
			var cross_section_height := 1.0 - absf(float(row) - 2.0) / 3.0
			var y := -0.12 + ridge_height * cross_section_height
			surface.add_vertex(Vector3(x, y, row_depth))

	for row in range(CROSS_SECTION_COUNT - 1):
		for sample in range(WIDTH_SEGMENTS):
			var start := row * (WIDTH_SEGMENTS + 1) + sample
			var next_row := start + WIDTH_SEGMENTS + 1
			surface.add_index(start)
			surface.add_index(start + 1)
			surface.add_index(next_row)
			surface.add_index(start + 1)
			surface.add_index(next_row + 1)
			surface.add_index(next_row)

	surface.generate_normals()
	return surface.commit()


func _load_roadside_vegetation() -> void:
	_create_roadside_palms()
	if not is_inside_tree():
		return

	for scene_index in range(SHRUB_SCENE_PATHS.size()):
		var shrub_scene := await _load_roadside_scene(SHRUB_SCENE_PATHS[scene_index])
		if not is_inside_tree():
			return
		if shrub_scene == null:
			continue
		var prototype := shrub_scene.instantiate() as Node3D
		if prototype == null:
			push_error("Roadside shrub did not instantiate: %s" % SHRUB_SCENE_PATHS[scene_index])
			continue
		var shrub_mesh := _combine_roadside_mesh(prototype)
		prototype.free()
		if shrub_mesh == null or shrub_mesh.get_surface_count() == 0:
			push_error("Could not build a batched roadside shrub: %s" % SHRUB_SCENE_PATHS[scene_index])
			continue

		var transforms: Array[Transform3D] = []
		for station in range(5):
			var offset := 9.4 + float(station % 3) * 1.25
			for side_index in range(2):
				var side := -1.0 if side_index == 0 else 1.0
				if (station + side_index) % SHRUB_SCENE_PATHS.size() != scene_index:
					continue
				var yaw := float(station * 31 + int(side) * 17) * PI / 180.0
				var plant_scale := 1.45 + float(station % 3) * 0.16
				var plant_transform := Transform3D(
					Basis(Vector3.UP, yaw).scaled(Vector3.ONE * plant_scale),
					Vector3(side * offset, 0.0, -20.0 - station * 34.0)
				)
				transforms.append(plant_transform)

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = shrub_mesh
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])
		multimesh.custom_aabb = AABB(Vector3(-40.0, -1.0, -500.0), Vector3(80.0, 25.0, 550.0))

		var shrub_batch := MultiMeshInstance3D.new()
		shrub_batch.name = "RoadsideShrub%d" % scene_index
		shrub_batch.multimesh = multimesh
		shrub_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shrub_batch.lod_bias = 0.35
		add_child(shrub_batch)
		_shrub_batches.append(shrub_batch)
		_shrub_instance_transforms.append_array(transforms)


func _combine_roadside_mesh(prototype: Node3D) -> ArrayMesh:
	var builders: Dictionary = {}
	var materials: Dictionary = {}
	var fallback_material := _material(Color.WHITE, 0.0, 1.0)
	for descendant in prototype.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := _relative_node_transform(prototype, mesh_instance)
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var surface_material := mesh_instance.get_active_material(surface_index)
			if surface_material == null:
				surface_material = fallback_material
			var material_key := str(surface_material.get_instance_id())
			if not builders.has(material_key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builders[material_key] = builder
				materials[material_key] = surface_material
			(builders[material_key] as SurfaceTool).append_from(
				mesh_instance.mesh,
				surface_index,
				relative_transform
			)

	var combined_mesh := ArrayMesh.new()
	for material_key in builders:
		var material_mesh := (builders[material_key] as SurfaceTool).commit()
		if material_mesh == null or material_mesh.get_surface_count() != 1:
			push_error("Could not combine roadside shrub material %s" % material_key)
			return null
		combined_mesh.add_surface_from_arrays(
			material_mesh.surface_get_primitive_type(0),
			material_mesh.surface_get_arrays(0)
		)
		combined_mesh.surface_set_material(
			combined_mesh.get_surface_count() - 1,
			materials[material_key]
		)
	return combined_mesh


func _create_roadside_palms() -> void:
	for species in [PALM_TREE_GENERATOR.COCONUT, PALM_TREE_GENERATOR.DATE]:
		var prototype := PALM_TREE_GENERATOR.build_tree(species) as MeshInstance3D
		if prototype == null or prototype.mesh == null:
			push_error("Could not build the %s palm mesh" % species)
			if prototype != null:
				prototype.free()
			return

		var transforms: Array[Transform3D] = []
		for station in range(TREE_STATION_COUNT):
			var z := -15.0 - station * TREE_STATION_SPACING
			var offset := 11.5 + float(station % 3) * 1.2
			for side_index in range(2):
				var side := -1.0 if side_index == 0 else 1.0
				var instance_species := (
					PALM_TREE_GENERATOR.COCONUT
					if (station + side_index) % 2 == 0
					else PALM_TREE_GENERATOR.DATE
				)
				if instance_species != species:
					continue
				var yaw := float(station * 37 + side_index * 21) * PI / 180.0
				var scale := 0.91 + float((station + side_index) % 4) * 0.06
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
				transforms.append(Transform3D(basis, Vector3(side * offset, 0.0, z)))

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = prototype.mesh
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index, transforms[index])
		multimesh.custom_aabb = AABB(Vector3(-30.0, -1.0, -250.0), Vector3(60.0, 20.0, 300.0))

		var tree_batch := MultiMeshInstance3D.new()
		tree_batch.name = "Roadside%sPalms" % species.capitalize()
		tree_batch.multimesh = multimesh
		tree_batch.material_override = prototype.material_override
		tree_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tree_batch)
		_tree_batches.append(tree_batch)
		for transform in transforms:
			_tree_instance_transforms.append(transform)
		prototype.free()


func _advance_palm_instances(scroll_distance: float) -> void:
	var transform_offset := 0
	for tree_batch in _tree_batches:
		var multimesh := tree_batch.multimesh
		if multimesh == null:
			push_error("Roadside palm batch is missing its MultiMesh")
			return
		var batch_distance: float = tree_batch.position.z + scroll_distance
		var recycle_count := floori(batch_distance / TREE_RECYCLE_DISTANCE)
		tree_batch.position.z = fposmod(batch_distance, TREE_RECYCLE_DISTANCE)
		var transform_shift := recycle_count * TREE_RECYCLE_DISTANCE
		for index in range(multimesh.instance_count):
			var transform_index := transform_offset + index
			var transform := _tree_instance_transforms[transform_index]
			var transform_changed := recycle_count > 0
			if transform_changed:
				transform.origin.z += transform_shift
			while transform.origin.z + tree_batch.position.z > 28.0:
				transform.origin.z -= TREE_RECYCLE_DISTANCE
				transform_changed = true
			if transform_changed:
				_tree_instance_transforms[transform_index] = transform
				multimesh.set_instance_transform(index, transform)
		transform_offset += multimesh.instance_count


func _disable_roadside_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		var instance := node as GeometryInstance3D
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.lod_bias = 0.35
	for child in node.get_children():
		_disable_roadside_shadows(child)


func _load_roadside_scene(scene_path: String) -> PackedScene:
	var request_error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if request_error != OK:
		push_error("Could not queue roadside model %s (error %d)" % [scene_path, request_error])
		return null

	while true:
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
			if packed_scene == null:
				push_error("Roadside model did not load as a PackedScene: %s" % scene_path)
			return packed_scene
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Could not load roadside model: %s" % scene_path)
			return null
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Roadside model path is invalid: %s" % scene_path)
			return null
		await get_tree().process_frame
	return null


func _create_road() -> void:
	_road_material = _textured_material(
		ROAD_ALBEDO,
		ROAD_NORMAL,
		ROAD_ROUGHNESS,
		Vector3(7.0, 16.0, 1.0)
	)
	var kerb_material := _material(Color.WHITE, 0.0, 0.82)
	kerb_material.vertex_color_use_as_albedo = true
	kerb_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	kerb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var kerb_mesh := _build_kerb_mesh()

	var asphalt_mesh := PlaneMesh.new()
	asphalt_mesh.size = Vector2(ROAD_WIDTH, ROAD_SEGMENT_LENGTH)
	var transforms: Array[Transform3D] = []
	for index in range(ROAD_SEGMENT_COUNT):
		var road_transform := Transform3D(Basis.IDENTITY, Vector3(
			0.0,
			0.04,
			-float(index) * ROAD_SEGMENT_LENGTH
		))
		transforms.append(road_transform)
	_create_road_batch("RoadAsphalt", asphalt_mesh, _road_material, transforms)
	for index in range(transforms.size()):
		var marking_transform := transforms[index]
		marking_transform.origin.y = 0.0
		transforms[index] = marking_transform
	_create_road_batch("RoadMarkings", kerb_mesh, kerb_material, transforms)


func _create_road_batch(
	batch_name: String,
	mesh: Mesh,
	material: Material,
	transforms: Array[Transform3D]
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	_road_instance_transforms.append_array(transforms)

	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multimesh
	batch.material_override = material
	batch.custom_aabb = AABB(Vector3(-7.0, -0.2, -250.0), Vector3(14.0, 1.0, 300.0))
	add_child(batch)
	_road_batches.append(batch)


func _build_kerb_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for road_index in range(ROAD_SEGMENT_COUNT):
		var segment_offset := -float(road_index) * ROAD_SEGMENT_LENGTH
		for side in [-1.0, 1.0]:
			for curb_index in range(15):
				var color := Color("c94132") if curb_index % 2 == 0 else Color.WHITE
				var inner_x: float = side * ROAD_WIDTH * 0.5
				var outer_x: float = side * (ROAD_WIDTH * 0.5 + 0.44)
				var start_z := -15.0 + curb_index * 2.0 + segment_offset
				var end_z := start_z + 2.0
				surface.set_color(color)
				var inner_start := Vector3(inner_x, 0.07, start_z)
				var inner_end := Vector3(inner_x, 0.07, end_z)
				var outer_start := Vector3(outer_x, 0.07, start_z)
				var outer_end := Vector3(outer_x, 0.07, end_z)
				var first := inner_start if side > 0.0 else outer_start
				var second := inner_end if side > 0.0 else outer_end
				var third := outer_end if side > 0.0 else inner_end
				var fourth := outer_start if side > 0.0 else inner_start
				surface.add_vertex(first)
				surface.add_vertex(second)
				surface.add_vertex(third)
				surface.add_vertex(first)
				surface.add_vertex(third)
				surface.add_vertex(fourth)

		_add_road_quad(
			surface,
			-5.675,
			-5.565,
			-15.0 + segment_offset,
			15.0 + segment_offset,
			Color("e7e5dd")
		)
		_add_road_quad(
			surface,
			5.565,
			5.675,
			-15.0 + segment_offset,
			15.0 + segment_offset,
			Color("e7e5dd")
		)
		for dash_index in range(4):
			var dash_z := -11.0 + dash_index * 7.0 + segment_offset
			_add_road_quad(surface, -0.08, 0.08, dash_z, dash_z + 3.2, Color("f1df9c"))

	surface.generate_normals()
	return surface.commit()


func _add_road_quad(
	surface: SurfaceTool,
	left_x: float,
	right_x: float,
	start_z: float,
	end_z: float,
	color: Color
) -> void:
	var first := Vector3(left_x, 0.071, start_z)
	var second := Vector3(left_x, 0.071, end_z)
	var third := Vector3(right_x, 0.071, end_z)
	var fourth := Vector3(right_x, 0.071, start_z)
	surface.set_color(color)
	surface.add_vertex(first)
	surface.set_color(color)
	surface.add_vertex(second)
	surface.set_color(color)
	surface.add_vertex(third)
	surface.set_color(color)
	surface.add_vertex(first)
	surface.set_color(color)
	surface.add_vertex(third)
	surface.set_color(color)
	surface.add_vertex(fourth)


func _create_car() -> void:
	_car = Node3D.new()
	_car.name = "RiftRunner"
	add_child(_car)

func _load_vehicle_model() -> void:
	var request_error := ResourceLoader.load_threaded_request(
		VEHICLE_SCENE_PATH,
		"PackedScene",
		true
	)
	if request_error != OK:
		_set_vehicle_asset_error(
			"Could not queue the licensed vehicle model (error %d)" % request_error
		)
		return

	while true:
		var status := ResourceLoader.load_threaded_get_status(VEHICLE_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED:
			_set_vehicle_asset_error("Could not load the licensed vehicle model")
			return
		if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_set_vehicle_asset_error("The licensed vehicle model path is invalid")
			return
		await get_tree().process_frame

	var vehicle_scene := ResourceLoader.load_threaded_get(VEHICLE_SCENE_PATH) as PackedScene
	if vehicle_scene == null:
		_set_vehicle_asset_error("The licensed vehicle resource is not a PackedScene")
		return
	var vehicle := vehicle_scene.instantiate() as Node3D
	if vehicle == null:
		_set_vehicle_asset_error("The licensed vehicle scene has no 3D root")
		return

	_remove_excluded_vehicle_marks(vehicle)
	if not _merge_vehicle_render_meshes(vehicle):
		_set_vehicle_asset_error("Could not optimize the licensed vehicle mesh")
		vehicle.free()
		return
	vehicle.name = "RiftRunner"
	vehicle.scale = Vector3.ONE
	vehicle.rotation.y = PI
	vehicle.position = Vector3(_vehicle.lateral_position, 0.0, 0.0)
	add_child(vehicle)
	_car.queue_free()
	_car = vehicle

	_vehicle_model_ready = true
	_vehicle_status_label.visible = false


func _merge_vehicle_render_meshes(vehicle: Node3D) -> bool:
	var wheel_pivots: Array[Node3D] = []
	var wheel_transforms: Array[Transform3D] = []
	for wheel_name in VEHICLE_WHEEL_NAMES:
		var wheel := vehicle.find_child(wheel_name, true, false) as Node3D
		if wheel == null:
			push_error("The vehicle asset is missing wheel pivot %s" % wheel_name)
			return false
		wheel_pivots.append(wheel)
		wheel_transforms.append(_vehicle_relative_transform(vehicle, wheel))

	var builders: Dictionary = {}
	var materials: Dictionary = {}
	var categories: Dictionary = {}
	for descendant in vehicle.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue

		var wheel_index := _vehicle_wheel_index(vehicle, mesh_instance, wheel_pivots)
		var transform_root := wheel_pivots[wheel_index] if wheel_index >= 0 else vehicle
		var relative_transform := _vehicle_relative_transform(transform_root, mesh_instance)
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var surface_material := mesh_instance.get_active_material(surface_index)
			if surface_material == null:
				surface_material = _material(Color.WHITE, 0.0, 1.0)
			var group_key := "%d:%d" % [wheel_index, surface_material.get_instance_id()]
			if not builders.has(group_key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				builder.set_material(surface_material)
				builders[group_key] = builder
				materials[group_key] = surface_material
				categories[group_key] = wheel_index
			(builders[group_key] as SurfaceTool).append_from(
				mesh_instance.mesh,
				surface_index,
				relative_transform
			)

	while vehicle.get_child_count() > 0:
		var child := vehicle.get_child(0)
		vehicle.remove_child(child)
		child.free()

	var optimized_wheels: Array[Node3D] = []
	for wheel_index in range(wheel_pivots.size()):
		var wheel := Node3D.new()
		wheel.name = VEHICLE_WHEEL_NAMES[wheel_index]
		wheel.transform = wheel_transforms[wheel_index]
		vehicle.add_child(wheel)
		optimized_wheels.append(wheel)

	for group_key in builders:
		var merged_mesh := (builders[group_key] as SurfaceTool).commit()
		if merged_mesh == null or merged_mesh.get_surface_count() != 1:
			push_error("Could not combine vehicle render group %s" % group_key)
			return false
		var merged_instance := MeshInstance3D.new()
		merged_instance.mesh = merged_mesh
		merged_instance.material_override = materials[group_key]
		var wheel_index: int = categories[group_key]
		if wheel_index >= 0:
			optimized_wheels[wheel_index].add_child(merged_instance)
		else:
			vehicle.add_child(merged_instance)

	_wheels = optimized_wheels
	_front_wheels = [optimized_wheels[0], optimized_wheels[1]]
	return true


func _vehicle_wheel_index(
	vehicle: Node3D,
	mesh_instance: MeshInstance3D,
	wheel_pivots: Array[Node3D]
) -> int:
	var ancestor: Node = mesh_instance
	while ancestor != null and ancestor != vehicle:
		for wheel_index in range(wheel_pivots.size()):
			if ancestor == wheel_pivots[wheel_index]:
				return wheel_index
		ancestor = ancestor.get_parent()
	return -1


func _vehicle_relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	return _relative_node_transform(ancestor, node)


func _relative_node_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var relative_transform := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != ancestor:
		var spatial_node := cursor as Node3D
		if spatial_node == null:
			push_error("Mesh hierarchy contains a non-3D transform node")
			return Transform3D.IDENTITY
		relative_transform = spatial_node.transform * relative_transform
		cursor = cursor.get_parent()
	if cursor != ancestor:
		push_error("Vehicle node is not a descendant of its expected transform root")
		return Transform3D.IDENTITY
	return relative_transform


func _remove_excluded_vehicle_marks(node: Node) -> void:
	for child in node.get_children():
		var normalized_name := String(child.name).to_lower().replace(" ", "")
		var excluded_mark := (
			normalized_name.contains("logo")
			or normalized_name.contains("emblem")
			or normalized_name.contains("khronos")
			or normalized_name.contains("3dcommerce")
			or normalized_name == "licenseplate"
		)
		if excluded_mark:
			node.remove_child(child)
			child.free()
		else:
			_remove_excluded_vehicle_marks(child)


func _set_vehicle_asset_error(message: String) -> void:
	push_error(message)
	_vehicle_status_label.text = "VEHICLE MODEL FAILED TO LOAD"
	_vehicle_status_label.add_theme_color_override("font_color", Color("ef4b3f"))
	_vehicle_status_label.visible = true


func _create_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "RaceCamera"
	_camera.position = Vector3(0.0, 5.1, 9.8)
	_camera.current = true
	_camera.fov = 68.0
	add_child(_camera)
	_camera.look_at_from_position(
		_camera.position,
		Vector3(0.0, 0.85, -16.0),
		Vector3.UP
	)


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
	_vehicle_status_label = Label.new()
	_vehicle_status_label.position = Vector2(286.0, 26.0)
	_vehicle_status_label.text = "LOADING VEHICLE"
	_vehicle_status_label.add_theme_font_size_override("font_size", 18)
	_vehicle_status_label.add_theme_color_override("font_color", Color("f2d28a"))
	layer.add_child(_vehicle_status_label)

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


func _textured_material(
	albedo_texture: Texture2D,
	normal_texture: Texture2D,
	roughness_texture: Texture2D,
	uv_scale: Vector3
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = albedo_texture
	if normal_texture != null:
		material.normal_enabled = true
		material.normal_texture = normal_texture
		material.normal_scale = 0.42
	if roughness_texture != null:
		material.roughness_texture = roughness_texture
	material.roughness = 0.92
	material.uv1_scale = uv_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
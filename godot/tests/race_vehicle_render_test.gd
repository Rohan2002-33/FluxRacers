extends SceneTree

const VEHICLE_SCENE_PATH := "res://assets/models/car_concept/CarConcept.glb"
const OPTIMIZED_VEHICLE_SCENE_PATH := "res://assets/models/car_concept/CarConceptOptimized.scn"
const WHEEL_NAMES := ["WheelFrontL", "WheelFrontR", "WheelRearL", "WheelRearR"]
const TRAFFIC_MODELS := preload("res://scripts/race_traffic_models.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var race_script := load("res://scripts/race_scene.gd") as Script
	var vehicle_scene := load(VEHICLE_SCENE_PATH) as PackedScene
	_assert(race_script != null, "The race scene script compiles")
	_assert(vehicle_scene != null, "The attributed vehicle scene loads")
	if race_script == null or vehicle_scene == null:
		quit(1)
		return

	for model_id in TRAFFIC_MODELS.IMPORTED_MODEL_PATHS:
		var imported_mesh: ArrayMesh = TRAFFIC_MODELS.build_body_mesh(model_id)
		var imported_spec: Dictionary = TRAFFIC_MODELS.get_spec(model_id)
		var imported_material := (
			imported_mesh.surface_get_material(0) as StandardMaterial3D
			if imported_mesh.get_surface_count() > 0
			else null
		)
		_assert(
			imported_mesh.get_surface_count() > 0,
			"%s imports as a renderable 3D vehicle" % model_id
		)
		_assert(
			imported_material != null and imported_material.albedo_texture != null,
			"%s retains the CC0 color-atlas texture" % model_id
		)
		var imported_attributes_compressed := imported_mesh.get_surface_count() > 0
		for surface_index in range(imported_mesh.get_surface_count()):
			if (
				imported_mesh.surface_get_format(surface_index)
				& Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
			) == 0:
				imported_attributes_compressed = false
		_assert(
			imported_attributes_compressed,
			"%s stores compressed vertex attributes" % model_id
		)
		_assert(
			TRAFFIC_MODELS.build_body_mesh(model_id) == imported_mesh,
			"%s reuses its cached mesh after the first load" % model_id
		)
		if imported_mesh.get_surface_count() > 0:
			var imported_bounds: AABB = imported_mesh.get_aabb()
			_assert(
				absf(imported_bounds.size.x - float(imported_spec["width"])) < 0.05
					and absf(imported_bounds.size.z - float(imported_spec["length"])) < 0.05,
				"%s matches its configured collision dimensions" % model_id
			)

	var race := race_script.new() as Node3D
	var vehicle := vehicle_scene.instantiate() as Node3D
	_assert(race != null and vehicle != null, "The scene creates a race root and vehicle")
	if race == null or vehicle == null:
		quit(1)
		return
	race.add_child(vehicle)
	race._remove_excluded_vehicle_marks(vehicle)
	race._traffic.configure(3, 25.0, 1234)
	race._selected_paint_color = Color("00bcd4")

	var source_mesh_nodes := _mesh_nodes(vehicle)
	var source_bounds: AABB = _mesh_bounds(race, vehicle, source_mesh_nodes)
	var wheel_transforms: Array[Transform3D] = []
	for wheel_name in WHEEL_NAMES:
		var wheel := vehicle.find_child(wheel_name, true, false) as Node3D
		_assert(wheel != null, "Source vehicle has wheel pivot %s" % wheel_name)
		if wheel != null:
			wheel_transforms.append(race._vehicle_relative_transform(vehicle, wheel))

	_assert(source_mesh_nodes.size() > 80, "Vehicle has enough separate source meshes to optimize")
	_assert(
		await race._merge_vehicle_render_meshes(vehicle),
		"Vehicle meshes merge successfully"
	)
	var optimized_vehicle_scene := load(OPTIMIZED_VEHICLE_SCENE_PATH) as PackedScene
	_assert(
		optimized_vehicle_scene != null,
		"The build-time optimized player vehicle scene is present"
	)
	if optimized_vehicle_scene != null:
		var optimized_vehicle := optimized_vehicle_scene.instantiate() as Node3D
		var optimized_race := race_script.new() as Node3D
		_assert(
			optimized_vehicle != null and optimized_race != null,
			"The optimized vehicle scene instantiates"
		)
		if optimized_vehicle != null and optimized_race != null:
			optimized_race.add_child(optimized_vehicle)
			optimized_race._selected_paint_color = Color("00bcd4")
			optimized_race._apply_selected_vehicle_paint(optimized_vehicle)
			var optimized_mesh_nodes := _mesh_nodes(optimized_vehicle)
			var optimized_bounds: AABB = _mesh_bounds(
				optimized_race,
				optimized_vehicle,
				optimized_mesh_nodes
			)
			_assert(
				optimized_mesh_nodes.size() <= 50,
				"The baked vehicle avoids the original per-frame mesh optimization"
			)
			_assert(
				source_bounds.position.distance_to(optimized_bounds.position) < 0.01
					and source_bounds.size.distance_to(optimized_bounds.size) < 0.01,
				"The baked vehicle preserves the source car's complete geometry"
			)
			var optimized_paint_found := false
			var optimized_attributes_compressed := not optimized_mesh_nodes.is_empty()
			for mesh_instance in optimized_mesh_nodes:
				for surface_index in range(mesh_instance.mesh.get_surface_count()):
					if (
						mesh_instance.mesh.surface_get_format(surface_index)
						& Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
					) == 0:
						optimized_attributes_compressed = false
				var paint_material := mesh_instance.material_override as StandardMaterial3D
				if (
					paint_material != null
					and paint_material.albedo_color.is_equal_approx(Color("00bcd4"))
				):
					optimized_paint_found = true
			_assert(
				optimized_paint_found,
				"Garage paint selection remains supported by the baked vehicle"
			)
			_assert(
				optimized_attributes_compressed,
				"The baked vehicle stores compressed vertex attributes"
			)
			optimized_race.free()
		elif optimized_race != null:
			optimized_race.free()
		elif optimized_vehicle != null:
			optimized_vehicle.free()
	_assert(
		await race._create_traffic_render_batch(),
		"Distinct procedural and imported models create GPU-instanced traffic"
	)
	_assert(
		race._traffic_model_batches.size() == 9,
		"Traffic includes nine different procedural and imported 3D models"
	)
	var varied_paint_seen: Dictionary = {}
	for model_id in race._traffic_model_batches:
		var batch: Dictionary = race._traffic_model_batches[model_id]
		var body_batch := batch["body"] as MultiMeshInstance3D
		var details_batch := batch["details"] as MultiMeshInstance3D
		var imported_model := TRAFFIC_MODELS.is_imported_model(model_id)
		_assert(
			body_batch != null and body_batch.multimesh.mesh.get_surface_count() >= 1,
			"%s uses a valid GPU-instanced body mesh" % model_id
		)
		if imported_model:
			_assert(not body_batch.multimesh.use_colors, "%s preserves its textured paint" % model_id)
			_assert(details_batch == null, "%s merges body and details into one render batch" % model_id)
			var imported_material := (
				body_batch.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
			)
			_assert(
				imported_material != null and imported_material.albedo_texture != null,
				"%s retains the licensed color-atlas texture" % model_id
			)
			var imported_spec: Dictionary = TRAFFIC_MODELS.get_spec(model_id)
			var imported_bounds: AABB = body_batch.multimesh.mesh.get_aabb()
			_assert(
				absf(imported_bounds.size.x - float(imported_spec["width"])) < 0.05
					and absf(imported_bounds.size.z - float(imported_spec["length"])) < 0.05,
				"%s is scaled to its collision dimensions" % model_id
			)
		else:
			_assert(
				body_batch.multimesh.use_colors
					and body_batch.multimesh.mesh.get_surface_count() == 1,
				"%s bodies use paintable single-surface instancing" % model_id
			)
			_assert(
				details_batch != null
					and details_batch.multimesh.mesh.get_surface_count() >= 5,
				"%s retains windows, lights, trim, tires and rims" % model_id
			)
	_assert(
		race._traffic.cars[0].paint_color != race._traffic.cars[1].paint_color,
		"Traffic model instances are assigned distinct body paint colors"
	)
	for traffic_car in race._traffic.cars:
		varied_paint_seen[traffic_car.paint_color.to_html()] = true
	_assert(varied_paint_seen.size() > 1, "Instanced traffic renders multiple paint colors")
	var truck_spec: Dictionary = TRAFFIC_MODELS.get_spec("box_truck")
	_assert(
		float(truck_spec["length"]) > 6.0
			and truck_spec["name"] == "BOX TRUCK",
		"The freight truck is a distinct full-size 3D vehicle"
	)
	if not _failed:
		var merged_mesh_nodes := _mesh_nodes(vehicle)
		print(
			"Vehicle mesh instances: %d -> %d"
			% [source_mesh_nodes.size(), merged_mesh_nodes.size()]
		)
		var merged_bounds: AABB = _mesh_bounds(race, vehicle, merged_mesh_nodes)
		_assert(
			merged_mesh_nodes.size() < source_mesh_nodes.size(),
			"Material batching reduces vehicle mesh render instances"
		)
		_assert(
			merged_mesh_nodes.size() <= 50,
			"Vehicle batching reduces the body and wheels to at most 50 mesh instances"
		)
		_assert(
			source_bounds.position.distance_to(merged_bounds.position) < 0.01
				and source_bounds.size.distance_to(merged_bounds.size) < 0.01,
			"Mesh batching preserves the complete vehicle geometry bounds"
		)
		_assert(race._wheels.size() == WHEEL_NAMES.size(), "Four wheel pivots remain animated")
		_assert(race._front_wheels.size() == 2, "Both front steering pivots remain available")
		var custom_paint_found := false
		for wheel_index in range(WHEEL_NAMES.size()):
			var merged_wheel := vehicle.find_child(WHEEL_NAMES[wheel_index], true, false) as Node3D
			_assert(merged_wheel != null, "Merged vehicle retains %s" % WHEEL_NAMES[wheel_index])
			if merged_wheel != null:
				var actual_transform: Transform3D = race._vehicle_relative_transform(
					vehicle,
					merged_wheel
				)
				_assert(
					actual_transform.is_equal_approx(wheel_transforms[wheel_index]),
					"Merged vehicle preserves the %s steering/rotation pivot"
					% WHEEL_NAMES[wheel_index]
				)
		for mesh_instance in merged_mesh_nodes:
			var paint_material := mesh_instance.material_override as StandardMaterial3D
			if (
				paint_material != null
				and paint_material.albedo_color.is_equal_approx(Color("00bcd4"))
			):
				custom_paint_found = true
		_assert(custom_paint_found, "Garage paint selection reaches the licensed car body")

	race.free()
	if _failed:
		quit(1)
	else:
		print("Godot vehicle render tests passed")
		quit(0)


func _mesh_nodes(node: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for descendant in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			result.append(mesh_instance)
	return result


func _mesh_bounds(
	race: Node3D,
	vehicle: Node3D,
	mesh_nodes: Array[MeshInstance3D]
) -> AABB:
	var bounds := AABB()
	var has_vertex := false
	for mesh_instance in mesh_nodes:
		var relative_transform: Transform3D = race._vehicle_relative_transform(
			vehicle,
			mesh_instance
		)
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex in vertices:
				var position: Vector3 = relative_transform * vertex
				if has_vertex:
					bounds = bounds.expand(position)
				else:
					bounds = AABB(position, Vector3.ZERO)
					has_vertex = true
	return bounds


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot vehicle render test failed: %s" % message)
		_failed = true

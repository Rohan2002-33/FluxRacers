extends SceneTree

const VEHICLE_SCENE_PATH := "res://assets/models/car_concept/CarConcept.glb"
const WHEEL_NAMES := ["WheelFrontL", "WheelFrontR", "WheelRearL", "WheelRearR"]

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

	var race := race_script.new() as Node3D
	var vehicle := vehicle_scene.instantiate() as Node3D
	_assert(race != null and vehicle != null, "The scene creates a race root and vehicle")
	if race == null or vehicle == null:
		quit(1)
		return
	root.add_child(race)
	race.add_child(vehicle)
	race._remove_excluded_vehicle_marks(vehicle)

	var source_mesh_nodes := _mesh_nodes(vehicle)
	var source_bounds: AABB = _mesh_bounds(race, vehicle, source_mesh_nodes)
	var wheel_transforms: Array[Transform3D] = []
	for wheel_name in WHEEL_NAMES:
		var wheel := vehicle.find_child(wheel_name, true, false) as Node3D
		_assert(wheel != null, "Source vehicle has wheel pivot %s" % wheel_name)
		if wheel != null:
			wheel_transforms.append(race._vehicle_relative_transform(vehicle, wheel))

	_assert(source_mesh_nodes.size() > 80, "Vehicle has enough separate source meshes to optimize")
	_assert(race._merge_vehicle_render_meshes(vehicle), "Vehicle meshes merge successfully")
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

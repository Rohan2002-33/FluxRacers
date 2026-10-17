extends SceneTree

const SHRUB_SCENE_PATHS := [
	"res://assets/models/shrub_03/shrub_03_1k.gltf",
	"res://assets/models/shrub_04/shrub_04_1k.gltf",
]
const INSTANCE_COUNT := 5
const SHRUB_RECYCLE_DISTANCE := 238.0

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var race_script := load("res://scripts/race_scene.gd") as Script
	_assert(race_script != null, "The race scene script compiles")
	if race_script == null:
		quit(1)
		return

	var race := race_script.new() as Node3D
	for scene_path in SHRUB_SCENE_PATHS:
		_test_shrub_scene(race, scene_path)
	if not _failed:
		_test_scrolling_and_recycling(race)

	race.free()
	if _failed:
		quit(1)
	else:
		print("Godot vegetation batch tests passed")
		quit(0)


func _test_shrub_scene(race: Node3D, scene_path: String) -> void:
	var shrub_scene := load(scene_path) as PackedScene
	_assert(shrub_scene != null, "The licensed shrub loads: %s" % scene_path)
	if shrub_scene == null:
		return
	var prototype := shrub_scene.instantiate() as Node3D
	_assert(prototype != null, "The shrub scene has a 3D root: %s" % scene_path)
	if prototype == null:
		return
	race.add_child(prototype)

	var source_meshes := _mesh_nodes(prototype)
	var source_bounds := _mesh_bounds(race, prototype, source_meshes)
	var source_material_ids: Dictionary = {}
	for mesh_instance in source_meshes:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index)
			if material != null:
				source_material_ids[material.get_instance_id()] = true

	var combined_mesh: ArrayMesh = race._combine_roadside_mesh(prototype)
	_assert(combined_mesh != null, "The shrub mesh combines: %s" % scene_path)
	if combined_mesh == null:
		prototype.free()
		return
	_assert(
		combined_mesh.get_surface_count() == maxi(1, source_material_ids.size()),
		"Material batches retain every original shrub surface group: %s" % scene_path
	)

	var combined_instance := MeshInstance3D.new()
	combined_instance.mesh = combined_mesh
	var combined_root := Node3D.new()
	combined_root.add_child(combined_instance)
	race.add_child(combined_root)
	var combined_bounds := _mesh_bounds(race, combined_root, [combined_instance])
	_assert(
		source_bounds.position.distance_to(combined_bounds.position) < 0.01
			and source_bounds.size.distance_to(combined_bounds.size) < 0.01,
		"Combining shrub meshes preserves the original geometry bounds: %s" % scene_path
	)
	if scene_path.ends_with("shrub_03_1k.gltf"):
		_assert(source_meshes.size() == 4, "Shrub 03 starts with four render meshes")
	_assert(
		combined_mesh.get_surface_count() <= source_meshes.size(),
		"Each shrub keeps no more material surfaces than source mesh instances"
	)
	print(
		"%s mesh instances: %d -> %d MultiMesh surfaces"
		% [scene_path.get_file(), source_meshes.size(), combined_mesh.get_surface_count()]
	)
	prototype.free()
	combined_root.free()


func _test_scrolling_and_recycling(race: Node3D) -> void:
	var batches: Array[MultiMeshInstance3D] = []
	for batch_index in range(2):
		var batch := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = BoxMesh.new()
		multimesh.instance_count = INSTANCE_COUNT
		var transforms: Array[Transform3D] = []
		for index in range(INSTANCE_COUNT):
			var transform := Transform3D(
				Basis.IDENTITY,
				Vector3(10.0 + batch_index, 0.0, -20.0 - index * 34.0)
			)
			transforms.append(transform)
			multimesh.set_instance_transform(index, transform)
		batch.multimesh = multimesh
		race.add_child(batch)
		race._shrub_batches.append(batch)
		race._shrub_instance_transforms.append_array(transforms)
		batches.append(batch)

	race._advance_shrub_instances(20.0)
	for batch_index in range(batches.size()):
		var transform_index := batch_index * INSTANCE_COUNT
		_assert(
			is_equal_approx(
				batches[batch_index].position.z
					+ race._shrub_instance_transforms[transform_index].origin.z,
				0.0
			),
			"Each shrub batch moves at the road's physical scroll distance"
		)

	for batch_index in range(batches.size()):
		var transform_index := batch_index * INSTANCE_COUNT
		var multimesh := batches[batch_index].multimesh
		var transform: Transform3D = race._shrub_instance_transforms[transform_index]
		transform.origin.z = 27.0
		race._shrub_instance_transforms[transform_index] = transform
		multimesh.set_instance_transform(0, transform)
	race._advance_shrub_instances(1.0)
	for batch_index in range(batches.size()):
		var transform_index := batch_index * INSTANCE_COUNT
		var recycled_z: float = (
			batches[batch_index].position.z
			+ race._shrub_instance_transforms[transform_index].origin.z
		)
		_assert(
			recycled_z < 0.0 and recycled_z > -SHRUB_RECYCLE_DISTANCE,
			"Each shrub species recycles behind the camera without popping"
		)


func _mesh_nodes(node: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for descendant in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			result.append(mesh_instance)
	return result


func _mesh_bounds(
	race: Node3D,
	mesh_root: Node3D,
	mesh_nodes: Array[MeshInstance3D]
) -> AABB:
	var bounds := AABB()
	var has_vertex := false
	for mesh_instance in mesh_nodes:
		var relative_transform: Transform3D = race._relative_node_transform(
			mesh_root,
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
		push_error("Godot vegetation batch test failed: %s" % message)
		_failed = true

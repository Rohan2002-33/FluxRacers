extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	print("Running race scene tests")
	var race_script := load("res://scripts/race_scene.gd") as Script
	if race_script == null or not race_script.can_instantiate():
		push_error("Godot race scene test failed: The race scene script must compile")
		quit(1)
		return

	var race := race_script.new() as Node3D
	if race == null:
		push_error("Godot race scene test failed: The race scene creates a Node3D")
		quit(1)
		return
	race._create_environment()
	race._create_road()
	race._create_roadside_palms()
	_assert(
		race._road_material.albedo_texture != null
			and race._road_material.normal_enabled
			and race._road_material.roughness_texture != null,
		"The road uses its diffuse, normal, and roughness maps"
	)
	_assert(
		race._terrain_material.albedo_texture != null
			and race._terrain_material.normal_enabled
			and race._terrain_material.roughness_texture == null,
		"The mobile terrain retains normal detail without sampling an extra roughness map"
	)
	_assert(race._road_batches.size() == 2, "The repeating road is reduced to two render batches")
	for road_batch in race._road_batches:
		_assert(
			road_batch.multimesh.instance_count == 8,
			"Each road batch preserves the full recycled segment pool"
		)
		_assert(
			road_batch.multimesh.mesh.get_surface_count() == 1,
			"Each road batch uses one render surface"
		)
	var markings_material := race._road_batches[1].material_override as StandardMaterial3D
	_assert(
		markings_material != null
			and markings_material.cull_mode == BaseMaterial3D.CULL_DISABLED
			and markings_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Lane markings and kerbs remain visible independent of face winding and lighting"
	)
	_assert(race._tree_batches.size() == 2, "Each palm species uses one draw batch")
	for tree_batch in race._tree_batches:
		_assert(
			tree_batch.multimesh.instance_count == 5,
			"Each species batch contains five roadside trees"
		)
		var palm_material := tree_batch.material_override as StandardMaterial3D
		_assert(
			tree_batch.multimesh.mesh.get_surface_count() == 1,
			"A complete palm uses one material surface"
		)
		_assert(
			palm_material != null
				and palm_material.vertex_color_use_as_albedo
				and palm_material.cull_mode == BaseMaterial3D.CULL_DISABLED,
			"Palm batches retain their green foliage and brown trunk vertex colors"
		)
	for transform in race._tree_instance_transforms:
		_assert(
			absf(transform.origin.x) > 6.0,
			"Palm instances remain outside the road edge"
		)
	var test_shrub := Node3D.new()
	test_shrub.position.z = -50.0
	race.add_child(test_shrub)
	race._vegetation.append(test_shrub)

	race._vehicle.speed_mps = 20.0
	race._update_road(1.0)
	_assert(
		is_equal_approx(race._road_batches[0].position.z, 20.0),
		"The batched road scrolls at the vehicle's physical speed"
	)
	_assert(
		race._road_material.uv1_offset.y > 0.0,
		"The asphalt texture advances with the moving road"
	)
	_assert(
		is_equal_approx(
			race._tree_batches[0].position.z + race._tree_instance_transforms[0].origin.z,
			5.0
		),
		"Instanced 3D palms move with the road using one transform per species batch"
	)
	_assert(
		is_equal_approx(test_shrub.position.z, -30.0),
		"Roadside shrubs move at the same rate as the road"
	)
	_assert(
		race._terrain_material.uv1_offset.y > 0.0,
		"The field texture scrolls with forward travel"
	)

	var tree_position_before_acceleration: float = (
		race._tree_batches[0].position.z + race._tree_instance_transforms[1].origin.z
	)
	var road_position_before_acceleration: float = (
		race._road_batches[0].position.z + race._road_instance_transforms[1].origin.z
	)
	race._vehicle.speed_mps = 40.0
	race._update_road(1.0)
	_assert(
		is_equal_approx(
			race._road_batches[0].position.z
				+ race._road_instance_transforms[1].origin.z
				- road_position_before_acceleration,
			40.0
		),
		"Road sections remain continuous while recycled in the shared render batch"
	)
	_assert(
		is_equal_approx(
			race._tree_batches[0].position.z
				+ race._tree_instance_transforms[1].origin.z
				- tree_position_before_acceleration,
			40.0
		),
		"Palm movement scales with physical vehicle speed"
	)
	_assert(
		is_equal_approx(race._vehicle.distance_m, 0.0),
		"World scrolling does not mutate vehicle distance telemetry"
	)

	var first_palm: Transform3D = race._tree_instance_transforms[0]
	first_palm.origin.z = 27.0
	race._tree_instance_transforms[0] = first_palm
	race._tree_batches[0].multimesh.set_instance_transform(0, first_palm)
	race._update_road(0.1)
	_assert(
		race._tree_batches[0].position.z + race._tree_instance_transforms[0].origin.z < 0.0
			and race._tree_batches[0].position.z
				+ race._tree_instance_transforms[0].origin.z
				> -200.0,
		"Roadside palm instances recycle without a near-field pop"
	)

	race.free()
	if _failed:
		quit(1)
	else:
		print("Godot race scene tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot race scene test failed: %s" % message)
		_failed = true

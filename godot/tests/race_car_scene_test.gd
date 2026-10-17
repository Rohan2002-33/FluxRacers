extends SceneTree

var _failed := false


func _init() -> void:
	_run_tests()


func _run_tests() -> void:
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
	race._create_car()
	race._create_camera()
	race._create_hud()

	_assert(
		race._camera != null and race._speed_label != null,
		"The first frame initializes the camera and speed HUD"
	)
	_assert(
		race._road_material.albedo_texture != null
			and race._road_material.normal_enabled
			and race._road_material.roughness_texture != null,
		"The road uses its diffuse, normal, and roughness maps"
	)
	_assert(
		race._terrain_material.albedo_texture != null
			and race._terrain_material.normal_enabled
			and race._terrain_material.roughness_texture != null,
		"The surrounding terrain uses its PBR maps"
	)
	_assert(race._road_segments.size() == 8, "The road uses a fixed segment pool")
	var test_tree := Node3D.new()
	test_tree.position.z = -40.0
	race.add_child(test_tree)
	race._trees.append(test_tree)
	var test_shrub := Node3D.new()
	test_shrub.position.z = -50.0
	race.add_child(test_shrub)
	race._vegetation.append(test_shrub)

	race._vehicle.speed_mps = 20.0
	race._update_road(1.0)
	_assert(
		is_equal_approx(race._road_segments[0].position.z, 20.0),
		"The road scrolls at the vehicle's physical speed"
	)
	_assert(
		is_equal_approx(test_tree.position.z, -20.0),
		"Real 3D trees move at the same rate as the road"
	)
	_assert(
		is_equal_approx(test_shrub.position.z, -30.0),
		"Roadside shrubs move at the same rate as the road"
	)
	_assert(
		race._terrain_material.uv1_offset.y > 0.0,
		"The field texture scrolls with forward travel"
	)

	var tree_position_before_acceleration: float = test_tree.position.z
	race._vehicle.speed_mps = 40.0
	race._update_road(1.0)
	_assert(
		is_equal_approx(test_tree.position.z - tree_position_before_acceleration, 40.0),
		"Roadside motion increases with vehicle speed"
	)
	_assert(
		is_equal_approx(race._vehicle.distance_m, 0.0),
		"World scrolling does not mutate vehicle distance telemetry"
	)

	test_tree.position.z = 27.0
	race._update_road(0.1)
	_assert(
		test_tree.position.z < 0.0 and test_tree.position.z > -200.0,
		"Roadside trees recycle beyond the camera without a near-field pop"
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

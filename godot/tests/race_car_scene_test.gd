extends SceneTree

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var packed_scene: PackedScene = load("res://scenes/race.tscn")
	var race: Node3D = packed_scene.instantiate()
	root.add_child(race)
	await process_frame

	_assert(race._car != null, "The race scene creates its car")
	_assert(race._car.name == "RiftRunner", "The original car has a stable scene identity")

	var road_forward := Vector3.FORWARD
	var car_forward: Vector3 = -race._car.global_transform.basis.z.normalized()
	_assert(
		car_forward.dot(road_forward) > 0.999,
		"The car points down the road's forward axis"
	)
	_assert(
		absf(race._car.global_rotation.y) < 0.001
			and absf(race._car.global_rotation.z) < 0.001,
		"The car remains parallel to the straight road"
	)

	var body: MeshInstance3D = race._car.get_node_or_null("SculptedBody")
	_assert(body != null, "The car has a separate sculpted 3D body mesh")
	if body != null:
		_assert(body.mesh.get_surface_count() > 0, "The body mesh has rendered geometry")
		_assert(
			body.mesh.get_faces().size() >= 100,
			"The body is a continuous modeled surface, not a box blockout"
		)

	_assert(
		race._car.get_node_or_null("CoupeGreenhouse") != null,
		"The car has a shaped cabin"
	)
	_assert(
		race._car.get_node_or_null("FrontWindshield") != null
			and race._car.get_node_or_null("RearWindow") != null,
		"The cabin has distinct front and rear glazing"
	)
	_assert(race._wheels.size() == 4, "The car has four independently modeled wheels")
	for wheel in race._wheels:
		var tire: MeshInstance3D = wheel.get_child(0)
		_assert(tire.mesh is CylinderMesh, "Each wheel has a 3D tire")
		_assert(
			is_equal_approx(wheel.position.y - 0.39, 0.04),
			"The tires meet the road surface"
		)

	race.queue_free()
	if _failed:
		quit(1)
	else:
		print("Godot car scene tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot car scene test failed: %s" % message)
		_failed = true

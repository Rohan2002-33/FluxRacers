extends SceneTree

var _failed := false

func _init() -> void:
	Engine.max_fps = 30
	call_deferred("_run_test")


func _run_test() -> void:
	var vehicle_scene_path := "res://assets/models/car_concept/CarConcept.glb"
	print("Loading the licensed Car Concept vehicle")
	var request_error := ResourceLoader.load_threaded_request(
		vehicle_scene_path,
		"PackedScene",
		true
	)
	if request_error != OK:
		push_error("Could not queue the licensed Car Concept GLB")
		quit(1)
		return
	var status := ResourceLoader.load_threaded_get_status(vehicle_scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await create_timer(0.05).timeout
		status = ResourceLoader.load_threaded_get_status(vehicle_scene_path)
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("The licensed Car Concept GLB failed to import")
		quit(1)
		return
	var vehicle_scene := ResourceLoader.load_threaded_get(vehicle_scene_path) as PackedScene
	if vehicle_scene == null:
		push_error("The licensed Car Concept GLB must import as a PackedScene")
		quit(1)
		return
	print("Loaded the licensed Car Concept vehicle")

	var vehicle := vehicle_scene.instantiate() as Node3D
	if vehicle == null:
		push_error("The licensed Car Concept scene must have a 3D root")
		quit(1)
		return
	var race_script := load("res://scripts/race_scene.gd") as Script
	if race_script == null or not race_script.can_instantiate():
		push_error("The race scene script must load for asset validation")
		quit(1)
		return
	var race := race_script.new() as Node3D
	race._remove_excluded_vehicle_marks(vehicle)

	vehicle.rotation.y = PI
	root.add_child(vehicle)

	var mesh_count := 0
	for node in vehicle.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_count += 1

	print("Imported concept car meshes: %d" % mesh_count)
	_assert(mesh_count >= 90, "The licensed car has detailed independent meshes")
	_assert(
		vehicle.find_child("InteriorSteeringEmblem", true, false) == null
			and vehicle.find_child("License Plate", true, false) == null,
		"Excluded logos and license plate are removed from the rendered vehicle"
	)
	for wheel_name in ["WheelFrontL", "WheelFrontR", "WheelRearL", "WheelRearR"]:
		_assert(
			vehicle.find_child(wheel_name, true, false) is Node3D,
			"The car has the independent wheel pivot %s" % wheel_name
		)
	var front_wheel := vehicle.find_child("WheelFrontL", true, false) as Node3D
	var rear_wheel := vehicle.find_child("WheelRearL", true, false) as Node3D
	_assert(
		front_wheel.global_position.z < rear_wheel.global_position.z,
		"The rotated vehicle faces the road's forward direction"
	)
	race.free()
	vehicle.free()
	if _failed:
		quit(1)
	else:
		print("Godot licensed vehicle asset tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot vehicle asset test failed: %s" % message)
		_failed = true

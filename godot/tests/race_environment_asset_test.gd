extends SceneTree

var _failed := false


func _init() -> void:
	Engine.max_fps = 30
	call_deferred("_run_tests")


func _run_tests() -> void:
	for scene_path in [
		"res://assets/models/shrub_03/shrub_03_1k.gltf",
		"res://assets/models/shrub_04/shrub_04_1k.gltf",
	]:
		print("Loading licensed vegetation scene: %s" % scene_path)
		var request_error := ResourceLoader.load_threaded_request(
			scene_path,
			"PackedScene",
			true
		)
		_assert(request_error == OK, "The licensed glTF load can be queued")
		if request_error != OK:
			continue
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await create_timer(0.05).timeout
			status = ResourceLoader.load_threaded_get_status(scene_path)
		_assert(
			status == ResourceLoader.THREAD_LOAD_LOADED,
			"The licensed glTF finishes loading"
		)
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			continue
		var packed_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
		_assert(packed_scene != null, "The licensed glTF imports as a PackedScene")
		if packed_scene == null:
			continue

		var plant := packed_scene.instantiate()
		_assert(plant is Node3D, "The glTF scene has a 3D root node")
		if plant is Node3D:
			_assert(
				plant.get_child_count() > 0,
				"The instantiated glTF contains visible 3D geometry"
			)
		plant.free()

	if _failed:
		quit(1)
	else:
		print("Godot environment asset tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot environment asset test failed: %s" % message)
		_failed = true

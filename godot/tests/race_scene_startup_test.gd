extends SceneTree

const RACE_SCENE_PATH := "res://scenes/race.tscn"

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var race_scene := load(RACE_SCENE_PATH) as PackedScene
	_assert(race_scene != null, "The race scene loads")
	if race_scene == null:
		quit(1)
		return

	for launch_index in range(2):
		var race := race_scene.instantiate() as Node
		_assert(race != null, "Race launch %d creates the 3D scene" % (launch_index + 1))
		if race == null:
			continue
		root.add_child(race)

		var ready := false
		for frame in range(600):
			await process_frame
			if (
				bool(race.get("_vehicle_model_ready"))
				or bool(race.get("_vehicle_asset_failed"))
			):
				ready = true
				break
		_assert(ready, "Race launch %d finishes vehicle loading" % (launch_index + 1))
		_assert(
			bool(race.get("_race_initialized")),
			"Race launch %d initializes gameplay" % (launch_index + 1)
		)
		_assert(
			not bool(race.get("_vehicle_asset_failed")),
			"Race launch %d reports no asset failure" % (launch_index + 1)
		)
		if bool(race.get("_vehicle_model_ready")):
			var loading_layer := race.get("_loading_layer") as CanvasLayer
			var traffic_batches: Dictionary = race.get("_traffic_model_batches")
			var traffic: RaceTraffic = race.get("_traffic")
			var car := race.get("_car") as Node3D
			_assert(
				not loading_layer.visible,
				"Race launch %d dismisses its loading screen when ready" % (launch_index + 1)
			)
			_assert(
				traffic_batches.size() == traffic.cars.size(),
				"Race launch %d batches each unique traffic model" % (launch_index + 1)
			)
			_assert(
				car != null and car.find_child("WheelFrontL", true, false) != null,
				"Race launch %d retains its optimized vehicle and wheel pivots" % (launch_index + 1)
			)
			if launch_index == 1 and car != null:
				var selected_paint := Color("00bcd4")
				race.set("_selected_paint_color", selected_paint)
				race.call("_apply_selected_vehicle_paint", car)
				var cached_paint_found := false
				for descendant in car.find_children("*", "MeshInstance3D", true, false):
					var mesh_instance := descendant as MeshInstance3D
					var paint_material := mesh_instance.material_override as StandardMaterial3D
					if (
						paint_material != null
						and paint_material.resource_name.to_lower().begins_with("paint ")
						and paint_material.albedo_color.is_equal_approx(selected_paint)
					):
						cached_paint_found = true
						break
				_assert(
					cached_paint_found,
					"A cached vehicle applies the newly selected garage paint"
				)

	if _failed:
		quit(1)
	else:
		print("Godot race startup tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot race startup test failed: %s" % message)
		_failed = true

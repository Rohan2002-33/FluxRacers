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
			var world_environment := race.get_node_or_null(
				"WorldEnvironment"
			) as WorldEnvironment
			_assert(
				world_environment != null
					and world_environment.environment.fog_enabled
					and world_environment.environment.fog_density > 0.0,
				"Race startup enables subtle depth fog for distant scenery"
			)
			_assert(
				not loading_layer.visible,
				"Race launch %d dismisses its loading screen when ready" % (launch_index + 1)
			)
			var road_markings := race.get_node_or_null(
				"RoadMarkings"
			) as MultiMeshInstance3D
			_assert(
				road_markings != null and road_markings.multimesh.instance_count == 8,
				"Race startup builds recycled road markings for all track segments"
			)
			var guardrails := race.get_node_or_null(
				"RoadsideGuardrails"
			) as MultiMeshInstance3D
			_assert(
				guardrails != null
					and guardrails.multimesh.instance_count == 8
					and guardrails.multimesh.mesh.get_surface_count() == 3,
				"Race startup builds batched rails, support posts, and reflector panels"
			)
			if guardrails != null:
				var guardrail_mesh := guardrails.multimesh.mesh as ArrayMesh
				var reflector_material := (
					guardrail_mesh.surface_get_material(2) as StandardMaterial3D
				)
				_assert(
					reflector_material != null
						and reflector_material.emission_enabled
						and reflector_material.emission == Color("e6a94f"),
					"Road-facing guardrail reflectors use warm emissive material"
				)
				var trackside_transforms: Array = race.get(
					"_trackside_instance_transforms"
				)
				var first_rail_z: float = (
					guardrails.position.z
					+ trackside_transforms[0].origin.z
				)
				race.call("_advance_trackside_batch", 30.0)
				_assert(
					is_equal_approx(guardrails.position.z, 30.0),
					"Guardrails scroll with the road at physical vehicle speed"
				)
				race.call("_advance_trackside_batch", 240.0)
				var recycled_rail_z: float = (
					guardrails.position.z
					+ trackside_transforms[0].origin.z
				)
				_assert(
					is_equal_approx(first_rail_z + 30.0, recycled_rail_z),
					"Guardrail segments recycle continuously without a trackside gap"
				)
			if road_markings != null:
				var marking_mesh := road_markings.multimesh.mesh as ArrayMesh
				var marking_arrays := marking_mesh.surface_get_arrays(0)
				var marking_vertices: PackedVector3Array = marking_arrays[Mesh.ARRAY_VERTEX]
				var marking_colors: PackedColorArray = marking_arrays[Mesh.ARRAY_COLOR]
				var left_lane_markings := 0
				var right_lane_markings := 0
				for vertex_index in range(marking_vertices.size()):
					if not marking_colors[vertex_index].is_equal_approx(Color("f1f1ea")):
						continue
					if absf(absf(marking_vertices[vertex_index].x) - 1.42) < 0.07:
						if marking_vertices[vertex_index].x < 0.0:
							left_lane_markings += 1
						else:
							right_lane_markings += 1
				_assert(
					left_lane_markings > 0 and right_lane_markings > 0,
					"Three-lane road has white dashed separators on both sides"
				)
			var camera := race.get("_camera") as Camera3D
			var vehicle: RaceVehicleModel = race.get("_vehicle")
			vehicle.speed_mps = vehicle.max_speed_kmh / 3.6
			race.call("_update_camera", 1.0)
			_assert(
				camera != null and camera.fov > 68.0 and camera.fov <= 73.0,
				"Chase camera widens smoothly as vehicle speed increases"
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

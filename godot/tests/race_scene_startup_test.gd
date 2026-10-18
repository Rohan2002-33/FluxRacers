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
			var track_lights := race.get_node_or_null(
				"RoadsideTrackLights"
			) as MultiMeshInstance3D
			_assert(
				track_lights != null
					and track_lights.multimesh != null
					and track_lights.multimesh.mesh != null
					and track_lights.multimesh.instance_count == 4
					and track_lights.multimesh.mesh.get_surface_count() == 3,
				"Race startup creates four instanced roadside light stations"
			)
			if (
				track_lights != null
				and track_lights.multimesh != null
				and track_lights.multimesh.mesh != null
			):
				var lights_mesh := track_lights.multimesh.mesh as ArrayMesh
				var lamp_material := (
					lights_mesh.surface_get_material(2) as StandardMaterial3D
				)
				_assert(
					lamp_material != null
						and lamp_material.emission_enabled
						and lamp_material.emission == Color("ffe4a3"),
					"Trackside lamps use warm emissive light panels"
				)
				var light_transforms: Array = race.get(
					"_trackside_light_transforms"
				)
				var first_light_z: float = (
					track_lights.position.z
					+ light_transforms[0].origin.z
				)
				race.call("_advance_trackside_lights", 30.0)
				race.call("_advance_trackside_lights", 240.0)
				var recycled_light_z: float = (
					track_lights.position.z
					+ light_transforms[0].origin.z
				)
				_assert(
					is_equal_approx(first_light_z + 30.0, recycled_light_z),
					"Trackside light stations recycle continuously with the road"
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
			var lane_studs := race.get_node_or_null(
				"RoadLaneStuds"
			) as MultiMeshInstance3D
			_assert(
				lane_studs != null
					and lane_studs.multimesh != null
					and lane_studs.multimesh.mesh != null
					and lane_studs.multimesh.instance_count == 8
					and lane_studs.multimesh.mesh.get_surface_count() == 1,
				"Race startup creates a recycled lane-stud mesh batch"
			)
			if (
				lane_studs != null
				and lane_studs.multimesh != null
				and lane_studs.multimesh.mesh != null
			):
				var lane_stud_material := (
					lane_studs.material_override as StandardMaterial3D
				)
				var stud_vertices: PackedVector3Array = (
					lane_studs.multimesh.mesh
					.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				)
				_assert(
					stud_vertices.size() >= 180
						and lane_stud_material != null
						and lane_stud_material.metallic > 0.0
						and lane_stud_material.roughness < 0.4,
					"Raised metallic reflectors are built along both lane separators"
				)
				var road_batches: Array = race.get("_road_batches")
				_assert(
					road_batches.size() == 3,
					"Road surface, paint and reflective studs share the recycled road loop"
				)
				race.call("_advance_road_batches", 15.0)
				_assert(
					is_equal_approx(lane_studs.position.z, 15.0),
					"Lane reflectors scroll in sync with the road surface"
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
			var player_shadow := race.get_node_or_null(
				"RiftRunner/VehicleContactShadow"
			) as MeshInstance3D
			var traffic_shadow := race.get_node_or_null(
				"TrafficContactShadows"
			) as MultiMeshInstance3D
			_assert(
				player_shadow != null
					and player_shadow.mesh is PlaneMesh
					and player_shadow.material_override is StandardMaterial3D
					and traffic_shadow != null
					and traffic_shadow.multimesh != null
					and traffic_shadow.multimesh.instance_count == traffic.cars.size(),
				"Player and traffic vehicles have lightweight contact-shadow geometry"
			)
			if (
				player_shadow != null
				and player_shadow.material_override is StandardMaterial3D
				and traffic_shadow != null
				and traffic_shadow.multimesh != null
			):
				var shadow_material := player_shadow.material_override as StandardMaterial3D
				var shadow_texture := shadow_material.albedo_texture as GradientTexture2D
				_assert(
					shadow_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA
						and shadow_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
						and shadow_texture != null
						and shadow_texture.fill == GradientTexture2D.FILL_RADIAL,
					"Contact shadows use soft radial alpha without extra lighting cost"
				)
				_assert(
					traffic_shadow.material_override is StandardMaterial3D
						and traffic_shadow.material_override == player_shadow.material_override,
					"Player and traffic contact shadows share one transparent material"
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

extends SceneTree

const RACE_SCENE_SCRIPT := preload("res://scripts/race_scene.gd")
const TRAFFIC_MODELS := preload("res://scripts/race_traffic_models.gd")
const VEHICLE_SOURCE_PATH := "res://assets/models/car_concept/CarConcept.glb"
const VEHICLE_OUTPUT_PATH := "res://assets/models/car_concept/CarConceptOptimized.scn"
const TRAFFIC_MESH_DIRECTORY := "res://assets/models/kenney_car_kit/merged"
const DEFAULT_PAINT := Color("b71923")


func _init() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var output_directory := ProjectSettings.globalize_path(TRAFFIC_MESH_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_directory)
	if directory_error != OK:
		push_error("Could not create baked traffic mesh directory (error %d)" % directory_error)
		quit(1)
		return

	for model_id in TRAFFIC_MODELS.IMPORTED_MODEL_PATHS:
		var mesh: ArrayMesh = TRAFFIC_MODELS.build_source_imported_model_mesh(model_id)
		if mesh.get_surface_count() == 0:
			push_error("Traffic mesh bake produced no surfaces for %s" % model_id)
			quit(1)
			return
		var output_path := "%s/%s.res" % [TRAFFIC_MESH_DIRECTORY, model_id]
		var save_error := ResourceSaver.save(mesh, output_path)
		if save_error != OK:
			push_error("Could not save baked traffic mesh %s (error %d)" % [output_path, save_error])
			quit(1)
			return
		print("[RaceAssetBake] traffic_mesh=%s surfaces=%d" % [model_id, mesh.get_surface_count()])

	if not await _bake_player_vehicle():
		quit(1)
		return
	quit(0)


func _bake_player_vehicle() -> bool:
	var source_scene := load(VEHICLE_SOURCE_PATH) as PackedScene
	if source_scene == null:
		push_error("Could not load source vehicle scene for offline optimization")
		return false
	var race := RACE_SCENE_SCRIPT.new() as Node3D
	var vehicle := source_scene.instantiate() as Node3D
	if race == null or vehicle == null:
		push_error("Could not instantiate the source vehicle for offline optimization")
		return false

	race.set("_selected_paint_color", DEFAULT_PAINT)
	race.add_child(vehicle)
	race._remove_excluded_vehicle_marks(vehicle)
	if not await race._merge_vehicle_render_meshes(vehicle):
		push_error("Could not optimize the source vehicle during offline asset baking")
		race.free()
		return false

	race._set_scene_owners(vehicle, vehicle)
	var optimized_scene := PackedScene.new()
	var pack_error := optimized_scene.pack(vehicle)
	if pack_error != OK:
		push_error("Could not pack the optimized vehicle scene (error %d)" % pack_error)
		race.free()
		return false
	var save_error := ResourceSaver.save(optimized_scene, VEHICLE_OUTPUT_PATH)
	race.free()
	if save_error != OK:
		push_error("Could not save the optimized vehicle scene (error %d)" % save_error)
		return false
	print("[RaceAssetBake] optimized_vehicle=%s" % VEHICLE_OUTPUT_PATH)
	return true

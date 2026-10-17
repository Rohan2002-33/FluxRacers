extends SceneTree

const PALM_TREE_GENERATOR := preload("res://scripts/race_palm_tree.gd")

var _failed := false


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	for species in [
		PALM_TREE_GENERATOR.COCONUT,
		PALM_TREE_GENERATOR.DATE,
	]:
		var palm := PALM_TREE_GENERATOR.build_tree(species) as Node3D
		_assert(palm != null, "%s palm creates a 3D model" % species)
		if palm == null:
			continue

		var palm_mesh := palm as MeshInstance3D
		_assert(palm_mesh.mesh != null, "%s palm has combined 3D geometry" % species)
		_assert(
			palm_mesh.mesh.get_surface_count() == 1,
			"%s palm geometry is merged into one draw surface" % species
		)
		_assert(
			palm_mesh.mesh.get_aabb().size.y >= 8.0,
			"%s palm has a full-height trunk and crown" % species
		)
		_assert(
			palm_mesh.mesh.get_aabb().size.x >= 8.0,
			"%s palm has a broad radial crown" % species
		)
		_assert(
			palm_mesh.mesh.get_faces().size() >= 2000,
			"%s palm fronds are modeled as detailed 3D geometry" % species
		)
		var colors := palm_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		var has_foliage := false
		var has_bark := false
		var has_fruit := false
		for color in colors:
			has_foliage = has_foliage or color.a < 0.25
			has_bark = has_bark or (color.a >= 0.25 and color.a < 0.75)
			has_fruit = has_fruit or color.a >= 0.75
		_assert(
			has_foliage and has_bark and has_fruit,
			"%s distinguishes green foliage, brown trunk, and natural fruit colors" % species
		)
		var palm_material := palm_mesh.material_override as StandardMaterial3D
		_assert(
			palm_material != null
				and palm_material.vertex_color_use_as_albedo
				and palm_material.cull_mode == BaseMaterial3D.CULL_DISABLED,
			"%s palm renders its authored foliage, bark, and fruit colors" % species
		)
		palm.free()

	if _failed:
		quit(1)
	else:
		print("Godot procedural palm tests passed")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("Godot palm test failed: %s" % message)
		_failed = true

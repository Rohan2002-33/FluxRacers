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

		var trunk := palm.get_node("Trunk") as MeshInstance3D
		var fronds := palm.get_node("Fronds") as MeshInstance3D
		var fruit := palm.get_node("Fruit") as MeshInstance3D
		_assert(trunk.mesh != null, "%s palm has trunk geometry" % species)
		_assert(fronds.mesh != null, "%s palm has 3D frond geometry" % species)
		_assert(fruit.mesh != null, "%s palm has distinct fruit geometry" % species)
		_assert(
			trunk.mesh.get_aabb().size.y >= 8.0,
			"%s palm has a tall trunk" % species
		)
		_assert(
			fronds.mesh.get_aabb().size.x >= 6.0,
			"%s palm has a broad radial crown" % species
		)
		_assert(
			fronds.mesh.get_faces().size() >= 2000,
			"%s palm fronds are modeled as detailed 3D geometry" % species
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

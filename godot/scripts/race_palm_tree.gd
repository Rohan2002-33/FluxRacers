class_name RacePalmTree
extends RefCounted

const COCONUT := "coconut"
const DATE := "date"


static func build_tree(species: String) -> Node3D:
	if species != COCONUT and species != DATE:
		push_error("Unsupported palm species: %s" % species)
		return null

	var is_coconut := species == COCONUT
	var tree := MeshInstance3D.new()
	tree.name = "CoconutPalm" if is_coconut else "DatePalm"

	var crown_height := 8.65 if is_coconut else 7.95
	tree.mesh = _combine_meshes([
		_build_trunk(9.2 if is_coconut else 8.4),
		_build_fronds(species, crown_height),
		_build_fruit(species, crown_height),
	])
	tree.material_override = _palm_material()

	return tree


static func _combine_meshes(meshes: Array[ArrayMesh]) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for mesh in meshes:
		var surface_arrays := mesh.surface_get_arrays(0)
		var surface_vertices := surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var vertex_offset := vertices.size()
		vertices.append_array(surface_vertices)
		normals.append_array(surface_arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		colors.append_array(surface_arrays[Mesh.ARRAY_COLOR] as PackedColorArray)
		var raw_indices: Variant = surface_arrays[Mesh.ARRAY_INDEX]
		if not raw_indices is PackedInt32Array or raw_indices.is_empty():
			for vertex_index in range(surface_vertices.size()):
				indices.append(vertex_offset + vertex_index)
		else:
			var surface_indices: PackedInt32Array = raw_indices
			for index in surface_indices:
				indices.append(vertex_offset + index)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var combined := ArrayMesh.new()
	combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return combined


static func _build_trunk(height: float) -> ArrayMesh:
	const RING_COUNT := 32
	const RADIAL_SEGMENTS := 14
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ring in range(RING_COUNT + 1):
		var t := float(ring) / RING_COUNT
		var radius := lerpf(0.62, 0.21, pow(t, 0.8))
		radius += 0.016 * sin(t * TAU * 18.0)
		if t < 0.14:
			radius += (1.0 - t / 0.14) * 0.15
		var center := Vector3(
			0.18 * sin(t * PI * 0.6),
			height * t,
			0.14 * sin(t * PI * 0.8)
		)
		var bark := _bark_color(ring)
		bark.a = 0.5
		for segment in range(RADIAL_SEGMENTS + 1):
			var angle := TAU * float(segment) / RADIAL_SEGMENTS
			var rib := 1.0 + 0.012 * sin(angle * 9.0 + t * 43.0)
			surface.set_color(bark)
			surface.add_vertex(
				center + Vector3(cos(angle) * radius * rib, 0.0, sin(angle) * radius * rib)
			)

	for ring in range(RING_COUNT):
		for segment in range(RADIAL_SEGMENTS):
			var first := ring * (RADIAL_SEGMENTS + 1) + segment
			var next_ring := first + RADIAL_SEGMENTS + 1
			surface.add_index(first)
			surface.add_index(next_ring)
			surface.add_index(next_ring + 1)
			surface.add_index(first)
			surface.add_index(next_ring + 1)
			surface.add_index(first + 1)

	surface.generate_normals()
	return surface.commit()


static func _bark_color(ring: int) -> Color:
	var band := ring % 4
	if band == 0:
		return Color("694530")
	if band == 1:
		return Color("9a704b")
	if band == 2:
		return Color("80583b")
	return Color("744c33")


static func _build_fronds(species: String, crown_height: float) -> ArrayMesh:
	var is_coconut := species == COCONUT
	var frond_count := 12 if is_coconut else 14
	var leaflet_pairs := 26 if is_coconut else 28
	var length := 5.0 if is_coconut else 4.0
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for frond in range(frond_count):
		var angle := TAU * float(frond) / frond_count + 0.12 * sin(float(frond) * 2.3)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var sideways := Vector3(direction.z, 0.0, -direction.x)
		var start := Vector3(0.18, crown_height, 0.14)
		var tip_drop := 2.1 if is_coconut else 1.05
		var frond_length := length * (0.94 + 0.06 * sin(float(frond) * 1.7))

		for section in range(10):
			var t0 := float(section) / 10.0
			var t1 := float(section + 1) / 10.0
			var p0 := _rachis_point(start, direction, frond_length, tip_drop, t0)
			var p1 := _rachis_point(start, direction, frond_length, tip_drop, t1)
			var width := lerpf(0.065, 0.024, t0)
			_add_strip(
				surface,
				p0 + sideways * width,
				p0 - sideways * width,
				p1 - sideways * width * 0.82,
				p1 + sideways * width * 0.82,
				_rachis_color(species, frond, section)
			)

		for pair_index in range(leaflet_pairs):
			var t := 0.12 + 0.82 * float(pair_index) / leaflet_pairs
			var base := _rachis_point(start, direction, frond_length, tip_drop, t)
			var envelope := pow(maxf(0.0, sin(PI * t)), 0.62)
			var leaflet_length := envelope * (0.58 if is_coconut else 0.46)
			leaflet_length *= 0.9 + 0.1 * sin(float(pair_index * 3 + frond) * 1.71)
			for side in [-1.0, 1.0]:
				var base_point: Vector3 = base + sideways * side * 0.035
				var mid: Vector3 = (
					base
					+ direction * (0.2 + 0.12 * t)
					+ sideways * side * leaflet_length * 0.59
					+ Vector3.UP * (-0.2 - 0.24 * t)
				)
				var tip: Vector3 = (
					base
					+ direction * (0.48 + 0.19 * t)
					+ sideways * side * leaflet_length
					+ Vector3.UP * (-0.38 - 0.65 * t)
				)
				var width := leaflet_length * 0.24
				var leaf_color := _leaflet_color(species, frond, pair_index)
				_add_leaflet_triangle(
					surface,
					base_point,
					mid + sideways * width,
					tip,
					leaf_color
				)
				_add_leaflet_triangle(
					surface,
					base_point,
					tip,
					mid - sideways * width,
					leaf_color
				)

	surface.generate_normals()
	return surface.commit()


static func _rachis_point(
	start: Vector3,
	direction: Vector3,
	length: float,
	tip_drop: float,
	t: float
) -> Vector3:
	return start + direction * (length * t) + Vector3.DOWN * (tip_drop * t * t)


static func _build_fruit(species: String, crown_height: float) -> ArrayMesh:
	var is_coconut := species == COCONUT
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	if is_coconut:
		for fruit_index in range(6):
			var angle := TAU * float(fruit_index) / 6.0
			var center := (
				Vector3(0.18, crown_height - 0.52, 0.14)
				+ Vector3(sin(angle) * 0.34, -0.26 - 0.1 * (fruit_index % 2), cos(angle) * 0.34)
			)
			var fruit_color := Color("748b42").lerp(Color("c7a34d"), float(fruit_index % 3) * 0.18)
			_add_ellipsoid(surface, center, Vector3(0.31, 0.38, 0.28), 7, 9, fruit_color)
	else:
		for bunch in range(4):
			var angle := TAU * float(bunch) / 4.0 + 0.3
			var radial := Vector3(sin(angle), 0.0, cos(angle))
			var bunch_origin := Vector3(0.18, crown_height - 0.34, 0.14) + radial * 0.24
			for fruit_index in range(9):
				var row := fruit_index / 3
				var column := fruit_index % 3
				var center := (
					bunch_origin
					+ radial * (0.06 * float(row))
					+ Vector3(
						cos(angle) * (float(column) - 1.0) * 0.12,
						-0.23 - row * 0.2,
						-sin(angle) * (float(column) - 1.0) * 0.12
					)
				)
				var ripeness := float((bunch + row + column) % 4) / 3.0
				var fruit_color := Color("497846").lerp(Color("9b5634"), ripeness)
				_add_ellipsoid(surface, center, Vector3(0.075, 0.12, 0.075), 5, 6, fruit_color)

	surface.generate_normals()
	return surface.commit()


static func _add_ellipsoid(
	surface: SurfaceTool,
	center: Vector3,
	radii: Vector3,
	rings: int,
	segments: int,
	color: Color
) -> void:
	for ring in range(rings):
		var latitude0 := -PI * 0.5 + PI * float(ring) / rings
		var latitude1 := -PI * 0.5 + PI * float(ring + 1) / rings
		for segment in range(segments):
			var longitude0 := TAU * float(segment) / segments
			var longitude1 := TAU * float(segment + 1) / segments
			var p00 := _sphere_point(center, radii, latitude0, longitude0)
			var p01 := _sphere_point(center, radii, latitude0, longitude1)
			var p10 := _sphere_point(center, radii, latitude1, longitude0)
			var p11 := _sphere_point(center, radii, latitude1, longitude1)
			_add_triangle(surface, p00, p10, p11, color)
			_add_triangle(surface, p00, p11, p01, color)


static func _sphere_point(
	center: Vector3,
	radii: Vector3,
	latitude: float,
	longitude: float
) -> Vector3:
	return center + Vector3(
		cos(latitude) * cos(longitude) * radii.x,
		sin(latitude) * radii.y,
		cos(latitude) * sin(longitude) * radii.z
	)


static func _add_strip(
	surface: SurfaceTool,
	first: Vector3,
	second: Vector3,
	third: Vector3,
	fourth: Vector3,
	color: Color
) -> void:
	_add_triangle(surface, first, second, third, color)
	_add_triangle(surface, first, third, fourth, color)


static func _add_triangle(
	surface: SurfaceTool,
	first: Vector3,
	second: Vector3,
	third: Vector3,
	color: Color
) -> void:
	surface.set_color(color)
	surface.add_vertex(first)
	surface.set_color(color)
	surface.add_vertex(second)
	surface.set_color(color)
	surface.add_vertex(third)


static func _add_leaflet_triangle(
	surface: SurfaceTool,
	first: Vector3,
	second: Vector3,
	third: Vector3,
	color: Color
) -> void:
	if (second - first).cross(third - first).y < 0.0:
		_add_triangle(surface, first, third, second, color)
	else:
		_add_triangle(surface, first, second, third, color)


static func _palm_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.84
	return material


static func _rachis_color(species: String, frond: int, section: int) -> Color:
	var variation := 0.94 + 0.025 * float((frond + section) % 4)
	var base := Color("82984c") if species == COCONUT else Color("788e43")
	var color := base * variation
	return Color(color.r, color.g, color.b, 0.0)


static func _leaflet_color(species: String, frond: int, pair_index: int) -> Color:
	var variation := 0.9 + 0.025 * float((frond * 3 + pair_index) % 5)
	var base := Color("62a64a") if species == COCONUT else Color("578f3d")
	var color := base * variation
	return Color(color.r, color.g, color.b, 0.0)

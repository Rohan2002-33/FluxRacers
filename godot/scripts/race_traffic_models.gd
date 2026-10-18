class_name RaceTrafficModels
extends RefCounted

const MODEL_SPECS := {
	"sedan": {
		"name": "SEDAN",
		"width": 1.88,
		"length": 4.5,
		"body_height": 0.55,
		"cabin_width": 1.52,
		"cabin_length": 2.15,
		"cabin_height": 0.67,
		"cabin_center_z": -0.12,
	},
	"sport": {
		"name": "SPORT COUPE",
		"width": 1.86,
		"length": 4.35,
		"body_height": 0.48,
		"cabin_width": 1.5,
		"cabin_length": 1.7,
		"cabin_height": 0.52,
		"cabin_center_z": -0.05,
	},
	"suv": {
		"name": "SUV",
		"width": 2.02,
		"length": 4.85,
		"body_height": 0.69,
		"cabin_width": 1.7,
		"cabin_length": 2.55,
		"cabin_height": 0.76,
		"cabin_center_z": -0.08,
	},
	"pickup": {
		"name": "PICKUP TRUCK",
		"width": 2.08,
		"length": 5.55,
		"body_height": 0.66,
		"cabin_width": 1.74,
		"cabin_length": 1.85,
		"cabin_height": 0.68,
		"cabin_center_z": 0.82,
	},
	"box_truck": {
		"name": "BOX TRUCK",
		"width": 2.4,
		"length": 7.1,
		"body_height": 0.64,
		"cabin_width": 1.94,
		"cabin_length": 1.95,
		"cabin_height": 0.83,
		"cabin_center_z": 2.05,
	},
}

const WHEEL_RADIUS := 0.39
const WHEEL_MATERIAL_COLOR := Color("20242a")
const RIM_MATERIAL_COLOR := Color("aeb8bd")
const WINDOW_MATERIAL_COLOR := Color("172a39")
const TRIM_MATERIAL_COLOR := Color("303840")
const HEADLIGHT_MATERIAL_COLOR := Color("f5e8ba")
const TAILLIGHT_MATERIAL_COLOR := Color("cf3028")

static var _paint_material: StandardMaterial3D
static var _detail_materials: Dictionary = {}


static func get_spec(model_id: String) -> Dictionary:
	if not MODEL_SPECS.has(model_id):
		push_error("Unknown traffic vehicle model: %s" % model_id)
		return MODEL_SPECS["sedan"]
	return MODEL_SPECS[model_id]


static func build_paint_material() -> StandardMaterial3D:
	if _paint_material == null:
		_paint_material = StandardMaterial3D.new()
		_paint_material.albedo_color = Color.WHITE
		_paint_material.vertex_color_use_as_albedo = true
		_paint_material.metallic = 0.28
		_paint_material.roughness = 0.3
	return _paint_material


static func build_body_mesh(model_id: String) -> ArrayMesh:
	var spec := get_spec(model_id)
	var width: float = spec["width"]
	var length: float = spec["length"]
	var height: float = spec["body_height"]
	var cabin_width: float = spec["cabin_width"]
	var cabin_length: float = spec["cabin_length"]
	var cabin_height: float = spec["cabin_height"]
	var cabin_center_z: float = spec["cabin_center_z"]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_painted_box(
		surface,
		Vector3(width, height, length * 0.9),
		Vector3(0.0, 0.58 + height * 0.5, 0.0)
	)
	var hood_length := (length - cabin_length) * 0.38
	_add_painted_box(
		surface,
		Vector3(width * 0.97, 0.22, hood_length),
		Vector3(0.0, 0.58 + height + 0.09, length * 0.3)
	)
	var trunk_length := (length - cabin_length) * 0.32
	_add_painted_box(
		surface,
		Vector3(width * 0.96, 0.2, trunk_length),
		Vector3(0.0, 0.58 + height + 0.08, -length * 0.31)
	)

	if model_id == "pickup":
		_add_pickup_bed(surface, width, length, height)
	elif model_id == "box_truck":
		_add_box_truck_cargo(surface, width, height)

	var cabin_base_y := 0.58 + height * 0.8
	var pillar_width := maxf(0.11, cabin_width * 0.085)
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			_add_painted_box(
				surface,
				Vector3(pillar_width, cabin_height, 0.16),
				Vector3(
					side * (cabin_width * 0.5 - pillar_width * 0.5),
					cabin_base_y + cabin_height * 0.45,
					cabin_center_z + end * cabin_length * 0.4
				)
			)
	_add_painted_box(
		surface,
		Vector3(cabin_width, 0.16, cabin_length * 0.92),
		Vector3(0.0, cabin_base_y + cabin_height * 0.91, cabin_center_z)
	)

	var body_mesh := surface.commit() as ArrayMesh
	if body_mesh == null:
		push_error("Could not create the %s traffic body mesh" % model_id)
		return ArrayMesh.new()
	body_mesh.surface_set_material(0, build_paint_material())
	return body_mesh


static func _add_painted_box(
	surface: SurfaceTool,
	size: Vector3,
	position: Vector3
) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if indices.is_empty():
		for vertex_index in range(vertices.size()):
			surface.set_color(Color.WHITE)
			surface.set_normal(normals[vertex_index])
			surface.add_vertex(position + vertices[vertex_index])
		return
	for vertex_index in indices:
		surface.set_color(Color.WHITE)
		surface.set_normal(normals[vertex_index])
		surface.add_vertex(position + vertices[vertex_index])


static func build_detail_mesh(model_id: String) -> ArrayMesh:
	var spec := get_spec(model_id)
	var builders: Dictionary = {}
	var materials := _get_detail_materials()
	for material_id in materials:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		builders[material_id] = surface

	var width: float = spec["width"]
	var length: float = spec["length"]
	var body_height: float = spec["body_height"]
	var cabin_width: float = spec["cabin_width"]
	var cabin_length: float = spec["cabin_length"]
	var cabin_height: float = spec["cabin_height"]
	var cabin_center_z: float = spec["cabin_center_z"]
	var body_top := 0.58 + body_height
	var cabin_bottom := 0.58 + body_height * 0.8
	var pillar_width := maxf(0.11, cabin_width * 0.085)
	var window_height := maxf(0.27, cabin_height * 0.58)
	var window_y := cabin_bottom + cabin_height * 0.48

	for side in [-1.0, 1.0]:
		_add_box(
			builders["glass"] as SurfaceTool,
			Vector3(0.025, window_height, cabin_length * 0.67),
			Vector3(side * (cabin_width * 0.5 + 0.012), window_y, cabin_center_z)
		)
	_add_box(
		builders["glass"] as SurfaceTool,
		Vector3(cabin_width * 0.78, window_height, 0.035),
		Vector3(0.0, window_y, cabin_center_z + cabin_length * 0.42)
	)
	_add_box(
		builders["glass"] as SurfaceTool,
		Vector3(cabin_width * 0.78, window_height, 0.035),
		Vector3(0.0, window_y, cabin_center_z - cabin_length * 0.42)
	)

	var wheelbase_z := length * 0.32
	for side in [-1.0, 1.0]:
		for axle in [-1.0, 1.0]:
			_add_cylinder(
				builders["tire"] as SurfaceTool,
				WHEEL_RADIUS,
				WHEEL_RADIUS,
				0.26,
				Vector3(side * (width * 0.5 + 0.045), WHEEL_RADIUS, axle * wheelbase_z)
			)
			_add_cylinder(
				builders["rim"] as SurfaceTool,
				WHEEL_RADIUS * 0.53,
				WHEEL_RADIUS * 0.53,
				0.275,
				Vector3(side * (width * 0.5 + 0.045), WHEEL_RADIUS, axle * wheelbase_z)
			)

	var front_z := length * 0.45
	var rear_z := -length * 0.45
	_add_box(
		builders["trim"] as SurfaceTool,
		Vector3(width * 0.92, 0.13, 0.15),
		Vector3(0.0, 0.48, front_z)
	)
	_add_box(
		builders["trim"] as SurfaceTool,
		Vector3(width * 0.92, 0.13, 0.15),
		Vector3(0.0, 0.48, rear_z)
	)
	for side in [-1.0, 1.0]:
		_add_box(
			builders["headlight"] as SurfaceTool,
			Vector3(width * 0.22, 0.14, 0.035),
			Vector3(side * width * 0.31, body_top - 0.08, front_z + 0.02)
		)
		_add_box(
			builders["taillight"] as SurfaceTool,
			Vector3(width * 0.16, 0.2, 0.035),
			Vector3(side * width * 0.36, body_top - 0.06, rear_z - 0.02)
		)
	_add_box(
		builders["trim"] as SurfaceTool,
		Vector3(width * 0.34, 0.26, 0.04),
		Vector3(0.0, body_top - 0.2, front_z + 0.025)
	)

	if model_id == "pickup":
		_add_pickup_bed_details(builders["trim"] as SurfaceTool, width, length, body_height)
	elif model_id == "box_truck":
		_add_box_truck_details(
			builders["trim"] as SurfaceTool,
			width,
			length,
			body_height,
			cabin_center_z
		)

	var detail_mesh := ArrayMesh.new()
	for material_id in builders:
		var surface := (builders[material_id] as SurfaceTool).commit()
		if surface == null or surface.get_surface_count() != 1:
			push_error("Could not create %s traffic detail surface: %s" % [model_id, material_id])
			return ArrayMesh.new()
		detail_mesh.add_surface_from_arrays(
			surface.surface_get_primitive_type(0),
			surface.surface_get_arrays(0)
		)
		detail_mesh.surface_set_material(
			detail_mesh.get_surface_count() - 1,
			materials[material_id]
		)
	return detail_mesh


static func _add_pickup_bed(surface: SurfaceTool, width: float, length: float, height: float) -> void:
	var bed_width := width * 0.77
	var bed_length := length * 0.3
	var bed_center_z := -length * 0.29
	var rail_height := 0.35
	var rail_y := 0.58 + height + rail_height * 0.5
	_add_painted_box(
		surface,
		Vector3(bed_width, 0.08, bed_length),
		Vector3(0.0, 0.58 + height + 0.04, bed_center_z)
	)
	for side in [-1.0, 1.0]:
		_add_painted_box(
			surface,
			Vector3(0.12, rail_height, bed_length),
			Vector3(side * bed_width * 0.5, rail_y, bed_center_z)
		)


static func _add_pickup_bed_details(
	surface: SurfaceTool,
	width: float,
	length: float,
	height: float
) -> void:
	var bed_width := width * 0.77
	var bed_length := length * 0.3
	var bed_center_z := -length * 0.29
	for side in [-1.0, 1.0]:
		_add_box(
			surface,
			Vector3(0.035, 0.06, bed_length * 0.82),
			Vector3(
				side * (bed_width * 0.5 - 0.07),
				0.58 + height + 0.12,
				bed_center_z
			)
		)


static func _add_box_truck_cargo(surface: SurfaceTool, width: float, height: float) -> void:
	_add_painted_box(
		surface,
		Vector3(width * 0.95, 1.95, 3.65),
		Vector3(0.0, 0.58 + height + 1.0, -0.43)
	)


static func _add_box_truck_details(
	surface: SurfaceTool,
	width: float,
	length: float,
	height: float,
	cabin_center_z: float
) -> void:
	_add_box(
		surface,
		Vector3(width * 0.84, 0.08, 0.035),
		Vector3(0.0, 0.63 + height + 1.72, -0.43 - length * 0.27)
	)
	_add_box(
		surface,
		Vector3(width * 0.97, 0.11, 0.13),
		Vector3(0.0, 0.5, length * 0.45)
	)
	_add_box(
		surface,
		Vector3(0.04, 0.17, 0.04),
		Vector3(-width * 0.44, 1.45, cabin_center_z + 0.8)
	)
	_add_box(
		surface,
		Vector3(0.04, 0.17, 0.04),
		Vector3(width * 0.44, 1.45, cabin_center_z + 0.8)
	)


static func _append_box(
	surface: SurfaceTool,
	size: Vector3,
	position: Vector3
) -> void:
	var box := BoxMesh.new()
	box.size = size
	surface.append_from(box, 0, Transform3D(Basis.IDENTITY, position))


static func _append_cylinder(
	surface: SurfaceTool,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position: Vector3
) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 1
	surface.append_from(
		cylinder,
		0,
		Transform3D(Basis(Vector3.FORWARD, PI * 0.5), position)
	)


static func _add_box(
	surface: SurfaceTool,
	size: Vector3,
	position: Vector3
) -> void:
	_append_box(surface, size, position)


static func _add_cylinder(
	surface: SurfaceTool,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position: Vector3
) -> void:
	_append_cylinder(surface, top_radius, bottom_radius, height, position)


static func _get_detail_materials() -> Dictionary:
	if _detail_materials.is_empty():
		_detail_materials = {
			"glass": _create_material(WINDOW_MATERIAL_COLOR, 0.32, 0.19),
			"headlight": _create_material(
				HEADLIGHT_MATERIAL_COLOR,
				0.12,
				0.28,
				HEADLIGHT_MATERIAL_COLOR
			),
			"rim": _create_material(RIM_MATERIAL_COLOR, 0.78, 0.27),
			"taillight": _create_material(
				TAILLIGHT_MATERIAL_COLOR,
				0.08,
				0.3,
				TAILLIGHT_MATERIAL_COLOR * 0.4
			),
			"tire": _create_material(WHEEL_MATERIAL_COLOR, 0.02, 0.88),
			"trim": _create_material(TRIM_MATERIAL_COLOR, 0.42, 0.38),
		}
	return _detail_materials


static func _create_material(
	color: Color,
	metallic: float,
	roughness: float,
	emission_color: Color = Color.BLACK
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission_color != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission_color
	return material

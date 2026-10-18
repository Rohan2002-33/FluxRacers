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

const IMPORTED_MODEL_PATHS := {
	"kenney_truck": "res://assets/models/kenney_car_kit/truck.glb",
	"kenney_suv": "res://assets/models/kenney_car_kit/suv.glb",
	"kenney_sports_sedan": "res://assets/models/kenney_car_kit/sedan-sports.glb",
	"kenney_garbage_truck": "res://assets/models/kenney_car_kit/garbage-truck.glb",
	"kenney_hatchback": "res://assets/models/kenney_car_kit/hatchback-sports.glb",
	"kenney_delivery": "res://assets/models/kenney_car_kit/delivery.glb",
	"kenney_taxi": "res://assets/models/kenney_car_kit/taxi.glb",
	"kenney_ambulance": "res://assets/models/kenney_car_kit/ambulance.glb",
	"kenney_flatbed": "res://assets/models/kenney_car_kit/truck-flat.glb",
	"kenney_van": "res://assets/models/kenney_car_kit/van.glb",
	"kenney_police": "res://assets/models/kenney_car_kit/police.glb",
	"kenney_fire_truck": "res://assets/models/kenney_car_kit/firetruck.glb",
	"kenney_luxury_suv": "res://assets/models/kenney_car_kit/suv-luxury.glb",
	"kenney_race_car": "res://assets/models/kenney_car_kit/race.glb",
}

const IMPORTED_MODEL_SPECS := {
	"kenney_truck": {"name": "DELIVERY TRUCK", "width": 2.15, "length": 6.1, "height": 2.25},
	"kenney_suv": {"name": "CROSSOVER SUV", "width": 2.02, "length": 4.85, "height": 1.85},
	"kenney_sports_sedan": {"name": "SPORT SEDAN", "width": 1.9, "length": 4.55, "height": 1.5},
	"kenney_garbage_truck": {"name": "GARBAGE TRUCK", "width": 2.4, "length": 7.2, "height": 2.8},
	"kenney_hatchback": {"name": "SPORT HATCHBACK", "width": 1.85, "length": 4.15, "height": 1.48},
	"kenney_delivery": {"name": "DELIVERY VAN", "width": 2.05, "length": 5.35, "height": 2.3},
	"kenney_taxi": {"name": "CITY TAXI", "width": 1.9, "length": 4.5, "height": 1.5},
	"kenney_ambulance": {"name": "AMBULANCE", "width": 2.05, "length": 5.2, "height": 2.35},
	"kenney_flatbed": {"name": "FLATBED TRUCK", "width": 2.2, "length": 6.5, "height": 2.2},
	"kenney_van": {"name": "PASSENGER VAN", "width": 2.0, "length": 5.1, "height": 2.25},
	"kenney_police": {"name": "POLICE CRUISER", "width": 1.9, "length": 4.55, "height": 1.52},
	"kenney_fire_truck": {"name": "FIRE ENGINE", "width": 2.4, "length": 7.1, "height": 2.75},
	"kenney_luxury_suv": {"name": "LUXURY SUV", "width": 2.05, "length": 5.0, "height": 1.9},
	"kenney_race_car": {"name": "RACE COUPE", "width": 1.9, "length": 4.35, "height": 1.38},
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
static var _imported_mesh_cache: Dictionary = {}


static func get_spec(model_id: String) -> Dictionary:
	if IMPORTED_MODEL_SPECS.has(model_id):
		return IMPORTED_MODEL_SPECS[model_id]
	if not MODEL_SPECS.has(model_id):
		push_error("Unknown traffic vehicle model: %s" % model_id)
		return MODEL_SPECS["sedan"]
	return MODEL_SPECS[model_id]


static func is_imported_model(model_id: String) -> bool:
	return IMPORTED_MODEL_PATHS.has(model_id)


static func build_paint_material() -> StandardMaterial3D:
	if _paint_material == null:
		_paint_material = StandardMaterial3D.new()
		_paint_material.albedo_color = Color.WHITE
		_paint_material.vertex_color_use_as_albedo = true
		_paint_material.metallic = 0.28
		_paint_material.roughness = 0.3
	return _paint_material


static func build_body_mesh(model_id: String) -> ArrayMesh:
	if is_imported_model(model_id):
		return _build_imported_model_mesh(model_id)
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


static func _build_imported_model_mesh(model_id: String) -> ArrayMesh:
	if _imported_mesh_cache.has(model_id):
		return _imported_mesh_cache[model_id] as ArrayMesh
	var baked_path := "res://assets/models/kenney_car_kit/merged/%s.res" % model_id
	var baked_mesh := load(baked_path) as ArrayMesh
	if baked_mesh == null:
		push_error("Could not load baked traffic mesh %s from %s" % [model_id, baked_path])
		return ArrayMesh.new()
	_imported_mesh_cache[model_id] = baked_mesh
	return baked_mesh

static func build_source_imported_model_mesh(model_id: String) -> ArrayMesh:
	if not is_imported_model(model_id):
		push_error("Cannot bake a non-imported traffic model: %s" % model_id)
		return ArrayMesh.new()
	return _merge_source_imported_model(model_id)


static func _merge_source_imported_model(model_id: String) -> ArrayMesh:
	var model_scene := load(IMPORTED_MODEL_PATHS[model_id]) as PackedScene
	if model_scene == null:
		push_error("Could not load imported traffic model: %s" % model_id)
		return ArrayMesh.new()
	var model_root := model_scene.instantiate() as Node3D
	if model_root == null:
		push_error("Imported traffic model has no 3D root: %s" % model_id)
		return ArrayMesh.new()

	var source_surfaces: Array[Dictionary] = []
	var bounds := AABB()
	var has_bounds := false
	for descendant in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := _relative_transform(model_root, mesh_instance)
		var mesh_bounds := relative_transform * mesh_instance.mesh.get_aabb()
		if has_bounds:
			bounds = bounds.merge(mesh_bounds)
		else:
			bounds = mesh_bounds
			has_bounds = true
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var surface_material := mesh_instance.get_active_material(surface_index)
			if surface_material == null:
				surface_material = StandardMaterial3D.new()
			source_surfaces.append(
				{
					"mesh": mesh_instance.mesh,
					"surface_index": surface_index,
					"material": surface_material,
					"transform": relative_transform,
				}
			)
	if not has_bounds or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		push_error("Imported traffic model contains no usable geometry: %s" % model_id)
		model_root.free()
		return ArrayMesh.new()

	var spec: Dictionary = get_spec(model_id)
	var model_scale := Vector3(
		float(spec["width"]) / bounds.size.x,
		float(spec["height"]) / bounds.size.y,
		float(spec["length"]) / bounds.size.z
	)
	var model_transform := Transform3D(
		Basis.from_scale(model_scale),
		Vector3(
			-bounds.get_center().x * model_scale.x,
			-bounds.position.y * model_scale.y,
			-bounds.get_center().z * model_scale.z
		)
	)
	var surface_builders: Dictionary = {}
	var materials: Dictionary = {}
	for source_surface in source_surfaces:
		var surface_material := source_surface["material"] as Material
		var material_id := str(surface_material.get_instance_id())
		if not surface_builders.has(material_id):
			var surface_builder := SurfaceTool.new()
			surface_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface_builder.set_material(surface_material)
			surface_builders[material_id] = surface_builder
			materials[material_id] = surface_material
		var source_mesh := source_surface["mesh"] as Mesh
		(surface_builders[material_id] as SurfaceTool).append_from(
			source_mesh,
			source_surface["surface_index"],
			model_transform * source_surface["transform"]
		)

	var combined_mesh := ArrayMesh.new()
	for material_id in surface_builders:
		var material_mesh := (surface_builders[material_id] as SurfaceTool).commit(
			null,
			Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		)
		if material_mesh == null or material_mesh.get_surface_count() != 1:
			push_error("Could not combine imported traffic model: %s" % model_id)
			model_root.free()
			return ArrayMesh.new()
		combined_mesh.add_surface_from_arrays(
			material_mesh.surface_get_primitive_type(0),
			material_mesh.surface_get_arrays(0),
			[],
			{},
			Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
		)
		combined_mesh.surface_set_material(
			combined_mesh.get_surface_count() - 1,
			materials[material_id]
		)
	model_root.free()
	if combined_mesh.get_surface_count() == 0:
		push_error("Imported traffic model produced no render surfaces: %s" % model_id)
		return ArrayMesh.new()
	_imported_mesh_cache[model_id] = combined_mesh
	return combined_mesh


static func _relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var relative_transform := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != ancestor:
		var spatial_node := cursor as Node3D
		if spatial_node == null:
			push_error("Imported traffic hierarchy contains a non-3D transform node")
			return Transform3D.IDENTITY
		relative_transform = spatial_node.transform * relative_transform
		cursor = cursor.get_parent()
	if cursor != ancestor:
		push_error("Imported traffic mesh is outside its expected model root")
		return Transform3D.IDENTITY
	return relative_transform


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
	if is_imported_model(model_id):
		return ArrayMesh.new()
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

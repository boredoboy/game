extends Node3D
## Stylized anime-inspired survivor assembled from reusable 3D primitives.

@export_range(0, 2) var style_variant := 0
@export var idle_motion := true

var _parts: Array[Node3D] = []
var _clock := 0.0
var _shirt_color := Color("364d58")
var _hair_color := Color("19252d")
var _accent_color := Color("c87569")

func _ready() -> void:
	if style_variant == 1:
		_shirt_color = Color("66524b")
		_hair_color = Color("e5b56d")
		_accent_color = Color("8a5149")
	elif style_variant == 2:
		_shirt_color = Color("394e45")
		_hair_color = Color("856f9f")
		_accent_color = Color("ba9b62")
	_build_model()

func _process(delta: float) -> void:
	if idle_motion:
		_clock += delta
		rotation.y = sin(_clock * 0.45) * 0.12
		position.y = sin(_clock * 1.1) * 0.025

func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = metallic
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	material.specular_mode = BaseMaterial3D.SPECULAR_TOON
	return material

func _mesh(name: String, geometry: PrimitiveMesh, at: Vector3, scale_by: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = geometry
	instance.position = at
	instance.scale = scale_by
	instance.material_override = _material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)
	_parts.append(instance)
	return instance

func _sphere(name: String, at: Vector3, scale_by: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	return _mesh(name, mesh, at, scale_by, color)

func _capsule(name: String, at: Vector3, scale_by: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.8
	return _mesh(name, mesh, at, scale_by, color)

func _cylinder(name: String, at: Vector3, scale_by: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	return _mesh(name, mesh, at, scale_by, color)

func _build_model() -> void:
	# Backpack and jacket silhouette.
	_cylinder("utility_skirt", Vector3(0, 0.91, 0), Vector3(0.62, 0.42, 0.42), _accent_color)
	var jacket := _capsule("jacket", Vector3(0, 1.28, 0), Vector3(0.56, 0.62, 0.37), _shirt_color)
	var jacket_material := jacket.material_override as StandardMaterial3D
	jacket_material.albedo_texture = load("res://assets/textures/packs/characters/field_cloth.png")
	_cylinder("collar", Vector3(0, 1.62, -0.01), Vector3(0.28, 0.1, 0.26), Color("ded0bd"))
	var head := _sphere("head", Vector3(0, 1.91, -0.01), Vector3(0.51, 0.57, 0.47), Color("f1c8ad"))
	var skin_material := head.material_override as StandardMaterial3D
	skin_material.albedo_texture = load("res://assets/textures/packs/characters/soft_skin.png")
	# Back hair, top cap, side locks and graphic bangs.
	var hair := _sphere("hair_back", Vector3(0, 1.93, 0.105), Vector3(0.56, 0.65, 0.48), _hair_color)
	var hair_material := hair.material_override as StandardMaterial3D
	hair_material.albedo_texture = load("res://assets/textures/packs/characters/anime_hair.png")
	_sphere("face", Vector3(0, 1.88, -0.158), Vector3(0.42, 0.43, 0.16), Color("f1c8ad"))
	_sphere("bang_left", Vector3(-0.105, 2.075, -0.18), Vector3(0.24, 0.2, 0.18), _hair_color)
	_sphere("bang_right", Vector3(0.105, 2.07, -0.18), Vector3(0.24, 0.19, 0.18), _hair_color)
	_sphere("side_lock_left", Vector3(-0.235, 1.79, -0.035), Vector3(0.15, 0.43, 0.19), _hair_color)
	_sphere("side_lock_right", Vector3(0.235, 1.79, -0.035), Vector3(0.15, 0.43, 0.19), _hair_color)
	# Large stylized eyes with bright irises and small catchlights.
	for side in [-1.0, 1.0]:
		_sphere("eye_white", Vector3(side * 0.105, 1.91, -0.242), Vector3(0.083, 0.12, 0.035), Color("fff0df"))
		_sphere("iris", Vector3(side * 0.105, 1.91, -0.272), Vector3(0.044, 0.078, 0.025), Color("80c5c3" if style_variant != 1 else "a77354"))
		_sphere("pupil", Vector3(side * 0.105, 1.91, -0.292), Vector3(0.022, 0.05, 0.015), Color("1b2528"))
		_sphere("eye_glint", Vector3(side * 0.093, 1.94, -0.306), Vector3(0.018, 0.022, 0.01), Color.WHITE)
	# Arms, gloves, legs and boots.
	for side in [-1.0, 1.0]:
		var arm := _capsule("sleeve", Vector3(side * 0.34, 1.23, -0.015), Vector3(0.17, 0.48, 0.17), _shirt_color)
		arm.rotation.z = side * -0.16
		_capsule("glove", Vector3(side * 0.39, 0.92, -0.08), Vector3(0.12, 0.21, 0.12), Color("282d30"))
		_capsule("leg", Vector3(side * 0.16, 0.49, 0.01), Vector3(0.19, 0.48, 0.19), Color("343b40"))
		_sphere("boot", Vector3(side * 0.16, 0.105, -0.065), Vector3(0.24, 0.15, 0.34), Color("20272a"))
	# Shoulder straps, radio pack and chest emblem.
	_cylinder("radio_pack", Vector3(0, 1.27, 0.24), Vector3(0.36, 0.5, 0.22), Color("252f31"))
	var emblem := _sphere("unit_patch", Vector3(0.0, 1.38, -0.19), Vector3(0.12, 0.13, 0.035), Color("e9c67f"))
	emblem.rotation.z = PI / 4.0

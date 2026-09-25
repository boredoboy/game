extends Node3D
## First-person rifle view model: visual geometry, recoil and muzzle flash.

var muzzle_light: OmniLight3D
var flash_clock := 0.0
var bob := 0.0

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	if flash_clock > 0.0:
		flash_clock -= delta
		if flash_clock <= 0.0:
			muzzle_light.light_energy = 0.0
	position.y = bob

func set_walk_bob(value: float) -> void:
	bob = value

func fire_fx() -> void:
	position.z = 0.08
	var tween := create_tween()
	tween.tween_property(self, "position:z", 0.0, 0.09)
	muzzle_light.light_energy = 4.0
	flash_clock = 0.055

func _build() -> void:
	_box("receiver", Vector3(0, 0, 0), Vector3(0.15, 0.15, 0.48), Color("343b40"), 0.55, 0.7)
	_box("upper", Vector3(0, 0.09, -0.08), Vector3(0.18, 0.07, 0.3), Color("20282c"), 0.42, 0.75)
	_box("barrel", Vector3(0, 0.025, -0.48), Vector3(0.055, 0.055, 0.52), Color("202528"), 0.34, 0.82)
	_box("muzzle", Vector3(0, 0.025, -0.76), Vector3(0.09, 0.09, 0.08), Color("111618"), 0.4, 0.65)
	_box("handguard", Vector3(0, 0.025, -0.31), Vector3(0.12, 0.12, 0.24), Color("4a4b43"), 0.86, 0.0)
	_box("stock", Vector3(0, -0.025, 0.28), Vector3(0.13, 0.19, 0.23), Color("554c41"), 0.82, 0.0)
	_box("grip", Vector3(0, -0.17, 0.08), Vector3(0.09, 0.2, 0.1), Color("292c2d"), 0.72, 0.0)
	_box("sight", Vector3(0, 0.14, -0.2), Vector3(0.08, 0.07, 0.1), Color("181e21"), 0.3, 0.8)
	muzzle_light = OmniLight3D.new()
	muzzle_light.position = Vector3(0, 0.02, -0.82)
	muzzle_light.omni_range = 4.0
	muzzle_light.light_color = Color("ffb25e")
	muzzle_light.light_energy = 0.0
	add_child(muzzle_light)

func _box(part_name: String, at: Vector3, size: Vector3, color: Color, roughness: float, metallic: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)

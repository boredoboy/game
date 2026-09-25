extends CharacterBody3D

signal died(points: int)

const HIT_SOUND := preload("res://assets/audio/packs/core_sfx/actors/zombies/zombie_hit.wav")
const GROWL_SOUND := preload("res://assets/audio/packs/voice_pack/zombie_groan.wav")
const WALK_SPEED := 1.65

@export var elite := false
@export var max_health := 100.0
var health := 100.0
var attack_clock := 0.0
var growl_clock := 3.0
var animation_clock := 0.0
var limbs: Array[Node3D] = []
var audio_player: AudioStreamPlayer3D
var alive := true

func _ready() -> void:
	add_to_group("zombies")
	if elite:
		max_health = 155.0
	health = max_health
	_build_visual()
	audio_player = AudioStreamPlayer3D.new()
	audio_player.max_distance = 22.0
	audio_player.volume_db = linear_to_db(maxf(float(GameSettings.get_value("sfx_volume")) * 0.72, 0.001))
	add_child(audio_player)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	attack_clock -= delta
	growl_clock -= delta
	var target: Node3D = GameManager.player
	if not is_instance_valid(target):
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > 1.38:
		var direction := offset.normalized()
		if _has_wall_ahead(direction):
			var left := Vector3(-direction.z, 0.0, direction.x)
			var right := -left
			if not _has_wall_ahead((direction * 0.18 + left).normalized()):
				direction = (direction * 0.18 + left).normalized()
			elif not _has_wall_ahead((direction * 0.18 + right).normalized()):
				direction = (direction * 0.18 + right).normalized()
		velocity.x = direction.x * (WALK_SPEED * (0.78 if elite else 1.0))
		velocity.z = direction.z * (WALK_SPEED * (0.78 if elite else 1.0))
		rotation.y = atan2(-direction.x, -direction.z)
		animation_clock += delta * 7.0
		for i in limbs.size():
			limbs[i].rotation.x = sin(animation_clock + float(i % 2) * PI) * (0.42 if i < 2 else 0.34)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 9.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 9.0 * delta)
		if attack_clock <= 0.0:
			attack_clock = 1.05
			if target.has_method("take_damage"):
				target.call("take_damage", 14.0 if elite else 9.0)
	if growl_clock <= 0.0 and audio_player:
		growl_clock = randf_range(5.0, 10.0)
		audio_player.stream = GROWL_SOUND
		audio_player.play()
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _has_wall_ahead(direction: Vector3) -> bool:
	var origin := global_position + Vector3.UP * 0.82
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.05)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func take_damage(amount: float, _hit_position := Vector3.ZERO) -> void:
	if not alive:
		return
	health -= amount
	if audio_player:
		audio_player.stream = HIT_SOUND
		audio_player.play()
	if health <= 0.0:
		alive = false
		GameManager.register_kill(180 if elite else 100)
		died.emit(180 if elite else 100)
		var tween := create_tween()
		tween.tween_property(self, "rotation:z", deg_to_rad(82.0), 0.18)
		tween.tween_callback(queue_free)

func _build_visual() -> void:
	var skin := Color("747b68") if not elite else Color("666953")
	var shirt := Color("45504a") if not elite else Color("59473d")
	_box("torso", Vector3(0, 1.19, 0), Vector3(0.62, 0.76, 0.38), shirt)
	_sphere("head", Vector3(0, 1.82, -0.025), Vector3(0.46, 0.48, 0.42), skin)
	_box("jaw", Vector3(0, 1.62, -0.18), Vector3(0.25, 0.1, 0.15), skin)
	_sphere("wound", Vector3(0.18, 1.27, -0.198), Vector3(0.19, 0.16, 0.035), Color("702b25"))
	for side in [-1.0, 1.0]:
		_sphere("eye", Vector3(side * 0.09, 1.86, -0.222), Vector3(0.055, 0.05, 0.025), Color("ff4934"), true)
		var arm := _capsule("arm", Vector3(side * 0.38, 1.26, -0.025), Vector3(0.18, 0.68, 0.17), shirt)
		limbs.append(arm)
		_capsule("hand", Vector3(side * 0.41, 0.89, -0.11), Vector3(0.13, 0.25, 0.12), skin)
		var leg := _capsule("leg", Vector3(side * 0.17, 0.55, 0.015), Vector3(0.21, 0.63, 0.2), Color("353c39"))
		limbs.append(leg)
		_box("shoe", Vector3(side * 0.17, 0.11, -0.07), Vector3(0.24, 0.16, 0.34), Color("252a29"))

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _box(part_name: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _make_mesh(part_name, mesh, at, Vector3.ONE, color)

func _sphere(part_name: String, at: Vector3, scale_by: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var part := _make_mesh(part_name, mesh, at, scale_by, color)
	if emissive:
		var material := part.material_override as StandardMaterial3D
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return part

func _capsule(part_name: String, at: Vector3, scale_by: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.8
	return _make_mesh(part_name, mesh, at, scale_by, color)

func _make_mesh(part_name: String, geometry: PrimitiveMesh, at: Vector3, scale_by: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = geometry
	part.position = at
	part.scale = scale_by
	part.material_override = _material(color)
	add_child(part)
	return part

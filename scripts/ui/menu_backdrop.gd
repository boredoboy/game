extends Node3D

const SURVIVOR_SCRIPT := preload("res://scripts/characters/anime_survivor.gd")
const AMBIENCE := preload("res://assets/audio/packs/ambience_pack/industrial_dawn.wav")
var clock := 0.0
var characters: Array[Node3D] = []
var ambience_player: AudioStreamPlayer

func _ready() -> void:
	_build_environment()
	_build_stage()
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = AMBIENCE
	ambience_player.volume_db = linear_to_db(maxf(float(GameSettings.get_value("music_volume")), 0.001))
	add_child(ambience_player)
	ambience_player.finished.connect(_play_ambience)
	ambience_player.play()
	GameSettings.setting_changed.connect(_on_setting_changed)
	for i in 3:
		var character: Variant = Node3D.new()
		character.set_script(SURVIVOR_SCRIPT)
		character.style_variant = i
		character.idle_motion = false
		character.position = Vector3(4.8 + (i - 1) * 1.0, 0.0, -2.0 - (i % 2) * 0.5)
		character.scale = Vector3.ONE * (1.08 if i == 0 else 0.89)
		add_child(character)
		characters.append(character)
	var camera := Camera3D.new()
	camera.position = Vector3(0.5, 2.45, 9.2)
	camera.look_at(Vector3(2.4, 1.12, -1.0), Vector3.UP)
	camera.fov = 45.0
	add_child(camera)
	camera.current = true

func _process(delta: float) -> void:
	clock += delta
	for i in characters.size():
		characters[i].rotation.y = -0.08 + sin(clock * 0.5 + float(i)) * 0.045
		characters[i].position.y = sin(clock * 1.1 + float(i)) * 0.018

func _play_ambience() -> void:
	if is_instance_valid(ambience_player):
		ambience_player.play()

func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "music_volume" and ambience_player:
		ambience_player.volume_db = linear_to_db(maxf(float(value), 0.001))

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("111b22")
	sky_mat.sky_horizon_color = Color("8a6551")
	sky_mat.ground_bottom_color = Color("101516")
	sky_mat.ground_horizon_color = Color("514439")
	sky_mat.energy_multiplier = 0.7
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8da0a4")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.018
	env.fog_light_color = Color("879091")
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38, -28, 0)
	key_light.light_color = Color("d0c6ad")
	key_light.light_energy = 1.25
	key_light.shadow_enabled = true
	add_child(key_light)
	var rim := OmniLight3D.new()
	rim.position = Vector3(5.0, 5.0, -2.0)
	rim.light_color = Color("ef9d5c")
	rim.light_energy = 5.5
	rim.omni_range = 10.0
	add_child(rim)
	var cool := OmniLight3D.new()
	cool.position = Vector3(1.0, 4.2, 2.0)
	cool.light_color = Color("84b7c1")
	cool.light_energy = 2.5
	cool.omni_range = 9.0
	add_child(cool)

func _build_stage() -> void:
	_box(Vector3(0, -0.25, -1), Vector3(70, 0.5, 70), Color("333a3b"))
	_box(Vector3(4, 1.6, -3), Vector3(8, 3.2, 1.4), Color("38464a"))
	_box(Vector3(8.3, 1.4, -4.1), Vector3(1.3, 2.8, 1.5), Color("615143"))
	_box(Vector3(4.4, 3.22, -3), Vector3(8.3, 0.15, 1.55), Color("222a2d"))
	for x in [0.3, 2.5, 4.7, 6.9, 9.1]:
		_box(Vector3(x, 1.6, -2.25), Vector3(0.06, 2.8, 0.08), Color("1b2428"))
	for x in [-3.0, -1.2, 10.5]:
		_box(Vector3(x, 1.0, -1.0), Vector3(1.0, 2.0, 1.0), Color("49473d"))
	_box(Vector3(3.8, 4.4, -2.2), Vector3(3.5, 0.12, 0.12), Color("c08b57"), 0.1)

func _box(at: Vector3, size: Vector3, color: Color, roughness := 0.86) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(instance)

extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/characters/zombie.tscn")
const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const AMBIENCE := preload("res://assets/audio/packs/ambience_pack/industrial_dawn.wav")

var player: CharacterBody3D
var hud: CanvasLayer
var wave := 0
var live_enemies := 0
var transition_running := false
var rng := RandomNumberGenerator.new()
var ambience_player: AudioStreamPlayer

func _ready() -> void:
	rng.randomize()
	_build_world()
	ambience_player = AudioStreamPlayer.new()
	ambience_player.stream = AMBIENCE
	ambience_player.volume_db = linear_to_db(maxf(float(GameSettings.get_value("music_volume")), 0.001))
	add_child(ambience_player)
	ambience_player.finished.connect(_loop_ambience)
	ambience_player.play()
	GameSettings.setting_changed.connect(_on_setting_changed)
	player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0, 0.05, 7)
	add_child(player)
	GameManager.begin_run(player)
	for i in 3:
		var ally: Variant = COMPANION_SCENE.instantiate()
		ally.style_variant = i
		ally.target_player = player
		ally.get_node("Visual").set("style_variant", i)
		add_child(ally)
		ally.position = Vector3(float(i - 1) * 1.3, 0.03, 8.6)
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)
	hud.call("setup", player)
	await get_tree().create_timer(2.2).timeout
	_spawn_wave()

func _process(_delta: float) -> void:
	if live_enemies == 0 and wave > 0 and not transition_running and not get_tree().paused:
		transition_running = true
		await get_tree().create_timer(2.5).timeout
		if is_inside_tree() and not get_tree().paused:
			_spawn_wave()
		transition_running = false

func _spawn_wave() -> void:
	wave += 1
	GameManager.set_wave(wave)
	if wave > 1 and is_instance_valid(player):
		player.call("add_reserve_ammo", 36)
	live_enemies = mini(4 + wave * 2, 30)
	if hud and hud.has_method("set_wave"):
		hud.call("set_wave", wave)
	for i in live_enemies:
		var zombie: Variant = ZOMBIE_SCENE.instantiate()
		zombie.elite = wave >= 3 and i % 5 == 4
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(17.0, 24.0)
		zombie.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		zombie.died.connect(_on_zombie_died)
		add_child(zombie)

func _on_zombie_died(_points: int) -> void:
	live_enemies = maxi(0, live_enemies - 1)

func _loop_ambience() -> void:
	if is_instance_valid(ambience_player):
		ambience_player.play()

func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "music_volume" and ambience_player:
		ambience_player.volume_db = linear_to_db(maxf(float(value), 0.001))

func _build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("18262e")
	sky_material.sky_horizon_color = Color("a38469")
	sky_material.ground_bottom_color = Color("171a19")
	sky_material.ground_horizon_color = Color("675649")
	sky_material.energy_multiplier = 0.55
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("85959a")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("889294")
	environment.fog_density = 0.012
	world_environment.environment = environment
	add_child(world_environment)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-54, -32, 0)
	moon.light_color = Color("a8c5d4")
	moon.light_energy = 1.15
	moon.shadow_enabled = GameSettings.shadows_enabled()
	var shadow_quality := str(GameSettings.get_value("quality"))
	moon.directional_shadow_max_distance = 52.0 if shadow_quality == "Высокое" else 30.0
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if shadow_quality == "Высокое" else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 5.5, -4)
	fill.light_color = Color("ffb875")
	fill.light_energy = 2.1
	fill.omni_range = 22.0
	add_child(fill)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = load("res://assets/textures/packs/environment/tarmac.png")
	ground_material.uv1_scale = Vector3(8, 8, 1)
	ground_material.roughness = 0.95
	_solid_box("Tarmac", Vector3(0, -0.2, 0), Vector3(70, 0.4, 70), ground_material)
	var wall_material := _mat(Color("424b4b"), 0.92)
	wall_material.albedo_texture = load("res://assets/textures/packs/environment/concrete.png")
	wall_material.uv1_scale = Vector3(4, 2, 1)
	var container_material := StandardMaterial3D.new()
	container_material.albedo_texture = load("res://assets/textures/packs/environment/rusted_metal.png")
	container_material.uv1_scale = Vector3(3, 1, 1)
	container_material.roughness = 0.82
	for wall in [[Vector3(0, 3, -34), Vector3(70, 6, 1)], [Vector3(0, 3, 34), Vector3(70, 6, 1)], [Vector3(-34, 3, 0), Vector3(1, 6, 70)], [Vector3(34, 3, 0), Vector3(1, 6, 70)]]:
		_solid_box("Perimeter wall", wall[0], wall[1], wall_material)
	_solid_box("Cargo container west", Vector3(-18, 1.55, -14), Vector3(12, 3.1, 3.2), container_material)
	_solid_box("Cargo container east", Vector3(18, 1.55, -17), Vector3(13, 3.1, 3.2), container_material)
	_solid_box("Cargo container south", Vector3(-18, 1.55, 16), Vector3(12, 3.1, 3.2), container_material)
	_solid_box("Warehouse", Vector3(0, 5, -33), Vector3(29, 10, 1.3), wall_material)
	var crate_material := StandardMaterial3D.new()
	crate_material.albedo_texture = load("res://assets/textures/packs/environment/crate_wood.png")
	crate_material.roughness = 0.9
	for point in [Vector3(-8, 0.7, 1), Vector3(8, 0.7, -4), Vector3(-3, 0.7, -10), Vector3(13, 0.7, 5), Vector3(-14, 0.7, -4), Vector3(4, 0.7, 13)]:
		_solid_box("Cover crate", point, Vector3(1.5, 1.4, 1.4), crate_material)
	for point in [Vector3(-24, 5.8, -3), Vector3(24, 5.8, -8), Vector3(-24, 5.8, 23), Vector3(24, 5.8, 23), Vector3(0, 5.8, -26)]:
		var lamp := OmniLight3D.new()
		lamp.position = point
		lamp.light_color = Color("f4a95f")
		lamp.light_energy = 3.2
		lamp.omni_range = 13.0
		add_child(lamp)
		_solid_box("Industrial lamp", point + Vector3(0, 0.45, 0), Vector3(0.7, 0.22, 0.45), _mat(Color("ffc475"), 0.35, 0.1))
	# Long road lines and scattered light pools give the space scale and depth.
	for x in [-28.0, -14.0, 0.0, 14.0, 28.0]:
		_visual_box("Road marking", Vector3(x, 0.012, 0), Vector3(0.08, 0.018, 48), _mat(Color("9e8458"), 0.95))
	var hazard_material := StandardMaterial3D.new()
	hazard_material.albedo_texture = load("res://assets/textures/packs/environment/hazard_stripe.png")
	hazard_material.uv1_scale = Vector3(4, 1, 1)
	hazard_material.roughness = 0.86
	_visual_box("Warehouse hazard stripe", Vector3(0, 1.05, -32.28), Vector3(10, 0.24, 0.05), hazard_material)

func _solid_box(part_name: String, at: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = part_name
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(visual)
	add_child(body)
	return body

func _visual_box(part_name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = part_name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	add_child(visual)
	return visual

func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

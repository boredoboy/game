extends Node3D

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")
const HUD_SCRIPT := preload("res://scripts/ui/forest_hud.gd")
const FLASHLIGHT_SCRIPT := preload("res://scripts/characters/flashlight_follow.gd")
const WOOD_TEXTURE := preload("res://assets/textures/packs/environment/crate_wood.png")
const NOTE_POINTS: Array[Vector2] = [
	Vector2(-14, 54), Vector2(10, 49), Vector2(-25, 37), Vector2(27, 27),
	Vector2(-36, 21), Vector2(35, 10), Vector2(-20, 8), Vector2(5, 16),
	Vector2(22, -2), Vector2(-38, -5), Vector2(38, -18), Vector2(-14, -25),
	Vector2(10, -38), Vector2(42, -40), Vector2(-44, -34), Vector2(-26, -54),
	Vector2(21, -58), Vector2(9, 62)
]
const PATH_POINTS: Array[Vector2] = [
	Vector2(0, 73), Vector2(0, 58), Vector2(-12, 44), Vector2(-24, 30),
	Vector2(-9, 16), Vector2(14, 0), Vector2(25, -18), Vector2(7, -34),
	Vector2(-5, -50), Vector2(0, -73)
]
const CABIN_POINTS: Array[Vector2] = [Vector2(-49, 4), Vector2(47, 33), Vector2(-51, -46), Vector2(48, -53)]
const NOTE_TEXTS: Array[String] = [
	"Если фонарь дрогнул, не оборачивайся сразу.",
	"Юна сказала, что тропа здесь меняется каждую ночь.",
	"У него нет лица. Но он всегда смотрит прямо на тебя.",
	"Не сходи с тропы у оврага. Земля там проваливается.",
	"Я увидел его между соснами. Моргнул — и он стал ближе.",
	"Старая хижина пустая. Голоса идут не изнутри.",
	"Юна знает дорогу к вышке. Держись рядом с ней.",
	"Бумаги отмечают путь. Собери все восемнадцать.",
	"Не свети ему в лицо. У него всё равно нет глаз.",
	"Когда лес замолкает, слышно, как он переставляет ноги.",
	"За северным склоном должен быть старый сигнальный огонь.",
	"Он двигается только тогда, когда ты смотришь в другую сторону.",
	"Если увидел длинные руки, беги к свету, не к домам.",
	"Юна не бросит тебя. Я слышал, как она звала меня по имени.",
	"В тумане не видно вершин, но они всё ещё над тобой.",
	"Не считай шаги. Считай листы. Осталось совсем немного.",
	"Сигнальная вышка за поворотом. Дойди туда вместе.",
	"Если читаешь это у фонаря, значит, ты почти выбрался."
]

var rng := RandomNumberGenerator.new()
var terrain_noise := FastNoiseLite.new()
var player: CharacterBody3D
var partner: CharacterBody3D
var hud: CanvasLayer
var stalker: Node3D
var tree_positions: Array[Vector3] = []
var pages: Array[Area3D] = []
var note_count := 0
var exit_position := Vector3.ZERO
var completed := false
var hint_clock := 0.0

func _ready() -> void:
	rng.seed = 70418
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.024
	terrain_noise.fractal_octaves = 3
	_build_environment()
	_build_terrain()
	_build_mountains()
	_build_forest()
	_build_cabins()
	_build_exit()
	_spawn_player_and_partner()
	_build_hud()
	hud.call("show_toast", "18 листов на деревьях. Найди вышку и выберись вместе с Юной.", 7.0)

func _process(delta: float) -> void:
	if not is_instance_valid(player) or completed:
		return
	hint_clock += delta
	var nearest_page: Area3D
	var nearest_distance := 2.65
	for page in pages:
		if not is_instance_valid(page):
			continue
		var distance := player.global_position.distance_to(page.global_position)
		if distance < nearest_distance:
			nearest_page = page
			nearest_distance = distance
	if nearest_page and Input.is_action_just_pressed("interact"):
		_collect_page(nearest_page)
	var at_exit := player.global_position.distance_to(exit_position) < 8.5
	var partner_near := is_instance_valid(partner) and partner.global_position.distance_to(exit_position) < 11.0
	if hud:
		hud.call("update_progress", note_count, nearest_page != null, at_exit, partner_near)
	if note_count == NOTE_POINTS.size() and at_exit and partner_near:
		completed = true
		hud.call("show_victory")
	_update_stalker(delta)
	if hint_clock > 18.0:
		hint_clock = 0.0
		if note_count >= 3 and note_count < NOTE_POINTS.size() and rng.randf() < 0.48:
			hud.call("show_toast", "Юна: Я слышала шаги справа. Не отходи далеко.", 3.5)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("05090d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("263038")
	environment.ambient_light_energy = 0.19
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("172024")
	environment.fog_density = 0.012
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-48, 28, 0)
	moon.light_color = Color("8dabc0")
	moon.light_energy = 0.22
	moon.shadow_enabled = false
	add_child(moon)

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var divisions := 76
	var span := 180.0
	var step_size := span / float(divisions)
	for z_index in range(divisions):
		for x_index in range(divisions):
			var x0 := -span * 0.5 + float(x_index) * step_size
			var x1 := x0 + step_size
			var z0 := -span * 0.5 + float(z_index) * step_size
			var z1 := z0 + step_size
			var a := Vector3(x0, _height_at(x0, z0), z0)
			var b := Vector3(x0, _height_at(x0, z1), z1)
			var c := Vector3(x1, _height_at(x1, z0), z0)
			var d := Vector3(x1, _height_at(x1, z1), z1)
			_add_terrain_triangle(surface, a, b, c)
			_add_terrain_triangle(surface, c, b, d)
	surface.generate_normals()
	var terrain_mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	terrain_mesh.surface_set_material(0, material)
	var body := StaticBody3D.new()
	body.name = "Rolling forest ground"
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = terrain_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.shape = terrain_mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)

func _add_terrain_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		surface.set_color(_ground_color(point.x, point.z, point.y))
		surface.add_vertex(point)

func _ground_color(x: float, z: float, height: float) -> Color:
	var color := Color("18211d").lerp(Color("28302a"), clampf((height + 4.0) / 12.0, 0.0, 0.42))
	if _distance_to_path(Vector2(x, z)) < 2.25:
		color = color.lerp(Color("39362d"), 0.75)
	return color

func _height_at(x: float, z: float) -> float:
	var rolling := terrain_noise.get_noise_2d(x, z) * 3.2
	rolling += terrain_noise.get_noise_2d(x * 0.43 + 187.0, z * 0.43 - 91.0) * 2.0
	var path_blend := 1.0 - clampf(_distance_to_path(Vector2(x, z)) / 8.0, 0.0, 1.0)
	return lerpf(rolling, 0.14, path_blend)

func _distance_to_path(point: Vector2) -> float:
	var closest := INF
	for index in range(1, PATH_POINTS.size()):
		var start := PATH_POINTS[index - 1]
		var segment := PATH_POINTS[index] - start
		var t := clampf((point - start).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		closest = minf(closest, point.distance_to(start + segment * t))
	return closest

func _build_mountains() -> void:
	var mountain_material := _material(Color("101a20"), 1.0)
	for index in range(13):
		var angle := TAU * float(index) / 13.0 + rng.randf_range(-0.08, 0.08)
		var radius := rng.randf_range(103.0, 119.0)
		var height := rng.randf_range(35.0, 57.0)
		var cone := ConeMesh.new()
		cone.bottom_radius = rng.randf_range(19.0, 29.0)
		cone.top_radius = rng.randf_range(1.2, 5.0)
		cone.height = height
		cone.radial_segments = 5
		cone.rings = 1
		var mountain := MeshInstance3D.new()
		mountain.mesh = cone
		mountain.material_override = mountain_material
		mountain.position = Vector3(cos(angle) * radius, height * 0.40 - 3.0, sin(angle) * radius)
		mountain.rotation.y = rng.randf_range(0.0, TAU)
		mountain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mountain)

func _build_forest() -> void:
	var positions: Array[Vector2] = NOTE_POINTS.duplicate()
	var attempts := 0
	while positions.size() < 96 and attempts < 900:
		attempts += 1
		var candidate := Vector2(rng.randf_range(-82.0, 82.0), rng.randf_range(-82.0, 82.0))
		if candidate.length() < 13.0 or candidate.distance_to(Vector2(0, -73)) < 10.0:
			continue
		if _distance_to_path(candidate) < 2.8:
			continue
		var separated := true
		for existing in positions:
			if candidate.distance_to(existing) < 5.2:
				separated = false
				break
		if separated:
			positions.append(candidate)
	_create_tree_instances(positions)
	for index in range(NOTE_POINTS.size()):
		_spawn_note(index, positions[index])

func _create_tree_instances(positions: Array[Vector2]) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.24
	trunk_mesh.bottom_radius = 0.52
	trunk_mesh.height = 7.4
	trunk_mesh.radial_segments = 6
	var trunk_material := _material(Color("443b30"), 0.98)
	trunk_material.vertex_color_use_as_albedo = true
	trunk_mesh.material = trunk_material
	var trunk_multimesh := MultiMesh.new()
	trunk_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multimesh.use_colors = true
	trunk_multimesh.mesh = trunk_mesh
	trunk_multimesh.instance_count = positions.size()
	var canopy_mesh := ConeMesh.new()
	canopy_mesh.bottom_radius = 3.0
	canopy_mesh.top_radius = 0.05
	canopy_mesh.height = 6.3
	canopy_mesh.radial_segments = 6
	canopy_mesh.rings = 1
	var canopy_material := _material(Color("23352b"), 1.0)
	canopy_material.vertex_color_use_as_albedo = true
	canopy_mesh.material = canopy_material
	var canopy_multimesh := MultiMesh.new()
	canopy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multimesh.use_colors = true
	canopy_multimesh.mesh = canopy_mesh
	canopy_multimesh.instance_count = positions.size() * 3
	for index in range(positions.size()):
		var point := positions[index]
		var ground := _height_at(point.x, point.y)
		var scale_x := rng.randf_range(0.82, 1.2)
		var scale_y := rng.randf_range(0.82, 1.18)
		var scale_z := rng.randf_range(0.82, 1.2)
		var yaw := rng.randf_range(0.0, TAU)
		var tree_basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale_x, scale_y, scale_z))
		var trunk_transform := Transform3D(tree_basis, Vector3(point.x, ground + 3.7 * scale_y, point.y))
		trunk_multimesh.set_instance_transform(index, trunk_transform)
		trunk_multimesh.set_instance_color(index, Color("ae9a7d").lerp(Color.WHITE, rng.randf_range(0.0, 0.2)))
		for tier in range(3):
			var tier_scale := 1.0 - float(tier) * 0.18
			var foliage_basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale_x * tier_scale, scale_y * 0.83, scale_z * tier_scale))
			var foliage_y := ground + (5.25 + float(tier) * 1.78) * scale_y
			var foliage_transform := Transform3D(foliage_basis, Vector3(point.x, foliage_y, point.y))
			var instance_index := index * 3 + tier
			canopy_multimesh.set_instance_transform(instance_index, foliage_transform)
			var green := Color("263b30").lerp(Color("344638"), rng.randf_range(0.0, 0.65))
			canopy_multimesh.set_instance_color(instance_index, green)
		var trunk_collision := StaticBody3D.new()
		trunk_collision.name = "Pine trunk"
		trunk_collision.position = Vector3(point.x, ground, point.y)
		trunk_collision.rotation.y = yaw
		trunk_collision.scale = Vector3(scale_x, scale_y, scale_z)
		var trunk_shape := CapsuleShape3D.new()
		trunk_shape.radius = 0.48
		trunk_shape.height = 5.6
		var trunk_collider := CollisionShape3D.new()
		trunk_collider.shape = trunk_shape
		trunk_collider.position.y = 2.8
		trunk_collision.add_child(trunk_collider)
		add_child(trunk_collision)
		tree_positions.append(Vector3(point.x, ground, point.y))
	var trunks := MultiMeshInstance3D.new()
	trunks.multimesh = trunk_multimesh
	trunks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunks)
	var crowns := MultiMeshInstance3D.new()
	crowns.multimesh = canopy_multimesh
	crowns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowns)

func _spawn_note(index: int, tree_point: Vector2) -> void:
	var note := Area3D.new()
	note.name = "Paper_%02d" % (index + 1)
	note.set_meta("note_index", index)
	note.set_meta("message", NOTE_TEXTS[index])
	var center := Vector3(tree_point.x, _height_at(tree_point.x, tree_point.y) + 2.05, tree_point.y)
	var toward_path := Vector3(-tree_point.x, 0.0, -tree_point.y).normalized()
	center += toward_path * 0.48
	note.position = center
	note.look_at(center + toward_path, Vector3.UP)
	var area_shape := SphereShape3D.new()
	area_shape.radius = 2.2
	var collider := CollisionShape3D.new()
	collider.shape = area_shape
	note.add_child(collider)
	var paper_material := _material(Color("d8cfad"), 0.95)
	paper_material.emission_enabled = true
	paper_material.emission = Color("756f56")
	paper_material.emission_energy_multiplier = 0.27
	var paper := MeshInstance3D.new()
	var paper_mesh := BoxMesh.new()
	paper_mesh.size = Vector3(0.42, 0.56, 0.035)
	paper.mesh = paper_mesh
	paper.material_override = paper_material
	note.add_child(paper)
	var ink := _material(Color("4b4639"), 1.0)
	for line_index in range(4):
		var stroke := MeshInstance3D.new()
		var stroke_mesh := BoxMesh.new()
		stroke_mesh.size = Vector3(0.24 - float(line_index % 2) * 0.045, 0.018, 0.008)
		stroke.mesh = stroke_mesh
		stroke.material_override = ink
		stroke.position = Vector3(0.0, 0.15 - float(line_index) * 0.09, -0.022)
		note.add_child(stroke)
	add_child(note)
	pages.append(note)

func _collect_page(page: Area3D) -> void:
	var page_index := int(page.get_meta("note_index"))
	var page_message := str(page.get_meta("message"))
	pages.erase(page)
	page.queue_free()
	note_count += 1
	GameManager.set_wave(note_count)
	if hud:
		hud.call("show_toast", "ЛИСТ %02d / 18\n%s" % [note_count, page_message], 5.2)
	if note_count == 3:
		_spawn_stalker()
		hud.call("show_toast", "В тумане стоит высокая фигура. Она не двигается, пока ты смотришь.", 5.8)
	elif note_count % 4 == 0 and note_count < NOTE_POINTS.size():
		_relocate_stalker()
	if note_count == NOTE_POINTS.size():
		hud.call("show_toast", "Все 18 листов у тебя. Теперь к огню у старой вышки — вместе с Юной.", 7.0)

func _build_cabins() -> void:
	var wood := _material(Color("544638"), 0.98)
	wood.albedo_texture = WOOD_TEXTURE
	wood.uv1_scale = Vector3(2.0, 1.5, 1.0)
	var dark_wood := _material(Color("282723"), 1.0)
	var window_material := _material(Color("080d0e"), 0.7)
	for index in range(CABIN_POINTS.size()):
		var point := CABIN_POINTS[index]
		var cabin := Node3D.new()
		cabin.name = "Abandoned cabin %02d" % (index + 1)
		cabin.position = Vector3(point.x, _height_at(point.x, point.y), point.y)
		cabin.rotation.y = rng.randf_range(-0.18, 0.18)
		add_child(cabin)
		_add_cabin_block(cabin, "Broken cabin shell", Vector3(0, 1.95, 0), Vector3(8.2, 3.9, 7.0), wood, true)
		_add_cabin_block(cabin, "Roof left slope", Vector3(-2.2, 4.15, 0), Vector3(5.8, 0.35, 8.0), dark_wood, false, -0.48)
		_add_cabin_block(cabin, "Roof right slope", Vector3(2.2, 4.15, 0), Vector3(5.8, 0.35, 8.0), dark_wood, false, 0.48)
		_add_cabin_block(cabin, "Door", Vector3(0.2, 1.25, -3.57), Vector3(1.35, 2.55, 0.12), dark_wood, false)
		for side in [-1.0, 1.0]:
			_add_cabin_block(cabin, "Black window", Vector3(side * 2.45, 2.25, -3.58), Vector3(1.3, 1.1, 0.1), window_material, false)
			for board_index in range(2):
				_add_cabin_block(cabin, "Boarded window", Vector3(side * 2.45, 2.05 + float(board_index) * 0.38, -3.68), Vector3(1.55, 0.12, 0.1), wood, false, -0.1 * side)
		if index % 2 == 0:
			var porch_light := OmniLight3D.new()
			porch_light.position = Vector3(0, 3.0, -4.6)
			porch_light.light_color = Color("d58f54")
			porch_light.light_energy = 0.75
			porch_light.omni_range = 8.0
			porch_light.shadow_enabled = false
			cabin.add_child(porch_light)

func _add_cabin_block(parent: Node3D, block_name: String, at: Vector3, size: Vector3, material: Material, solid: bool, slope := 0.0) -> void:
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.name = block_name
	holder.position = at
	holder.rotation.z = slope
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mesh_instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		holder.add_child(collision)
	parent.add_child(holder)

func _build_exit() -> void:
	var xz := Vector2(0.0, -73.0)
	exit_position = Vector3(xz.x, _height_at(xz.x, xz.y), xz.y)
	var post_material := _material(Color("494237"), 0.95)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.1
	post_mesh.bottom_radius = 0.16
	post_mesh.height = 4.4
	post.mesh = post_mesh
	post.material_override = post_material
	post.position = exit_position + Vector3(0, 2.2, 0)
	add_child(post)
	var beacon := MeshInstance3D.new()
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.42
	beacon_mesh.height = 0.84
	beacon.mesh = beacon_mesh
	var beacon_material := _material(Color("ffb96c"), 0.3)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color("e5914c")
	beacon_material.emission_energy_multiplier = 2.6
	beacon.material_override = beacon_material
	beacon.position = exit_position + Vector3(0, 4.55, 0)
	add_child(beacon)
	var exit_light := OmniLight3D.new()
	exit_light.position = beacon.position
	exit_light.light_color = Color("ffb36d")
	exit_light.light_energy = 2.2
	exit_light.omni_range = 17.0
	exit_light.shadow_enabled = false
	add_child(exit_light)
	var label := Label3D.new()
	label.text = "СТАРАЯ ВЫШКА  ·  ВЫХОД"
	label.position = exit_position + Vector3(0, 5.65, 0)
	label.pixel_size = 0.008
	label.modulate = Color("ffd9a4")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _spawn_player_and_partner() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "ForestWalker"
	player.position = Vector3(0, _height_at(0, 70) + 0.06, 70)
	player.set("walk_speed", 3.9)
	player.set("sprint_speed", 5.7)
	player.set("can_shoot", false)
	add_child(player)
	GameManager.begin_run(player)
	var view_model: Node3D = player.get_node("Head/Camera3D/ViewModel")
	view_model.visible = false
	var flashlight := Node3D.new()
	flashlight.name = "Handheld flashlight inertia"
	flashlight.set_script(FLASHLIGHT_SCRIPT)
	add_child(flashlight)
	flashlight.call("attach_to", player.get_node("Head/Camera3D"))
	partner = COMPANION_SCENE.instantiate()
	partner.name = "Yuna"
	partner.set("style_variant", 1)
	partner.set("forest_mode", true)
	partner.set("follow_speed", 6.2)
	partner.set("target_player", player)
	add_child(partner)
	partner.position = player.position + Vector3(1.3, -0.02, 2.2)
	var companion_lamp := OmniLight3D.new()
	companion_lamp.position = Vector3(0.0, 1.35, 0.0)
	companion_lamp.light_color = Color("eac999")
	companion_lamp.light_energy = 0.16
	companion_lamp.omni_range = 3.2
	companion_lamp.shadow_enabled = false
	partner.add_child(companion_lamp)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)

func _spawn_stalker() -> void:
	if is_instance_valid(stalker):
		return
	stalker = Node3D.new()
	stalker.name = "The Watcher"
	var suit := _material(Color("090d10"), 1.0)
	var no_face := _material(Color("030607"), 1.0)
	_add_stalker_mesh(stalker, CapsuleMesh.new(), Vector3(0, 1.28, 0), Vector3(0.66, 1.26, 0.42), suit)
	_add_stalker_mesh(stalker, SphereMesh.new(), Vector3(0, 2.55, -0.02), Vector3(0.42, 0.62, 0.36), no_face)
	for side in [-1.0, 1.0]:
		_add_stalker_mesh(stalker, CapsuleMesh.new(), Vector3(side * 0.48, 1.43, 0), Vector3(0.19, 1.18, 0.19), suit, side * 0.11)
		_add_stalker_mesh(stalker, CapsuleMesh.new(), Vector3(side * 0.18, 0.46, 0.0), Vector3(0.21, 0.66, 0.22), suit)
	add_child(stalker)
	_relocate_stalker()
	stalker.visible = true

func _add_stalker_mesh(parent: Node3D, primitive: PrimitiveMesh, at: Vector3, scale_by: Vector3, material: Material, tilt := 0.0) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = primitive
	mesh.position = at
	mesh.scale = scale_by
	mesh.rotation.z = tilt
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)

func _relocate_stalker() -> void:
	if not is_instance_valid(stalker) or not is_instance_valid(player):
		return
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var direction := -camera.global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var distance := rng.randf_range(29.0, 39.0) - minf(float(note_count), 14.0) * 0.45
	var destination := player.global_position + direction * distance
	destination.x = clampf(destination.x, -78.0, 78.0)
	destination.z = clampf(destination.z, -78.0, 78.0)
	destination.y = _height_at(destination.x, destination.z)
	stalker.global_position = destination
	stalker.look_at(Vector3(player.global_position.x, destination.y + 1.2, player.global_position.z), Vector3.UP)

func _update_stalker(delta: float) -> void:
	if not is_instance_valid(stalker) or note_count < 3:
		return
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var to_player := player.global_position - stalker.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	if distance < 11.0:
		_relocate_stalker()
		return
	var to_stalker := (stalker.global_position - camera.global_position).normalized()
	var forward := -camera.global_basis.z
	if forward.dot(to_stalker) < 0.91 and distance > 13.0:
		var speed := 0.42 + float(note_count) * 0.055
		stalker.global_position += to_player.normalized() * speed * delta
		stalker.global_position.y = _height_at(stalker.global_position.x, stalker.global_position.z)
		stalker.look_at(Vector3(player.global_position.x, stalker.global_position.y + 1.2, player.global_position.z), Vector3.UP)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

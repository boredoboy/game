extends CharacterBody3D

const SUPPORT_SOUND := preload("res://assets/audio/packs/core_sfx/weapons/rifle_shot.wav")
@export_range(0, 2) var style_variant := 0
@export var follow_speed := 5.2
@export var forest_mode := false

var target_player: Node3D
var fire_clock := 0.0
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
	$Visual.set("style_variant", style_variant)
	$Visual.set("idle_motion", false)
	add_to_group("companions")
	audio_player = AudioStreamPlayer3D.new()
	audio_player.max_distance = 18.0
	audio_player.volume_db = linear_to_db(maxf(float(GameSettings.get_value("sfx_volume")) * 0.62, 0.001))
	add_child(audio_player)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_player):
		return
	var follow_offset := Vector3(float(style_variant - 1) * 1.25, 0, 1.45)
	if forest_mode:
		follow_offset = Vector3(0.85, 0, 1.8)
	var desired := target_player.global_position + target_player.global_transform.basis * follow_offset
	var to_goal := desired - global_position
	to_goal.y = 0.0
	if to_goal.length() > 2.1:
		velocity.x = to_goal.normalized().x * follow_speed
		velocity.z = to_goal.normalized().z * follow_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	fire_clock -= delta
	if fire_clock <= 0.0:
		var target := _nearest_zombie()
		if target:
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
			if global_position.distance_to(target.global_position) < 19.0:
				target.call("take_damage", 28.0, target.global_position + Vector3.UP)
				audio_player.stream = SUPPORT_SOUND
				audio_player.play()
				fire_clock = 1.4
		else:
			fire_clock = 0.25

func _nearest_zombie() -> Node3D:
	var nearest: Node3D
	var best_distance := 22.0
	for candidate in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			nearest = candidate
			best_distance = distance
	return nearest

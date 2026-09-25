extends CharacterBody3D

signal health_changed(value: float)
signal ammo_changed(magazine: int, reserve: int, is_reloading: bool)
signal hit_confirm

const GRAVITY := 19.6
const MAG_SIZE := 30
const SHOT_SOUND := preload("res://assets/audio/packs/core_sfx/weapons/rifle_shot.wav")
const RELOAD_SOUND := preload("res://assets/audio/packs/core_sfx/weapons/reload.wav")
const EMPTY_SOUND := preload("res://assets/audio/packs/core_sfx/weapons/empty.wav")
const FOOTSTEP_SOUND := preload("res://assets/audio/packs/core_sfx/footsteps/concrete_step.wav")

@export var walk_speed := 5.3
@export var sprint_speed := 8.4
@export var max_health := 100.0
@export var damage := 52.0
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon: Node3D = $Head/Camera3D/ViewModel/Rifle

var health := 100.0
var magazine := MAG_SIZE
var reserve_ammo := 180
var is_reloading := false
var reload_clock := 0.0
var shot_clock := 0.0
var footstep_clock := 0.0
var bob_clock := 0.0
var audio_player: AudioStreamPlayer3D
var footstep_player: AudioStreamPlayer3D

func _ready() -> void:
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "WeaponAudio"
	add_child(audio_player)
	footstep_player = AudioStreamPlayer3D.new()
	footstep_player.name = "Footsteps"
	footstep_player.stream = FOOTSTEP_SOUND
	footstep_player.volume_db = linear_to_db(maxf(float(GameSettings.get_value("sfx_volume")) * 0.55, 0.001))
	add_child(footstep_player)
	health_changed.emit(health)
	ammo_changed.emit(magazine, reserve_ammo, false)

func _physics_process(delta: float) -> void:
	shot_clock = maxf(0.0, shot_clock - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := (global_transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
		bob_clock += delta * (12.0 if speed == sprint_speed else 9.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 8.0 * delta)
	move_and_slide()
	if move_direction != Vector3.ZERO and is_on_floor():
		footstep_clock -= delta
		if footstep_clock <= 0.0:
			footstep_player.play()
			footstep_clock = 0.33 if speed == sprint_speed else 0.48
	else:
		footstep_clock = 0.0
	head.position.y = 1.58 + (sin(bob_clock) * 0.025 if move_direction != Vector3.ZERO else 0.0)
	if weapon:
		weapon.call("set_walk_bob", sin(bob_clock * 2.0) * 0.01 if move_direction != Vector3.ZERO else 0.0)
	if is_reloading:
		reload_clock -= delta
		if reload_clock <= 0.0:
			var needed := MAG_SIZE - magazine
			var loaded := mini(needed, reserve_ammo)
			magazine += loaded
			reserve_ammo -= loaded
			is_reloading = false
			ammo_changed.emit(magazine, reserve_ammo, false)
	if Input.is_action_just_pressed("reload"):
		reload()
	if Input.is_action_pressed("shoot"):
		shoot()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * GameSettings.mouse_sensitivity() * 0.02)
		head.rotate_x(-event.relative.y * GameSettings.mouse_sensitivity() * 0.02)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var pause_hud := get_tree().get_first_node_in_group("hud")
		if pause_hud and pause_hud.has_method("show_pause"):
			pause_hud.call("show_pause")

func shoot() -> void:
	if shot_clock > 0.0 or is_reloading:
		return
	if magazine <= 0:
		_play_sound(EMPTY_SOUND)
		shot_clock = 0.22
		return
	magazine -= 1
	shot_clock = 0.105
	ammo_changed.emit(magazine, reserve_ammo, false)
	_play_sound(SHOT_SOUND)
	if weapon:
		weapon.call("fire_fx")
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 90.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 5
	query.exclude = [get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var target: Object = result.collider
		if target.has_method("take_damage"):
			target.call("take_damage", damage, result.position)
			hit_confirm.emit()

func reload() -> void:
	if is_reloading or magazine == MAG_SIZE or reserve_ammo <= 0:
		return
	is_reloading = true
	reload_clock = 1.55
	_play_sound(RELOAD_SOUND)
	ammo_changed.emit(magazine, reserve_ammo, true)

func add_reserve_ammo(amount: int) -> void:
	reserve_ammo += amount
	ammo_changed.emit(magazine, reserve_ammo, is_reloading)

func take_damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	health_changed.emit(health)
	if health <= 0.0:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_game_over"):
			hud.call("show_game_over")

func _play_sound(stream: AudioStream) -> void:
	if audio_player:
		audio_player.stream = stream
		var volume := float(GameSettings.get_value("sfx_volume"))
		audio_player.volume_db = linear_to_db(maxf(volume, 0.001))
		audio_player.play()

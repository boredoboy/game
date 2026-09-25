extends Node3D

var target_camera: Camera3D
var beam: SpotLight3D
var follow_rate := 5.0

func _ready() -> void:
	beam = SpotLight3D.new()
	beam.name = "Warm flashlight beam"
	beam.light_color = Color("ffe8c4")
	beam.light_energy = 5.2
	beam.spot_range = 34.0
	beam.spot_angle = 31.0
	beam.spot_angle_attenuation = 1.15
	beam.shadow_enabled = false
	beam.light_specular = 0.35
	add_child(beam)

func attach_to(camera: Camera3D) -> void:
	target_camera = camera
	global_transform = camera.global_transform

func _process(delta: float) -> void:
	if not is_instance_valid(target_camera):
		return
	var weight := 1.0 - exp(-follow_rate * delta)
	var target_position := target_camera.global_position + target_camera.global_basis * Vector3(0.24, -0.18, 0.02)
	global_position = global_position.lerp(target_position, weight)
	var current_rotation := global_basis.get_rotation_quaternion()
	var target_rotation := target_camera.global_basis.get_rotation_quaternion()
	global_basis = Basis(current_rotation.slerp(target_rotation, weight))
	beam.light_energy = 5.2 + sin(float(Time.get_ticks_msec()) * 0.0021) * 0.035

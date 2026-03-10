extends RigidBody3D

@export var engine_force: float = 13500.0
@export var reverse_force: float = 6000.0
@export var steer_torque: float = 3600.0
@export var buoyancy: float = 5600.0
@export var float_damping: float = 46.0
@export var side_grip: float = 7.0
@export var upright_torque: float = 4200.0
@export var max_speed: float = 78.0

var sample_offsets: Array[Vector3] = [
	Vector3(-0.55, -0.25, -1.05),
	Vector3(0.55, -0.25, -1.05),
	Vector3(-0.55, -0.25, 1.05),
	Vector3(0.55, -0.25, 1.05),
]

var submerged_ratio: float = 0.0
var water_provider: Node = null


func _ready() -> void:
	water_provider = get_parent()


func _physics_process(delta: float) -> void:
	if water_provider == null:
		return

	var now: float = Time.get_ticks_msec() * 0.001
	var avg_normal: Vector3 = Vector3.ZERO
	var submersion_accum: float = 0.0

	for offset: Vector3 in sample_offsets:
		var sample_world: Vector3 = global_transform * offset
		var water_y: float = float(water_provider.call("wave_height_at", sample_world, now))
		var depth: float = water_y - sample_world.y

		var n: Vector3 = water_provider.call("wave_normal_at", sample_world, now)
		avg_normal += n

		if depth > 0.0:
			var s: float = clampf(depth, 0.0, 1.0)
			submersion_accum += s
			var buoyant_force: Vector3 = Vector3.UP * buoyancy * s
			buoyant_force += -linear_velocity * float_damping * s
			apply_force(buoyant_force, sample_world - global_position)

	submerged_ratio = clampf(submersion_accum / float(sample_offsets.size()), 0.0, 1.0)
	if avg_normal.length() < 0.001:
		avg_normal = Vector3.UP
	else:
		avg_normal = avg_normal.normalized()

	var throttle: float = Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	if Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S):
		throttle -= 1.0
	throttle = clampf(throttle, -1.0, 1.0)

	var forward: Vector3 = -global_basis.z
	var thrust_force: float = (engine_force if throttle >= 0.0 else reverse_force) * throttle
	apply_central_force(forward * thrust_force * maxf(0.22, submerged_ratio))

	var steer: float = Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	if Input.is_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_key_pressed(KEY_D):
		steer -= 1.0
	steer = clampf(steer, -1.0, 1.0)

	var speed_factor: float = clampf(linear_velocity.length() / 36.0, 0.30, 1.25)
	apply_torque(avg_normal * steer_torque * steer * speed_factor * maxf(0.35, submerged_ratio))

	var up: Vector3 = global_basis.y
	var correction_axis: Vector3 = up.cross(avg_normal)
	apply_torque(correction_axis * upright_torque)

	var local_velocity: Vector3 = global_basis.inverse() * linear_velocity
	local_velocity.x = move_toward(local_velocity.x, 0.0, side_grip * 20.0 * delta * maxf(0.2, submerged_ratio))
	linear_velocity = global_basis * local_velocity

	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed


func speed_kph() -> float:
	return linear_velocity.length() * 3.6


func hard_reset(pos: Vector3, heading: float = 0.0) -> void:
	global_position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	rotate_y(heading)

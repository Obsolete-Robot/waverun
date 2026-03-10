extends Node3D

@export var max_speed_kph: float = 82.0
@export var reverse_speed_kph: float = 18.0
@export var forward_accel: float = 18.0
@export var reverse_accel: float = 7.5
@export var brake_accel: float = 18.0
@export var coast_drag: float = 2.6
@export var water_drag: float = 0.65
@export var air_drag: float = 0.18
@export var water_grip: float = 15.0
@export var air_grip: float = 2.4
@export var slip_push: float = 1.35
@export var turn_rate: float = 2.15
@export var turn_response: float = 6.4
@export var yaw_damping: float = 2.4
@export var gravity_force: float = 16.0
@export var ride_height: float = 0.94
@export var planing_height: float = 0.24
@export var ride_spring: float = 34.0
@export var ride_damping: float = 8.4
@export var ride_contact_height: float = 0.45
@export var airborne_height: float = 1.15
@export var max_submerge_depth: float = 0.65
@export var reentry_snap_speed: float = 14.0
@export var bank_angle: float = 0.24
@export var slope_roll: float = 0.08
@export var slope_pitch: float = 0.07
@export var attitude_response: float = 6.0
@export var debug_logging_enabled: bool = true
@export var debug_log_interval: float = 0.10

const SAMPLE_FRONT := Vector3(0.0, 0.0, -1.1)
const SAMPLE_BACK := Vector3(0.0, 0.0, 1.0)
const SAMPLE_LEFT := Vector3(-0.55, 0.0, -0.05)
const SAMPLE_RIGHT := Vector3(0.55, 0.0, -0.05)
const DEBUG_LOG_PATH := "res://debug/jetski_debug.log"

var water_provider: Node = null
var velocity := Vector3.ZERO
var heading: float = 0.0
var yaw_speed: float = 0.0
var throttle_input: float = 0.0
var steer_input: float = 0.0
var grounded: bool = false
var surface_height: float = 0.0
var surface_normal := Vector3.UP
var pitch_angle: float = 0.0
var roll_angle: float = 0.0
var debug_time_accum: float = 0.0
var traction_amount: float = 0.0
var slip_speed: float = 0.0
var forward_speed: float = 0.0
var water_clearance: float = 0.0
var target_clearance: float = 0.0
var planing_amount: float = 0.0


func _ready() -> void:
	water_provider = get_parent()
	_reset_debug_log()


func _physics_process(delta: float) -> void:
	if water_provider == null:
		return

	var now := Time.get_ticks_msec() * 0.001
	_read_input(delta)
	var wave: Dictionary = _sample_wave(now)
	_step_vertical(delta, wave)
	_step_planar(delta)
	global_position += velocity * delta
	_post_move_surface_clamp()
	_update_attitude(delta, wave)
	_log_debug_sample(delta, wave)


func _read_input(delta: float) -> void:
	var throttle := Input.get_action_strength("ui_up") - Input.get_action_strength("ui_down")
	if Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S):
		throttle -= 1.0
	throttle_input = move_toward(throttle_input, clampf(throttle, -1.0, 1.0), delta * 3.6)

	var steer := Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	if Input.is_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_key_pressed(KEY_D):
		steer -= 1.0
	steer_input = move_toward(steer_input, clampf(steer, -1.0, 1.0), delta * 5.8)


func _sample_wave(t: float) -> Dictionary:
	var forward: Vector3 = _heading_forward()
	var right: Vector3 = _heading_right()
	var front_pos: Vector3 = _sample_offset_world(SAMPLE_FRONT, forward, right)
	var back_pos: Vector3 = _sample_offset_world(SAMPLE_BACK, forward, right)
	var left_pos: Vector3 = _sample_offset_world(SAMPLE_LEFT, forward, right)
	var right_pos: Vector3 = _sample_offset_world(SAMPLE_RIGHT, forward, right)

	var center_height: float = float(water_provider.call("wave_height_at", global_position, t))
	var front_height: float = float(water_provider.call("wave_height_at", front_pos, t))
	var back_height: float = float(water_provider.call("wave_height_at", back_pos, t))
	var left_height: float = float(water_provider.call("wave_height_at", left_pos, t))
	var right_height: float = float(water_provider.call("wave_height_at", right_pos, t))

	var center_normal: Vector3 = water_provider.call("wave_normal_at", global_position, t)
	var front_normal: Vector3 = water_provider.call("wave_normal_at", front_pos, t)
	var back_normal: Vector3 = water_provider.call("wave_normal_at", back_pos, t)
	var left_normal: Vector3 = water_provider.call("wave_normal_at", left_pos, t)
	var right_normal: Vector3 = water_provider.call("wave_normal_at", right_pos, t)

	var avg_normal: Vector3 = (
		center_normal * 0.40
		+ front_normal * 0.15
		+ back_normal * 0.15
		+ left_normal * 0.15
		+ right_normal * 0.15
	).normalized()

	return {
		"center_height": center_height,
		"average_height": center_height * 0.40 + (front_height + back_height + left_height + right_height) * 0.15,
		"front_height": front_height,
		"back_height": back_height,
		"left_height": left_height,
		"right_height": right_height,
		"normal": avg_normal,
	}


func _sample_offset_world(offset: Vector3, forward: Vector3, right: Vector3) -> Vector3:
	return global_position + right * offset.x + forward * offset.z


func _step_vertical(delta: float, wave: Dictionary) -> void:
	surface_height = float(wave["average_height"])
	surface_normal = wave["normal"]

	var max_speed: float = max_speed_kph / 3.6
	planing_amount = clampf(maxf(forward_speed, 0.0) / max_speed, 0.0, 1.0)
	target_clearance = ride_height + planing_height * planing_amount
	water_clearance = global_position.y - surface_height
	var height_error: float = target_clearance - water_clearance
	var over_target: float = maxf(water_clearance - target_clearance, 0.0)
	var contact_target: float = clampf(1.0 - over_target / airborne_height, 0.0, 1.0)
	if height_error > 0.0:
		contact_target = maxf(contact_target, clampf(height_error / ride_contact_height, 0.0, 1.0))

	traction_amount = move_toward(traction_amount, contact_target, delta * 5.5)
	grounded = traction_amount > 0.35 or height_error > 0.0

	var spring_ratio: float = maxf(traction_amount, clampf(height_error / ride_contact_height, 0.0, 1.0))
	var vertical_accel: float = -gravity_force
	if spring_ratio > 0.0:
		vertical_accel += height_error * ride_spring * spring_ratio
		vertical_accel -= velocity.y * ride_damping * lerpf(0.30, 1.0, spring_ratio)
		if height_error > 0.0:
			vertical_accel += minf(height_error, max_submerge_depth) * reentry_snap_speed
	velocity.y += vertical_accel * delta

	var min_y: float = surface_height + target_clearance - max_submerge_depth
	if global_position.y < min_y:
		global_position.y = min_y
		velocity.y = maxf(velocity.y, 0.0)
	elif traction_amount > 0.80 and absf(height_error) < 0.08 and absf(velocity.y) < 1.0:
		global_position.y = lerpf(global_position.y, surface_height + target_clearance, clampf(delta * 6.0, 0.0, 1.0))


func _step_planar(delta: float) -> void:
	var max_speed: float = max_speed_kph / 3.6
	var max_reverse_speed: float = reverse_speed_kph / 3.6
	var speed_ratio: float = clampf(maxf(forward_speed, 0.0) / max_speed, 0.0, 1.0)

	if throttle_input > 0.0:
		var thrust: float = throttle_input * forward_accel * lerpf(0.45, 1.0, traction_amount)
		thrust *= lerpf(1.0, 0.60, speed_ratio)
		forward_speed += thrust * delta
	elif throttle_input < 0.0:
		if forward_speed > 0.0:
			forward_speed = move_toward(forward_speed, 0.0, brake_accel * -throttle_input * delta)
		else:
			forward_speed -= reverse_accel * -throttle_input * delta

	var drag_accel: float = lerpf(air_drag, water_drag, traction_amount)
	drag_accel += absf(forward_speed) * lerpf(0.03, 0.12, traction_amount)
	drag_accel += forward_speed * forward_speed * lerpf(0.006, 0.013, traction_amount)
	if absf(throttle_input) < 0.05:
		drag_accel += coast_drag
	forward_speed = move_toward(forward_speed, 0.0, drag_accel * delta)
	forward_speed = clampf(forward_speed, -max_reverse_speed, max_speed)

	var yaw_authority: float = clampf(absf(forward_speed) / 4.0, 0.0, 1.0)
	var carve_strength: float = lerpf(0.20, 1.0, traction_amount) * lerpf(0.45, 1.0, speed_ratio)
	var yaw_target: float = steer_input * turn_rate * yaw_authority * carve_strength
	if forward_speed < -0.5:
		yaw_target *= -0.55
	else:
		yaw_target += steer_input * speed_ratio * traction_amount * 0.35
	yaw_target -= slip_speed * 0.12 * traction_amount

	yaw_speed = move_toward(yaw_speed, yaw_target, turn_response * delta)
	var yaw_decay: float = yaw_damping + (1.0 - absf(steer_input)) * 1.4
	yaw_speed = move_toward(yaw_speed, 0.0, yaw_decay * delta * lerpf(0.45, 1.0, traction_amount))
	heading += yaw_speed * delta

	slip_speed += yaw_speed * maxf(forward_speed, 0.0) * slip_push * delta
	var slip_grip: float = lerpf(air_grip, water_grip, traction_amount)
	slip_grip *= lerpf(0.40, 1.0, clampf(absf(forward_speed) / 8.0, 0.0, 1.0))
	slip_grip += absf(slip_speed) * 0.5
	slip_speed = move_toward(slip_speed, 0.0, slip_grip * delta)
	slip_speed = clampf(slip_speed, -max_speed * 0.35, max_speed * 0.35)

	var forward: Vector3 = _heading_forward()
	var right: Vector3 = _heading_right()
	var planar_velocity: Vector3 = forward * forward_speed + right * slip_speed
	velocity.x = planar_velocity.x
	velocity.z = planar_velocity.z


func _post_move_surface_clamp() -> void:
	var min_y: float = surface_height + target_clearance - max_submerge_depth
	if global_position.y < min_y:
		global_position.y = min_y
		velocity.y = maxf(velocity.y, 0.0)
	water_clearance = global_position.y - surface_height


func _update_attitude(delta: float, wave: Dictionary) -> void:
	var up_dir: Vector3 = Vector3.UP.lerp(surface_normal, traction_amount).normalized()
	var forward: Vector3 = _heading_forward().slide(up_dir).normalized()
	if forward.length_squared() < 0.001:
		forward = _heading_forward()
	var right: Vector3 = forward.cross(up_dir).normalized()

	var speed_ratio: float = clampf(maxf(forward_speed, 0.0) / (max_speed_kph / 3.6), 0.0, 1.0)
	var target_pitch: float = (float(wave["back_height"]) - float(wave["front_height"])) * slope_pitch
	target_pitch -= throttle_input * 0.06
	target_pitch -= velocity.y * 0.014
	target_pitch += planing_amount * 0.04
	target_pitch = clampf(target_pitch, -0.34, 0.26)

	var target_roll: float = (float(wave["left_height"]) - float(wave["right_height"])) * slope_roll
	target_roll -= steer_input * (0.08 + speed_ratio * bank_angle)
	target_roll -= slip_speed * 0.018
	target_roll = clampf(target_roll, -0.48, 0.48)

	var attitude_alpha: float = clampf(delta * attitude_response, 0.0, 1.0)
	pitch_angle = lerpf(pitch_angle, target_pitch, attitude_alpha)
	roll_angle = lerpf(roll_angle, target_roll, attitude_alpha)

	var water_basis: Basis = Basis(right, up_dir, -forward).orthonormalized()
	global_basis = (water_basis * Basis.from_euler(Vector3(pitch_angle, 0.0, roll_angle))).orthonormalized()


func _heading_forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func _heading_right() -> Vector3:
	return Vector3(cos(heading), 0.0, -sin(heading))


func speed_kph() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6


func hard_reset(pos: Vector3, heading_radians: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	heading = heading_radians
	yaw_speed = 0.0
	throttle_input = 0.0
	steer_input = 0.0
	grounded = false
	traction_amount = 0.0
	forward_speed = 0.0
	slip_speed = 0.0
	surface_height = pos.y
	surface_normal = Vector3.UP
	water_clearance = ride_height
	target_clearance = ride_height
	planing_amount = 0.0
	pitch_angle = 0.0
	roll_angle = 0.0
	global_basis = Basis(Vector3.UP, heading_radians)
	_reset_debug_log()


func debug_log_path() -> String:
	return ProjectSettings.globalize_path(DEBUG_LOG_PATH)


func _reset_debug_log() -> void:
	debug_time_accum = 0.0
	if not debug_logging_enabled:
		return

	var log_dir := debug_log_path().get_base_dir()
	DirAccess.make_dir_recursive_absolute(log_dir)

	var file := FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to create debug log at %s" % debug_log_path())
		return

	file.store_line("# WaveRun jetski debug log")
	file.store_line("# path=%s" % debug_log_path())
	file.store_line("time,dt,throttle,steer,grounded,traction,forward_speed,slip_speed,clearance,target_clearance,planing,pos_x,pos_y,pos_z,vel_x,vel_y,vel_z,speed_kph,heading_deg,yaw_speed,surface_h,pitch_deg,roll_deg,normal_x,normal_y,normal_z,front_h,back_h,left_h,right_h")


func _log_debug_sample(delta: float, wave: Dictionary) -> void:
	if not debug_logging_enabled:
		return

	debug_time_accum += delta
	if debug_time_accum < debug_log_interval:
		return
	debug_time_accum = 0.0

	var file := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		push_warning("Failed to append debug log at %s" % debug_log_path())
		return

	file.seek_end()
	file.store_line("%.3f,%.3f,%.3f,%.3f,%s,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.2f,%.3f,%.3f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
		Time.get_ticks_msec() * 0.001,
		delta,
		throttle_input,
		steer_input,
		str(grounded),
		traction_amount,
		forward_speed,
		slip_speed,
		water_clearance,
		target_clearance,
		planing_amount,
		global_position.x,
		global_position.y,
		global_position.z,
		velocity.x,
		velocity.y,
		velocity.z,
		speed_kph(),
		rad_to_deg(heading),
		yaw_speed,
		surface_height,
		rad_to_deg(pitch_angle),
		rad_to_deg(roll_angle),
		surface_normal.x,
		surface_normal.y,
		surface_normal.z,
		float(wave["front_height"]),
		float(wave["back_height"]),
		float(wave["left_height"]),
		float(wave["right_height"]),
	])

extends Node3D

@export var max_speed_kph: float = 82.0
@export var reverse_speed_kph: float = 18.0
@export var forward_accel: float = 18.0
@export var reverse_accel: float = 7.5
@export var brake_accel: float = 18.0
@export var coast_drag: float = 2.6
@export var water_drag: float = 0.65
@export var air_drag: float = 0.2
@export var water_grip: float = 15.0
@export var air_grip: float = 2.4
@export var slip_push: float = 1.35
@export var turn_rate: float = 2.15
@export var turn_response: float = 6.4
@export var yaw_damping: float = 4.0
@export var gravity_force: float = 20.0
@export var ride_height: float = 0.4
@export var planing_height: float = 0.25
@export var ride_spring: float = 75.0
@export var ride_damping: float = 6.0
@export var ride_contact_height: float = 0.45
@export var airborne_height: float = 1.15
@export var max_submerge_depth: float = 2.5
@export var reentry_snap_speed: float = 4.0
@export var surface_follow: float = 0.55
@export var launch_boost: float = 5.5
@export var launch_speed_threshold: float = 7.5
@export var wave_face_lift: float = 4.5
@export var landing_base_sink: float = 0.35
@export var landing_dive_depth: float = 0.65
@export var landing_bounce: float = 1.10
@export var landing_sink_recovery: float = 3.6
@export var reentry_softness: float = 0.75
@export var bank_angle: float = 0.24
@export var slope_roll: float = 0.08
@export var slope_pitch: float = 0.07
@export var attitude_response: float = 6.0
@export var water_pitch_control: float = 0.22
@export var air_pitch_control: float = 1.0
@export var dive_clearance_offset: float = 0.8
@export var dive_extra_depth: float = 1.15
@export var dive_speed_threshold: float = 4.5
@export var air_pitch_torque: float = 2.6
@export var air_pitch_damping: float = 1.9
@export var air_roll_torque: float = 1.9
@export var air_roll_damping: float = 2.4
@export var max_air_pitch_angle: float = 0.95
@export var max_air_roll_angle: float = 0.85
@export var debug_logging_enabled: bool = true
@export var debug_log_interval: float = 0.10

const SAMPLE_FRONT := Vector3(0.0, 0.0, -1.1)
const SAMPLE_BACK := Vector3(0.0, 0.0, 1.0)
const SAMPLE_LEFT := Vector3(-0.55, 0.0, -0.05)
const SAMPLE_RIGHT := Vector3(0.55, 0.0, -0.05)
const DEBUG_LOG_PATH := "res://debug/jetski_debug.log"
const WAVE_SAMPLE_DT := 1.0 / 60.0

var water_provider: Node = null
var velocity := Vector3.ZERO
var heading: float = 0.0
var yaw_speed: float = 0.0
var throttle_input: float = 0.0
var steer_input: float = 0.0
var nose_input: float = 0.0
var grounded: bool = false
var surface_height: float = 0.0
var surface_normal := Vector3.UP
var pitch_angle: float = 0.0
var roll_angle: float = 0.0
var debug_time_accum: float = 0.0
var traction_amount: float = 0.0
var support_amount: float = 0.0
var slip_speed: float = 0.0
var forward_speed: float = 0.0
var water_clearance: float = 0.0
var target_clearance: float = 0.0
var planing_amount: float = 0.0
var wave_vertical_speed: float = 0.0
var landing_sink: float = 0.0
var air_pitch_velocity: float = 0.0
var air_roll_velocity: float = 0.0
var air_pitch_offset: float = 0.0
var air_roll_offset: float = 0.0


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
	throttle_input = move_toward(throttle_input, clampf(throttle, -1.0, 1.0), delta * 3.6)

	var steer := Input.get_action_strength("ui_left") - Input.get_action_strength("ui_right")
	if Input.is_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_key_pressed(KEY_D):
		steer -= 1.0
	steer_input = move_toward(steer_input, clampf(steer, -1.0, 1.0), delta * 5.8)

	var nose := 0.0
	if Input.is_key_pressed(KEY_W):
		nose += 1.0
	if Input.is_key_pressed(KEY_S):
		nose -= 1.0
	nose_input = move_toward(nose_input, clampf(nose, -1.0, 1.0), delta * 7.5)


func _sample_wave(t: float) -> Dictionary:
	var forward: Vector3 = _heading_forward()
	var right: Vector3 = _heading_right()
	var front_pos: Vector3 = _sample_offset_world(SAMPLE_FRONT, forward, right)
	var back_pos: Vector3 = _sample_offset_world(SAMPLE_BACK, forward, right)
	var left_pos: Vector3 = _sample_offset_world(SAMPLE_LEFT, forward, right)
	var right_pos: Vector3 = _sample_offset_world(SAMPLE_RIGHT, forward, right)
	var prev_t: float = t - WAVE_SAMPLE_DT

	var center_height: float = float(water_provider.call("wave_height_at", global_position, t))
	var front_height: float = float(water_provider.call("wave_height_at", front_pos, t))
	var back_height: float = float(water_provider.call("wave_height_at", back_pos, t))
	var left_height: float = float(water_provider.call("wave_height_at", left_pos, t))
	var right_height: float = float(water_provider.call("wave_height_at", right_pos, t))

	var prev_center_height: float = float(water_provider.call("wave_height_at", global_position, prev_t))
	var prev_front_height: float = float(water_provider.call("wave_height_at", front_pos, prev_t))
	var prev_back_height: float = float(water_provider.call("wave_height_at", back_pos, prev_t))
	var prev_left_height: float = float(water_provider.call("wave_height_at", left_pos, prev_t))
	var prev_right_height: float = float(water_provider.call("wave_height_at", right_pos, prev_t))

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

	var average_height: float = center_height * 0.40 + (front_height + back_height + left_height + right_height) * 0.15
	var prev_average_height: float = prev_center_height * 0.40 + (prev_front_height + prev_back_height + prev_left_height + prev_right_height) * 0.15

	return {
		"center_height": center_height,
		"average_height": average_height,
		"front_height": front_height,
		"back_height": back_height,
		"left_height": left_height,
		"right_height": right_height,
		"average_velocity": (average_height - prev_average_height) / WAVE_SAMPLE_DT,
		"center_velocity": (center_height - prev_center_height) / WAVE_SAMPLE_DT,
		"normal": avg_normal,
	}


func _sample_offset_world(offset: Vector3, forward: Vector3, right: Vector3) -> Vector3:
	return global_position + right * offset.x + forward * offset.z


func _step_vertical(delta: float, wave: Dictionary) -> void:
	var was_grounded: bool = grounded
	surface_height = float(wave["average_height"])
	surface_normal = wave["normal"]
	wave_vertical_speed = float(wave["average_velocity"])
	landing_sink = move_toward(landing_sink, 0.0, landing_sink_recovery * delta)

	var max_speed: float = max_speed_kph / 3.6
	planing_amount = clampf(maxf(forward_speed, 0.0) / max_speed, 0.0, 1.0)
	target_clearance = ride_height + planing_height * planing_amount - landing_sink
	var dive_ratio: float = clampf(
		(maxf(forward_speed, 0.0) - dive_speed_threshold) / maxf(max_speed - dive_speed_threshold, 0.001),
		0.0,
		1.0
	) * clampf(nose_input, 0.0, 1.0)
	target_clearance -= dive_clearance_offset * dive_ratio
	target_clearance = maxf(-max_submerge_depth - dive_extra_depth * 0.35, target_clearance)

	water_clearance = global_position.y - surface_height
	var height_error: float = target_clearance - water_clearance
	var over_target: float = maxf(water_clearance - target_clearance, 0.0)

	var support_target: float = clampf(1.0 - over_target / maxf(ride_contact_height, 0.001), 0.0, 1.0)
	if height_error > 0.0:
		support_target = 1.0
	support_amount = move_toward(support_amount, support_target, delta * 11.0)

	var traction_target: float = clampf(1.0 - over_target / maxf(airborne_height, 0.001), 0.0, 1.0)
	if height_error > 0.0:
		traction_target = 1.0
	traction_amount = move_toward(traction_amount, traction_target, delta * 4.5)
	grounded = support_amount > 0.10 or height_error > 0.0

	var vertical_accel: float = -gravity_force
	if support_amount > 0.0:
		var sink_limit: float = maxf(max_submerge_depth + landing_dive_depth, 0.001)
		var reentry_ratio: float = clampf(landing_sink / sink_limit, 0.0, 1.0)
		var support_softness: float = 1.0 - reentry_ratio * reentry_softness
		var relative_vertical_speed: float = velocity.y - wave_vertical_speed * surface_follow
		vertical_accel += height_error * ride_spring * support_amount * support_softness
		vertical_accel -= relative_vertical_speed * ride_damping * support_amount * support_softness
		if height_error > 0.0:
			vertical_accel += minf(height_error, max_submerge_depth) * reentry_snap_speed * support_softness

		var speed_ratio: float = clampf(maxf(forward_speed, 0.0) / max_speed, 0.0, 1.0)
		var launch_ratio: float = clampf(
			(maxf(forward_speed, 0.0) - launch_speed_threshold) / maxf(max_speed - launch_speed_threshold, 0.001),
			0.0,
			1.0
		)
		var crest_rise: float = maxf(float(wave["center_velocity"]), 0.0)
		var face_lift: float = maxf(float(wave["front_height"]) - float(wave["back_height"]), 0.0)
		vertical_accel += crest_rise * launch_boost * launch_ratio * support_amount
		vertical_accel += face_lift * wave_face_lift * speed_ratio * support_amount

	velocity.y += vertical_accel * delta

	if not was_grounded and grounded:
		_apply_landing_response()

	if support_amount > 0.20:
		var dynamic_submerge_depth: float = max_submerge_depth + dive_extra_depth * dive_ratio
		var min_y: float = surface_height + target_clearance - dynamic_submerge_depth
		if global_position.y < min_y:
			global_position.y = min_y
			velocity.y = maxf(velocity.y, 0.0)
		elif support_amount > 0.85 and absf(height_error) < 0.08 and absf(velocity.y - wave_vertical_speed) < 1.4:
			var settle_softness: float = 1.0 - clampf(landing_sink / maxf(max_submerge_depth + landing_dive_depth, 0.001), 0.0, 1.0) * reentry_softness
			global_position.y = lerpf(global_position.y, surface_height + target_clearance, clampf(delta * 4.8 * settle_softness, 0.0, 1.0))


func _apply_landing_response() -> void:
	var impact_speed: float = maxf(-velocity.y, 0.0)
	if impact_speed <= 0.0:
		return

	var nose_down: float = clampf(-pitch_angle / maxf(max_air_pitch_angle, 0.001), 0.0, 1.0)
	var nose_up: float = clampf(pitch_angle / maxf(max_air_pitch_angle, 0.001), 0.0, 1.0)
	var sink_amount: float = impact_speed * (landing_base_sink + nose_down * landing_dive_depth)
	landing_sink = clampf(maxf(landing_sink, sink_amount), 0.0, max_submerge_depth + landing_dive_depth)

	if nose_up > 0.0:
		velocity.y = maxf(velocity.y, impact_speed * nose_up * landing_bounce - impact_speed * 0.30)
	else:
		velocity.y = -impact_speed * lerpf(0.18, 0.60, nose_down)


func _step_planar(delta: float) -> void:
	var max_speed: float = max_speed_kph / 3.6
	var max_reverse_speed: float = reverse_speed_kph / 3.6
	var speed_ratio: float = clampf(maxf(forward_speed, 0.0) / max_speed, 0.0, 1.0)
	var thrust_grip: float = lerpf(0.35, 1.0, traction_amount)

	if throttle_input > 0.0:
		var thrust: float = throttle_input * forward_accel * thrust_grip
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
	var carve_strength: float = lerpf(0.18, 1.0, traction_amount) * lerpf(0.45, 1.0, speed_ratio)
	var yaw_target: float = steer_input * turn_rate * yaw_authority * carve_strength
	if forward_speed < -0.5:
		yaw_target *= -0.55
	else:
		yaw_target += steer_input * speed_ratio * traction_amount * 0.35
	yaw_target -= slip_speed * 0.12 * traction_amount

	yaw_speed = move_toward(yaw_speed, yaw_target, turn_response * delta)
	var yaw_decay: float = yaw_damping + (1.0 - absf(steer_input)) * 1.4
	yaw_speed = move_toward(yaw_speed, 0.0, yaw_decay * delta * lerpf(0.35, 1.0, traction_amount))
	heading += yaw_speed * delta

	slip_speed += yaw_speed * maxf(forward_speed, 0.0) * slip_push * delta * lerpf(0.25, 1.0, traction_amount)
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
	if support_amount > 0.20:
		var speed_ratio: float = clampf(
			(maxf(forward_speed, 0.0) - dive_speed_threshold) / maxf(max_speed_kph / 3.6 - dive_speed_threshold, 0.001),
			0.0,
			1.0
		)
		var dynamic_submerge_depth: float = max_submerge_depth + dive_extra_depth * speed_ratio * clampf(nose_input, 0.0, 1.0)
		var min_y: float = surface_height + target_clearance - dynamic_submerge_depth
		if global_position.y < min_y:
			global_position.y = min_y
			velocity.y = maxf(velocity.y, 0.0)
	water_clearance = global_position.y - surface_height


func _update_attitude(delta: float, wave: Dictionary) -> void:
	var air_ratio: float = 1.0 - support_amount
	if air_ratio > 0.05:
		var pitch_input: float = nose_input
		air_pitch_velocity = move_toward(air_pitch_velocity, pitch_input * air_pitch_torque, delta * 8.0)
		air_pitch_velocity = move_toward(air_pitch_velocity, 0.0, air_pitch_damping * delta * lerpf(1.0, 0.40, absf(pitch_input)))
		air_pitch_offset = clampf(air_pitch_offset + air_pitch_velocity * delta, -max_air_pitch_angle, max_air_pitch_angle)

		var roll_input: float = -steer_input
		air_roll_velocity = move_toward(air_roll_velocity, roll_input * air_roll_torque, delta * 8.0)
		air_roll_velocity = move_toward(air_roll_velocity, 0.0, air_roll_damping * delta * lerpf(1.0, 0.40, absf(roll_input)))
		air_roll_offset = clampf(air_roll_offset + air_roll_velocity * delta, -max_air_roll_angle, max_air_roll_angle)
	else:
		air_pitch_velocity = move_toward(air_pitch_velocity, 0.0, air_pitch_damping * delta * 2.2)
		air_roll_velocity = move_toward(air_roll_velocity, 0.0, air_roll_damping * delta * 2.2)
		air_pitch_offset = move_toward(air_pitch_offset, 0.0, (landing_sink_recovery + 1.2) * delta)
		air_roll_offset = move_toward(air_roll_offset, 0.0, (landing_sink_recovery + 1.8) * delta)

	var up_dir: Vector3 = Vector3.UP.lerp(surface_normal, support_amount).normalized()
	var forward: Vector3 = _heading_forward().slide(up_dir).normalized()
	if forward.length_squared() < 0.001:
		forward = _heading_forward()
	var right: Vector3 = forward.cross(up_dir).normalized()

	var speed_ratio: float = clampf(maxf(forward_speed, 0.0) / (max_speed_kph / 3.6), 0.0, 1.0)
	var target_pitch: float = (float(wave["back_height"]) - float(wave["front_height"])) * slope_pitch
	target_pitch -= throttle_input * 0.05 * support_amount
	target_pitch -= nose_input * water_pitch_control * support_amount
	target_pitch -= (velocity.y - wave_vertical_speed) * 0.012
	target_pitch += planing_amount * 0.04
	target_pitch -= nose_input * air_pitch_control * air_ratio
	target_pitch += air_pitch_offset * air_ratio
	target_pitch = clampf(target_pitch, -max_air_pitch_angle, max_air_pitch_angle)

	var target_roll: float = (float(wave["left_height"]) - float(wave["right_height"])) * slope_roll
	target_roll -= steer_input * (0.08 + speed_ratio * bank_angle) * support_amount
	target_roll -= slip_speed * 0.018
	target_roll += air_roll_offset * air_ratio
	target_roll = clampf(target_roll, -max_air_roll_angle, max_air_roll_angle)

	var blended_response: float = lerpf(attitude_response * 0.55, attitude_response, support_amount)
	var attitude_alpha: float = clampf(delta * blended_response, 0.0, 1.0)
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
	nose_input = 0.0
	grounded = false
	traction_amount = 0.0
	support_amount = 0.0
	forward_speed = 0.0
	slip_speed = 0.0
	surface_height = pos.y
	surface_normal = Vector3.UP
	water_clearance = ride_height
	target_clearance = ride_height
	planing_amount = 0.0
	wave_vertical_speed = 0.0
	landing_sink = 0.0
	air_pitch_velocity = 0.0
	air_roll_velocity = 0.0
	air_pitch_offset = 0.0
	air_roll_offset = 0.0
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
	file.store_line("time,dt,throttle,steer,grounded,traction,support,forward_speed,slip_speed,clearance,target_clearance,planing,wave_vy,landing_sink,pos_x,pos_y,pos_z,vel_x,vel_y,vel_z,speed_kph,heading_deg,yaw_speed,pitch_deg,roll_deg,normal_x,normal_y,normal_z,front_h,back_h,left_h,right_h")


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
	file.store_line("%.3f,%.3f,%.3f,%.3f,%s,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.2f,%.3f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f" % [
		Time.get_ticks_msec() * 0.001,
		delta,
		throttle_input,
		steer_input,
		str(grounded),
		traction_amount,
		support_amount,
		forward_speed,
		slip_speed,
		water_clearance,
		target_clearance,
		planing_amount,
		wave_vertical_speed,
		landing_sink,
		global_position.x,
		global_position.y,
		global_position.z,
		velocity.x,
		velocity.y,
		velocity.z,
		speed_kph(),
		rad_to_deg(heading),
		yaw_speed,
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

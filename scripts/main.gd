extends Node3D

const CHECKPOINT_COUNT := 10
const CHECKPOINT_RADIUS := 360.0
const CHECKPOINT_TRIGGER_RADIUS := 24.0
const START_POS := Vector3(0, 0.0, -310.0)
const WAVE_AMPLITUDE_MIN := 0.0
const WAVE_AMPLITUDE_MAX := 10.0
const WAVE_FREQUENCY_MIN := 0.25
const WAVE_FREQUENCY_MAX := 4.0
const DETAIL_PATCH_RADIUS := 145.0
const MID_PATCH_RADIUS := 540.0

const WAVE_DIRS := [
	Vector2(0.978, 0.210),
	Vector2(-0.612, 0.791),
	Vector2(0.334, 0.943),
	Vector2(-0.935, 0.355),
	Vector2(0.822, -0.569),
	Vector2(-0.179, -0.984),
	Vector2(0.608, 0.794),
	Vector2(-0.768, -0.640),
]
const WAVE_AMPLITUDES := [0.72, 0.36, 0.22, 0.16, 0.11, 0.08, 0.06, 0.04]
const WAVE_FREQUENCIES := [0.008, 0.014, 0.024, 0.038, 0.061, 0.092, 0.138, 0.205]
const WAVE_SPEEDS := [0.40, 0.62, 0.88, 1.18, 1.58, 2.05, 2.75, 3.45]
const WAVE_PHASES := [0.0, 1.1, 2.4, 0.65, 1.9, 2.8, 0.45, 1.55]

@onready var status_label: Label = $UI/Status
@onready var hud_label: Label = $UI/Hud
@onready var amplitude_slider: HSlider = $UI/WavePanel/Margin/VBox/AmplitudeSlider
@onready var amplitude_value_label: Label = $UI/WavePanel/Margin/VBox/AmplitudeValue
@onready var frequency_slider: HSlider = $UI/WavePanel/Margin/VBox/FrequencySlider
@onready var frequency_value_label: Label = $UI/WavePanel/Margin/VBox/FrequencyValue

var jetski
var follow_camera: Camera3D
var ocean_mesh: MeshInstance3D
var ocean_mid_mesh: MeshInstance3D
var ocean_detail_mesh: MeshInstance3D
var ocean_material: ShaderMaterial
var ocean_mid_material: ShaderMaterial
var ocean_detail_material: ShaderMaterial
var wave_amplitude := 1.15
var wave_frequency := 1.0

var checkpoint_positions: Array[Vector3] = []
var checkpoint_nodes: Array[MeshInstance3D] = []
var checkpoint_index := 0
var lap := 1
var lap_time := 0.0
var best_lap := INF


func _ready() -> void:
	_build_world()
	_build_checkpoints()
	_spawn_jetski()
	_spawn_camera()
	_setup_wave_controls()
	_update_checkpoint_visuals()
	status_label.text = "WaveRun • Custom Water Prototype\nDebug log: %s" % jetski.call("debug_log_path")


func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		_reset_run()

	lap_time += delta
	_update_ocean()
	_update_camera(delta)
	_check_checkpoint_progress()
	_update_hud()


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PhysicalSkyMaterial.new()
	sky_mat.rayleigh_coefficient = 2.1
	sky_mat.mie_coefficient = 0.02
	sky_mat.sun_disk_scale = 2.0
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_density = 0.0009
	environment.fog_sky_affect = 0.6

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-38, -20, 0)
	add_child(sun)

	ocean_mesh = MeshInstance3D.new()
	ocean_mesh.name = "OceanFar"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6400, 6400)
	plane.subdivide_width = 220
	plane.subdivide_depth = 220
	ocean_mesh.mesh = plane
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = load("res://materials/ocean.gdshader")
	ocean_mesh.material_override = ocean_material
	_configure_ocean_patch(ocean_material, MID_PATCH_RADIUS, 5000.0)
	add_child(ocean_mesh)

	ocean_mid_mesh = MeshInstance3D.new()
	ocean_mid_mesh.name = "OceanMid"
	var mid_plane := PlaneMesh.new()
	mid_plane.size = Vector2(1100, 1100)
	mid_plane.subdivide_width = 340
	mid_plane.subdivide_depth = 340
	ocean_mid_mesh.mesh = mid_plane
	ocean_mid_material = ShaderMaterial.new()
	ocean_mid_material.shader = load("res://materials/ocean.gdshader")
	ocean_mid_mesh.material_override = ocean_mid_material
	_configure_ocean_patch(ocean_mid_material, DETAIL_PATCH_RADIUS, MID_PATCH_RADIUS)
	add_child(ocean_mid_mesh)

	ocean_detail_mesh = MeshInstance3D.new()
	ocean_detail_mesh.name = "OceanDetail"
	var detail_plane := PlaneMesh.new()
	detail_plane.size = Vector2(260, 260)
	detail_plane.subdivide_width = 420
	detail_plane.subdivide_depth = 420
	ocean_detail_mesh.mesh = detail_plane
	ocean_detail_material = ShaderMaterial.new()
	ocean_detail_material.shader = load("res://materials/ocean.gdshader")
	ocean_detail_mesh.material_override = ocean_detail_material
	_configure_ocean_patch(ocean_detail_material, 0.0, DETAIL_PATCH_RADIUS)
	add_child(ocean_detail_mesh)


func _build_checkpoints() -> void:
	for i in range(CHECKPOINT_COUNT):
		var angle := TAU * float(i) / float(CHECKPOINT_COUNT)
		var pos := Vector3(cos(angle) * CHECKPOINT_RADIUS, 0.0, sin(angle) * CHECKPOINT_RADIUS)
		checkpoint_positions.append(pos)

		var buoy := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.6
		cyl.bottom_radius = 2.4
		cyl.height = 7.0
		buoy.mesh = cyl
		buoy.position = pos + Vector3(0, 3.5, 0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.3, 0.25)
		mat.metallic = 0.05
		mat.roughness = 0.32
		buoy.material_override = mat

		add_child(buoy)
		checkpoint_nodes.append(buoy)


func _spawn_jetski() -> void:
	jetski = load("res://scripts/jetski.gd").new()
	jetski.name = "Jetski"
	add_child(jetski)

	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(1.25, 0.42, 2.35)
	hull.mesh = hull_mesh

	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.98, 0.82, 0.22)
	hull_mat.roughness = 0.28
	hull.material_override = hull_mat
	jetski.add_child(hull)

	var seat := MeshInstance3D.new()
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.65, 0.25, 0.75)
	seat.mesh = seat_mesh
	seat.position = Vector3(0, 0.25, 0.25)

	var seat_mat := StandardMaterial3D.new()
	seat_mat.albedo_color = Color(0.08, 0.08, 0.1)
	seat.material_override = seat_mat
	jetski.add_child(seat)

	jetski.call("hard_reset", _start_position(), 0.0)


func _spawn_camera() -> void:
	follow_camera = Camera3D.new()
	follow_camera.current = true
	follow_camera.fov = 72.0
	follow_camera.near = 0.03
	follow_camera.far = 12000.0
	add_child(follow_camera)
	follow_camera.global_position = _start_position() + Vector3(0, 8, 14)


func _setup_wave_controls() -> void:
	amplitude_slider.min_value = WAVE_AMPLITUDE_MIN
	amplitude_slider.max_value = WAVE_AMPLITUDE_MAX
	amplitude_slider.step = 0.05
	amplitude_slider.value = wave_amplitude
	amplitude_slider.value_changed.connect(_on_amplitude_slider_changed)

	frequency_slider.min_value = WAVE_FREQUENCY_MIN
	frequency_slider.max_value = WAVE_FREQUENCY_MAX
	frequency_slider.step = 0.05
	frequency_slider.value = wave_frequency
	frequency_slider.value_changed.connect(_on_frequency_slider_changed)

	_apply_wave_controls()


func _update_camera(delta: float) -> void:
	if jetski == null or follow_camera == null:
		return

	var forward: Vector3 = -jetski.global_basis.z
	var target: Vector3 = jetski.global_position + Vector3(0, 2.2, 0)
	var desired: Vector3 = target - forward * 13.5 + Vector3(0, 5.2, 0)
	var alpha: float = 1.0 - exp(-delta * 4.2)
	follow_camera.global_position = follow_camera.global_position.lerp(desired, alpha)
	follow_camera.look_at(target, Vector3.UP)


func _update_ocean() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if jetski:
		ocean_mesh.global_position.x = snapped(jetski.global_position.x, 32.0)
		ocean_mesh.global_position.z = snapped(jetski.global_position.z, 32.0)
		ocean_mid_mesh.global_position.x = snapped(jetski.global_position.x, 8.0)
		ocean_mid_mesh.global_position.z = snapped(jetski.global_position.z, 8.0)
		ocean_detail_mesh.global_position.x = snapped(jetski.global_position.x, 4.0)
		ocean_detail_mesh.global_position.z = snapped(jetski.global_position.z, 4.0)
	_sync_ocean_material(ocean_material, ocean_mesh.global_position, now)
	_sync_ocean_material(ocean_mid_material, ocean_mid_mesh.global_position, now)
	_sync_ocean_material(ocean_detail_material, ocean_detail_mesh.global_position, now)


func _check_checkpoint_progress() -> void:
	if jetski == null:
		return

	var target: Vector3 = checkpoint_positions[checkpoint_index]
	if jetski.global_position.distance_to(target) <= CHECKPOINT_TRIGGER_RADIUS:
		checkpoint_index += 1
		if checkpoint_index >= CHECKPOINT_COUNT:
			checkpoint_index = 0
			if lap_time < best_lap:
				best_lap = lap_time
			lap += 1
			lap_time = 0.0
		_update_checkpoint_visuals()


func _update_checkpoint_visuals() -> void:
	for i in range(checkpoint_nodes.size()):
		var mat := checkpoint_nodes[i].material_override as StandardMaterial3D
		if i == checkpoint_index:
			mat.albedo_color = Color(0.25, 1.0, 0.58)
			mat.emission_enabled = true
			mat.emission = Color(0.15, 0.9, 0.45)
			mat.emission_energy_multiplier = 2.0
		else:
			mat.albedo_color = Color(0.95, 0.3, 0.25)
			mat.emission_enabled = false


func _update_hud() -> void:
	if jetski == null:
		return

	var speed: float = float(jetski.call("speed_kph"))
	var best_text := "--"
	if best_lap < INF:
		best_text = _fmt_time(best_lap)
	hud_label.text = "Speed: %d kph\nLap: %d\nCheckpoint: %d/%d\nLap time: %s\nBest: %s\nAmp: %.2fx\nFreq: %.2fx" % [
		int(speed),
		lap,
		checkpoint_index + 1,
		CHECKPOINT_COUNT,
		_fmt_time(lap_time),
		best_text,
		wave_amplitude,
		wave_frequency,
	]


func _reset_run() -> void:
	lap = 1
	lap_time = 0.0
	checkpoint_index = 0
	if jetski:
		jetski.call("hard_reset", _start_position(), 0.0)
	_update_checkpoint_visuals()


func _fmt_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	var millis := int((seconds - floor(seconds)) * 1000.0)
	return "%02d:%02d.%03d" % [mins, secs, millis]


func _sync_ocean_material(material: ShaderMaterial, mesh_pos: Vector3, now: float) -> void:
	material.set_shader_parameter("u_time", now)
	material.set_shader_parameter("wave_amplitude", wave_amplitude)
	material.set_shader_parameter("wave_frequency", wave_frequency)
	material.set_shader_parameter("mesh_origin", Vector2(mesh_pos.x, mesh_pos.z))


func _configure_ocean_patch(material: ShaderMaterial, inner_radius: float, outer_radius: float) -> void:
	material.set_shader_parameter("patch_inner_radius", inner_radius)
	material.set_shader_parameter("patch_outer_radius", outer_radius)


func _start_position() -> Vector3:
	var start := START_POS
	start.y = wave_height_at(start) + 1.20
	return start


func wave_height_at(world_pos: Vector3, t: float = -1.0) -> float:
	if t < 0.0:
		t = Time.get_ticks_msec() * 0.001
	return float(_wave_state(Vector2(world_pos.x, world_pos.z), t)["height"])


func wave_normal_at(world_pos: Vector3, t: float = -1.0) -> Vector3:
	if t < 0.0:
		t = Time.get_ticks_msec() * 0.001
	return _wave_state(Vector2(world_pos.x, world_pos.z), t)["normal"]


func _wave_state(p: Vector2, t: float) -> Dictionary:
	var height: float = 0.0
	var grad_x: float = 0.0
	var grad_y: float = 0.0
	var frequency_speed_scale: float = sqrt(maxf(wave_frequency, 0.001))

	for i in range(WAVE_DIRS.size()):
		var dir: Vector2 = WAVE_DIRS[i]
		var amp: float = WAVE_AMPLITUDES[i] * wave_amplitude
		var freq: float = WAVE_FREQUENCIES[i] * wave_frequency
		var phase: float = p.dot(dir) * freq + t * WAVE_SPEEDS[i] * frequency_speed_scale + WAVE_PHASES[i]
		var s: float = sin(phase)
		var c: float = cos(phase)

		height += s * amp
		grad_x += c * amp * freq * dir.x
		grad_y += c * amp * freq * dir.y

	return {
		"height": height,
		"normal": Vector3(-grad_x, 1.0, -grad_y).normalized(),
	}


func _on_amplitude_slider_changed(value: float) -> void:
	wave_amplitude = value
	_apply_wave_controls()


func _on_frequency_slider_changed(value: float) -> void:
	wave_frequency = value
	_apply_wave_controls()


func _apply_wave_controls() -> void:
	amplitude_value_label.text = "Amplitude %.2fx" % wave_amplitude
	frequency_value_label.text = "Frequency %.2fx" % wave_frequency
	if ocean_material:
		ocean_material.set_shader_parameter("wave_amplitude", wave_amplitude)
		ocean_material.set_shader_parameter("wave_frequency", wave_frequency)
	if ocean_mid_material:
		ocean_mid_material.set_shader_parameter("wave_amplitude", wave_amplitude)
		ocean_mid_material.set_shader_parameter("wave_frequency", wave_frequency)
	if ocean_detail_material:
		ocean_detail_material.set_shader_parameter("wave_amplitude", wave_amplitude)
		ocean_detail_material.set_shader_parameter("wave_frequency", wave_frequency)

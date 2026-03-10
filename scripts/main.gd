extends Node3D

const CHECKPOINT_COUNT := 10
const CHECKPOINT_RADIUS := 360.0
const CHECKPOINT_TRIGGER_RADIUS := 24.0
const START_POS := Vector3(0, 4.0, -310.0)

@onready var status_label: Label = $UI/Status
@onready var hud_label: Label = $UI/Hud

var jetski: RigidBody3D
var follow_camera: Camera3D
var ocean_mesh: MeshInstance3D
var ocean_material: ShaderMaterial

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
	_update_checkpoint_visuals()
	status_label.text = "WaveRun • Open Ocean Circuit"


func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		_reset_run()

	lap_time += delta
	_update_ocean()
	_update_camera(delta)
	_check_checkpoint_progress()
	_update_hud()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := PhysicalSkyMaterial.new()
	sky_mat.rayleigh_coefficient = 2.1
	sky_mat.mie_coefficient = 0.02
	sky_mat.sun_disk_scale = 2.0
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.fog_enabled = true
	e.fog_density = 0.0009
	e.fog_sky_affect = 0.6
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-38, -20, 0)
	add_child(sun)

	ocean_mesh = MeshInstance3D.new()
	ocean_mesh.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(6400, 6400)
	plane.subdivide_width = 220
	plane.subdivide_depth = 220
	ocean_mesh.mesh = plane
	ocean_material = ShaderMaterial.new()
	ocean_material.shader = load("res://materials/ocean.gdshader")
	ocean_mesh.material_override = ocean_material
	add_child(ocean_mesh)


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
	jetski = RigidBody3D.new()
	jetski.name = "Jetski"
	jetski.script = load("res://scripts/jetski.gd")
	jetski.mass = 240.0
	jetski.linear_damp = 0.08
	jetski.angular_damp = 0.22
	jetski.continuous_cd = true
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

	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.25, 0.42, 2.3)
	collider.shape = shape
	jetski.add_child(collider)

	jetski.hard_reset(START_POS, 0.0)


func _spawn_camera() -> void:
	follow_camera = Camera3D.new()
	follow_camera.current = true
	follow_camera.fov = 72.0
	follow_camera.near = 0.03
	follow_camera.far = 12000.0
	add_child(follow_camera)
	follow_camera.global_position = START_POS + Vector3(0, 8, 14)


func _update_camera(delta: float) -> void:
	if jetski == null or follow_camera == null:
		return

	var forward := -jetski.global_basis.z
	var target := jetski.global_position + Vector3(0, 2.6, 0)
	var desired := target - forward * 12.0 + Vector3(0, 4.0, 0)
	var alpha := 1.0 - exp(-delta * 5.0)
	follow_camera.global_position = follow_camera.global_position.lerp(desired, alpha)
	follow_camera.look_at(target, Vector3.UP)


func _update_ocean() -> void:
	var now := Time.get_ticks_msec() * 0.001
	ocean_material.set_shader_parameter("u_time", now)
	if jetski:
		# Keep the ocean centered around the player so it feels endless.
		ocean_mesh.global_position.x = snapped(jetski.global_position.x, 32.0)
		ocean_mesh.global_position.z = snapped(jetski.global_position.z, 32.0)


func _check_checkpoint_progress() -> void:
	if jetski == null:
		return

	var target := checkpoint_positions[checkpoint_index]
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

	var speed: float = jetski.linear_velocity.length() * 3.6
	var best_text := "--"
	if best_lap < INF:
		best_text = _fmt_time(best_lap)
	hud_label.text = "Speed: %d kph\nLap: %d\nCheckpoint: %d/%d\nLap time: %s\nBest: %s" % [
		int(speed),
		lap,
		checkpoint_index + 1,
		CHECKPOINT_COUNT,
		_fmt_time(lap_time),
		best_text
	]


func _reset_run() -> void:
	lap = 1
	lap_time = 0.0
	checkpoint_index = 0
	if jetski:
		jetski.hard_reset(START_POS, 0.0)
	_update_checkpoint_visuals()


func _fmt_time(seconds: float) -> String:
	var mins := int(seconds) / 60
	var secs := int(seconds) % 60
	var millis := int((seconds - floor(seconds)) * 1000.0)
	return "%02d:%02d.%03d" % [mins, secs, millis]


func wave_height_at(world_pos: Vector3, t: float = -1.0) -> float:
	if t < 0.0:
		t = Time.get_ticks_msec() * 0.001
	var p := Vector2(world_pos.x, world_pos.z)
	var h := 0.0
	h += sin(p.dot(Vector2(0.970, 0.242)) * 0.050 + t * 1.80) * 2.40
	h += sin(p.dot(Vector2(-0.573, 0.819)) * 0.092 + t * 2.45 + 1.4) * 1.30
	h += sin(p.dot(Vector2(0.287, 0.958)) * 0.165 + t * 3.15 + 2.1) * 0.55
	return h


func wave_normal_at(world_pos: Vector3, t: float = -1.0) -> Vector3:
	var eps := 0.55
	var hx := wave_height_at(world_pos + Vector3(eps, 0, 0), t) - wave_height_at(world_pos - Vector3(eps, 0, 0), t)
	var hz := wave_height_at(world_pos + Vector3(0, 0, eps), t) - wave_height_at(world_pos - Vector3(0, 0, eps), t)
	return Vector3(-hx, 2.0 * eps, -hz).normalized()

extends Node3D

const CHECKPOINT_COUNT := 10
const CHECKPOINT_RADIUS := 360.0
const CHECKPOINT_TRIGGER_RADIUS := 24.0
const START_POS := Vector3(0, 0.0, -310.0)
const WAVE_AMPLITUDE_MIN := 0.0
const WAVE_AMPLITUDE_MAX := 10.0
const WAVE_FREQUENCY_MIN := 0.25
const WAVE_FREQUENCY_MAX := 4.0
const WAVE_SPEED_MIN := 0.1
const WAVE_SPEED_MAX := 4.0
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
const JETSKI_TUNABLES := [
	{"property": "max_speed_kph", "label": "Top Speed", "min": 20.0, "max": 180.0, "step": 1.0},
	{"property": "reverse_speed_kph", "label": "Reverse Speed", "min": 5.0, "max": 45.0, "step": 1.0},
	{"property": "forward_accel", "label": "Forward Accel", "min": 1.0, "max": 45.0, "step": 0.25},
	{"property": "reverse_accel", "label": "Reverse Accel", "min": 0.0, "max": 20.0, "step": 0.25},
	{"property": "brake_accel", "label": "Brake Accel", "min": 0.0, "max": 30.0, "step": 0.25},
	{"property": "coast_drag", "label": "Coast Drag", "min": 0.0, "max": 12.0, "step": 0.05},
	{"property": "water_drag", "label": "Water Drag", "min": 0.0, "max": 4.0, "step": 0.05},
	{"property": "air_drag", "label": "Air Drag", "min": 0.0, "max": 2.0, "step": 0.05},
	{"property": "water_grip", "label": "Water Grip", "min": 0.0, "max": 40.0, "step": 0.25},
	{"property": "air_grip", "label": "Air Grip", "min": 0.0, "max": 10.0, "step": 0.05},
	{"property": "slip_push", "label": "Slip Push", "min": 0.0, "max": 4.0, "step": 0.05},
	{"property": "turn_rate", "label": "Turn Rate", "min": 0.0, "max": 6.0, "step": 0.05},
	{"property": "turn_response", "label": "Turn Response", "min": 0.0, "max": 16.0, "step": 0.1},
	{"property": "yaw_damping", "label": "Yaw Damping", "min": 0.0, "max": 10.0, "step": 0.1},
	{"property": "gravity_force", "label": "Gravity", "min": 0.0, "max": 40.0, "step": 0.25},
	{"property": "ride_height", "label": "Ride Height", "min": 0.1, "max": 3.0, "step": 0.05},
	{"property": "planing_height", "label": "Planing Lift", "min": 0.0, "max": 1.5, "step": 0.05},
	{"property": "ride_spring", "label": "Ride Spring", "min": 0.0, "max": 90.0, "step": 0.5},
	{"property": "ride_damping", "label": "Ride Damping", "min": 0.0, "max": 30.0, "step": 0.25},
	{"property": "ride_contact_height", "label": "Support Band", "min": 0.05, "max": 2.0, "step": 0.05},
	{"property": "airborne_height", "label": "Grip Release", "min": 0.05, "max": 3.0, "step": 0.05},
	{"property": "max_submerge_depth", "label": "Max Submerge", "min": 0.1, "max": 3.0, "step": 0.05},
	{"property": "reentry_snap_speed", "label": "Reentry Snap", "min": 0.0, "max": 30.0, "step": 0.25},
	{"property": "surface_follow", "label": "Surface Follow", "min": 0.0, "max": 2.0, "step": 0.05},
	{"property": "launch_boost", "label": "Launch Boost", "min": 0.0, "max": 20.0, "step": 0.25},
	{"property": "launch_speed_threshold", "label": "Launch Threshold", "min": 0.0, "max": 25.0, "step": 0.25},
	{"property": "wave_face_lift", "label": "Wave Face Lift", "min": 0.0, "max": 20.0, "step": 0.25},
	{"property": "landing_base_sink", "label": "Base Landing Sink", "min": 0.0, "max": 1.0, "step": 0.01},
	{"property": "landing_dive_depth", "label": "Landing Dive", "min": 0.0, "max": 2.5, "step": 0.05},
	{"property": "landing_bounce", "label": "Landing Bounce", "min": 0.0, "max": 4.0, "step": 0.05},
	{"property": "landing_sink_recovery", "label": "Dive Recovery", "min": 0.0, "max": 12.0, "step": 0.1},
	{"property": "reentry_softness", "label": "Reentry Softness", "min": 0.0, "max": 1.0, "step": 0.01},
	{"property": "bank_angle", "label": "Bank Angle", "min": 0.0, "max": 1.2, "step": 0.01},
	{"property": "slope_roll", "label": "Slope Roll", "min": 0.0, "max": 0.5, "step": 0.01},
	{"property": "slope_pitch", "label": "Slope Pitch", "min": 0.0, "max": 0.5, "step": 0.01},
	{"property": "attitude_response", "label": "Attitude Response", "min": 0.5, "max": 14.0, "step": 0.1},
	{"property": "water_pitch_control", "label": "Water Pitch Ctrl", "min": 0.0, "max": 1.2, "step": 0.01},
	{"property": "air_pitch_control", "label": "Air Pitch Ctrl", "min": 0.0, "max": 2.0, "step": 0.01},
	{"property": "dive_clearance_offset", "label": "Dive Clearance", "min": 0.0, "max": 2.5, "step": 0.05},
	{"property": "dive_extra_depth", "label": "Dive Extra Depth", "min": 0.0, "max": 3.0, "step": 0.05},
	{"property": "dive_speed_threshold", "label": "Dive Threshold", "min": 0.0, "max": 20.0, "step": 0.25},
	{"property": "air_pitch_torque", "label": "Air Pitch Torque", "min": 0.0, "max": 8.0, "step": 0.05},
	{"property": "air_pitch_damping", "label": "Air Pitch Damping", "min": 0.0, "max": 8.0, "step": 0.05},
	{"property": "air_roll_torque", "label": "Air Roll Torque", "min": 0.0, "max": 8.0, "step": 0.05},
	{"property": "air_roll_damping", "label": "Air Roll Damping", "min": 0.0, "max": 8.0, "step": 0.05},
	{"property": "max_air_pitch_angle", "label": "Max Air Pitch", "min": 0.1, "max": 1.5, "step": 0.01},
	{"property": "max_air_roll_angle", "label": "Max Air Roll", "min": 0.1, "max": 1.5, "step": 0.01},
]
const CAMERA_TUNABLES := [
	{"property": "camera_follow_offset_x", "label": "Follow Offset X", "min": -20.0, "max": 20.0, "step": 0.1},
	{"property": "camera_follow_offset_y", "label": "Follow Offset Y", "min": -5.0, "max": 20.0, "step": 0.1},
	{"property": "camera_follow_offset_z", "label": "Follow Offset Z", "min": 1.0, "max": 30.0, "step": 0.1},
	{"property": "camera_target_offset_x", "label": "Target Offset X", "min": -10.0, "max": 10.0, "step": 0.1},
	{"property": "camera_target_offset_y", "label": "Target Offset Y", "min": -5.0, "max": 10.0, "step": 0.1},
	{"property": "camera_target_offset_z", "label": "Target Offset Z", "min": -10.0, "max": 10.0, "step": 0.1},
	{"property": "camera_smoothing", "label": "Camera Smoothing", "min": 0.1, "max": 12.0, "step": 0.1},
	{"property": "camera_fov", "label": "Camera FOV", "min": 30.0, "max": 120.0, "step": 1.0},
	{"property": "camera_near", "label": "Camera Near", "min": 0.01, "max": 2.0, "step": 0.01},
	{"property": "camera_far", "label": "Camera Far", "min": 100.0, "max": 20000.0, "step": 10.0},
	{"property": "camera_drag_sensitivity", "label": "Orbit Drag Sens", "min": 0.001, "max": 0.03, "step": 0.001},
	{"property": "camera_pitch_min", "label": "Pitch Min", "min": -1.5, "max": 0.0, "step": 0.01},
	{"property": "camera_pitch_max", "label": "Pitch Max", "min": -0.2, "max": 1.2, "step": 0.01},
	{"property": "camera_default_orbit_yaw", "label": "Default Orbit Yaw", "min": -3.14, "max": 3.14, "step": 0.01},
	{"property": "camera_default_orbit_pitch", "label": "Default Orbit Pitch", "min": -1.2, "max": 0.8, "step": 0.01},
]
const WAVE_TOOLTIPS := {
	"amplitude": "Controls how tall the waves get. Higher values make the water rougher and bumpier.",
	"frequency": "Controls how tightly packed the waves are. Higher values make the water choppier with more waves close together.",
	"speed": "Controls how fast the waves move across the water. Higher values make the whole ocean motion move faster.",
}
const JETSKI_TUNING_TOOLTIPS := {
	"max_speed_kph": "Sets the fastest speed the jetski can reach going forward.",
	"reverse_speed_kph": "Sets the fastest speed the jetski can reach while backing up.",
	"forward_accel": "Controls how quickly the jetski speeds up when you press the throttle.",
	"reverse_accel": "Controls how quickly the jetski picks up speed in reverse.",
	"brake_accel": "Controls how hard the jetski slows down when you brake.",
	"coast_drag": "Controls how much the jetski slows itself when you let off the throttle.",
	"water_drag": "Controls how much the water resists movement. Higher values scrub speed faster on the surface.",
	"air_drag": "Controls how much speed is lost while the jetski is in the air.",
	"water_grip": "Controls how strongly the jetski sticks to its direction on the water instead of sliding sideways.",
	"air_grip": "Controls how much steering still works while airborne.",
	"slip_push": "Controls how much sideways slide turns into a shove. Higher values make drifts feel more forceful.",
	"turn_rate": "Sets the maximum turning strength.",
	"turn_response": "Controls how quickly the jetski reacts when you start steering.",
	"yaw_damping": "Controls how quickly extra spinning settles down after a turn.",
	"gravity_force": "Controls how strongly the jetski is pulled downward.",
	"ride_height": "Sets how high the jetski tries to float above the water.",
	"planing_height": "Adds extra lift at speed so the jetski rides higher when moving fast.",
	"ride_spring": "Controls how strongly the jetski pushes back up when the water drops out from under it.",
	"ride_damping": "Controls how much bouncing is smoothed out after the jetski moves up or down.",
	"ride_contact_height": "Controls how far from the water the jetski can be and still get strong support.",
	"airborne_height": "Controls how far above the water the jetski can get before it fully loses water grip.",
	"max_submerge_depth": "Sets how deep the jetski is allowed to sink into the water.",
	"reentry_snap_speed": "Controls how aggressively the jetski snaps back toward the water after coming down.",
	"surface_follow": "Controls how much the jetski follows the up-and-down motion of the waves.",
	"launch_boost": "Adds extra upward kick when the jetski launches off a wave.",
	"launch_speed_threshold": "Sets how fast you need to be before launch boost really starts to matter.",
	"wave_face_lift": "Controls how much the front of a wave helps pop the jetski upward.",
	"landing_base_sink": "Controls how much the jetski sinks into the water on any landing, even when it lands flat.",
	"landing_dive_depth": "Controls how much the nose wants to dip into the water when landing.",
	"landing_bounce": "Controls how springy the jetski feels after it slaps back onto the water.",
	"landing_sink_recovery": "Controls how quickly the jetski climbs back to normal after a heavy landing.",
	"reentry_softness": "Controls how soft the buoyancy feels right after landing. Higher values stop the jetski from popping back up so quickly.",
	"bank_angle": "Controls how much the jetski leans sideways while turning.",
	"slope_roll": "Controls how much the jetski tilts sideways to match the wave slope.",
	"slope_pitch": "Controls how much the jetski tilts forward or backward to match the wave slope.",
	"attitude_response": "Controls how quickly the jetski lines its body back up to the target angle.",
	"water_pitch_control": "Controls how much you can lift or lower the nose while still touching the water.",
	"air_pitch_control": "Controls how much you can pitch the nose up or down while in the air.",
	"dive_clearance_offset": "Controls how much pressing the nose down makes the jetski ride lower.",
	"dive_extra_depth": "Controls how much extra depth the jetski can push into the water during a dive.",
	"dive_speed_threshold": "Sets how fast you must be before nose-down diving starts to take effect.",
	"air_pitch_torque": "Controls how strongly the jetski rotates nose up or down in the air.",
	"air_pitch_damping": "Controls how quickly airborne front-back rotation settles down.",
	"air_roll_torque": "Controls how strongly the jetski rolls side to side in the air.",
	"air_roll_damping": "Controls how quickly airborne side-roll motion settles down.",
	"max_air_pitch_angle": "Sets the furthest the nose can tilt up or down in the air.",
	"max_air_roll_angle": "Sets the furthest the jetski can roll sideways in the air.",
}
const CAMERA_TUNING_TOOLTIPS := {
	"camera_follow_offset_x": "Moves the camera left or right relative to the jetski.",
	"camera_follow_offset_y": "Moves the camera higher or lower behind the jetski.",
	"camera_follow_offset_z": "Moves the camera closer or farther behind the jetski.",
	"camera_target_offset_x": "Moves the point the camera looks at left or right.",
	"camera_target_offset_y": "Moves the point the camera looks at higher or lower.",
	"camera_target_offset_z": "Moves the point the camera looks at forward or backward on the jetski.",
	"camera_smoothing": "Controls how quickly the camera catches up. Lower values feel floatier, higher values feel locked on.",
	"camera_fov": "Controls how wide the camera view is.",
	"camera_near": "Controls how close objects can get to the camera before they clip out.",
	"camera_far": "Controls how far away objects stay visible.",
	"camera_drag_sensitivity": "Controls how fast right-mouse camera dragging rotates the view.",
	"camera_pitch_min": "Sets the lowest angle you can drag the camera down to.",
	"camera_pitch_max": "Sets the highest angle you can drag the camera up to.",
	"camera_default_orbit_yaw": "Sets the camera's default left-right orbit angle when you reset.",
	"camera_default_orbit_pitch": "Sets the camera's default up-down orbit angle when you reset.",
}

@onready var status_label: Label = $UI/Status
@onready var hud_label: Label = $UI/Hud
@onready var jetski_stats_label: Label = $UI/JetskiStatsPanel/Margin/VBox/JetskiStats
@onready var wave_collision_graph: Control = $UI/JetskiStatsPanel/Margin/VBox/WaveCollisionGraph
@onready var amplitude_slider: HSlider = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveContent/AmplitudeSlider
@onready var amplitude_value_label: Label = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveContent/AmplitudeValue
@onready var frequency_slider: HSlider = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveContent/FrequencySlider
@onready var frequency_value_label: Label = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveContent/FrequencyValue
@onready var speed_slider: HSlider = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveContent/SpeedSlider
@onready var speed_value_label: Label = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveContent/SpeedValue
@onready var wave_toggle_button: Button = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveToggle
@onready var wave_content: VBoxContainer = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/WaveSection/WaveContent
@onready var jetski_toggle_button: Button = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/JetskiSection/JetskiToggle
@onready var jetski_content: VBoxContainer = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/JetskiSection/JetskiContent
@onready var copy_settings_button: Button = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/JetskiSection/JetskiContent/CopySettingsButton
@onready var physics_tuning_box: VBoxContainer = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/JetskiSection/JetskiContent/PhysicsVBox
@onready var camera_toggle_button: Button = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/CameraSection/CameraToggle
@onready var camera_content: VBoxContainer = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/CameraSection/CameraContent
@onready var copy_camera_settings_button: Button = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/CameraSection/CameraContent/CopyCameraSettingsButton
@onready var camera_tuning_box: VBoxContainer = $UI/SidebarPanel/Margin/VBox/SidebarScroll/Sections/CameraSection/CameraContent/CameraVBox

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
var wave_speed := 1.0
var camera_follow_offset_x := 0.0
var camera_follow_offset_y := 5.2
var camera_follow_offset_z := 13.5
var camera_target_offset_x := 0.0
var camera_target_offset_y := 2.2
var camera_target_offset_z := 0.0
var camera_smoothing := 4.2
var camera_fov := 72.0
var camera_near := 0.03
var camera_far := 12000.0
var camera_drag_sensitivity := 0.008
var camera_pitch_min := -0.85
var camera_pitch_max := 0.35
var camera_default_orbit_yaw := 0.0
var camera_default_orbit_pitch := -0.18
var camera_dragging := false
var camera_orbit_yaw := 0.0
var camera_orbit_pitch := -0.18

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
	wave_collision_graph.call("clear_samples")
	_setup_wave_controls()
	_setup_sidebar_sections()
	_setup_copy_settings_button()
	_setup_jetski_controls()
	_setup_camera_controls()
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
	_update_jetski_stats()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		camera_dragging = event.pressed
		if camera_dragging:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and camera_dragging:
		camera_orbit_yaw -= event.relative.x * camera_drag_sensitivity
		camera_orbit_pitch = clampf(
			camera_orbit_pitch - event.relative.y * camera_drag_sensitivity,
			camera_pitch_min,
			camera_pitch_max
		)


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
	follow_camera.fov = camera_fov
	follow_camera.near = camera_near
	follow_camera.far = camera_far
	add_child(follow_camera)
	camera_orbit_yaw = camera_default_orbit_yaw
	camera_orbit_pitch = camera_default_orbit_pitch
	follow_camera.global_position = _camera_desired_position()


func _setup_wave_controls() -> void:
	amplitude_slider.min_value = WAVE_AMPLITUDE_MIN
	amplitude_slider.max_value = WAVE_AMPLITUDE_MAX
	amplitude_slider.step = 0.05
	amplitude_slider.value = wave_amplitude
	amplitude_slider.tooltip_text = WAVE_TOOLTIPS["amplitude"]
	amplitude_value_label.tooltip_text = WAVE_TOOLTIPS["amplitude"]
	amplitude_slider.value_changed.connect(_on_amplitude_slider_changed)

	frequency_slider.min_value = WAVE_FREQUENCY_MIN
	frequency_slider.max_value = WAVE_FREQUENCY_MAX
	frequency_slider.step = 0.05
	frequency_slider.value = wave_frequency
	frequency_slider.tooltip_text = WAVE_TOOLTIPS["frequency"]
	frequency_value_label.tooltip_text = WAVE_TOOLTIPS["frequency"]
	frequency_slider.value_changed.connect(_on_frequency_slider_changed)

	speed_slider.min_value = WAVE_SPEED_MIN
	speed_slider.max_value = WAVE_SPEED_MAX
	speed_slider.step = 0.05
	speed_slider.value = wave_speed
	speed_slider.tooltip_text = WAVE_TOOLTIPS["speed"]
	speed_value_label.tooltip_text = WAVE_TOOLTIPS["speed"]
	speed_slider.value_changed.connect(_on_speed_slider_changed)

	_apply_wave_controls()


func _setup_copy_settings_button() -> void:
	copy_settings_button.tooltip_text = "Copies the current jetski tuning values so you can paste them into chat."
	copy_settings_button.pressed.connect(_on_copy_settings_button_pressed)
	copy_camera_settings_button.tooltip_text = "Copies the current camera tuning values so you can paste them into chat."
	copy_camera_settings_button.pressed.connect(_on_copy_camera_settings_button_pressed)


func _setup_sidebar_sections() -> void:
	_bind_section_toggle(wave_toggle_button, wave_content, "Wave Settings")
	_bind_section_toggle(jetski_toggle_button, jetski_content, "Jetski Settings")
	_bind_section_toggle(camera_toggle_button, camera_content, "Camera Settings")


func _bind_section_toggle(button: Button, content: Control, title: String) -> void:
	button.toggle_mode = true
	button.button_pressed = content.visible
	_update_section_toggle_label(button, title, content.visible)
	button.toggled.connect(_on_section_toggled.bind(content, button, title))


func _on_section_toggled(pressed: bool, content: Control, button: Button, title: String) -> void:
	content.visible = pressed
	_update_section_toggle_label(button, title, pressed)


func _update_section_toggle_label(button: Button, title: String, expanded: bool) -> void:
	button.text = "%s %s" % ["Hide" if expanded else "Show", title]


func _setup_jetski_controls() -> void:
	if jetski == null:
		return

	for child in physics_tuning_box.get_children():
		child.free()

	for config in JETSKI_TUNABLES:
		var property_name := str(config["property"])
		var tooltip_text := _get_jetski_tuning_tooltip(property_name)
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 2)
		row.tooltip_text = tooltip_text

		var label := Label.new()
		label.add_theme_font_size_override("font_size", 17)
		label.tooltip_text = tooltip_text
		row.add_child(label)

		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = float(config["min"])
		slider.max_value = float(config["max"])
		slider.step = float(config["step"])
		slider.value = float(jetski.get(property_name))
		slider.tooltip_text = tooltip_text
		slider.value_changed.connect(_on_jetski_tuning_changed.bind(property_name, str(config["label"]), label, float(config["step"])))
		row.add_child(slider)

		physics_tuning_box.add_child(row)
		_update_jetski_tuning_label(label, str(config["label"]), slider.value, float(config["step"]))


func _setup_camera_controls() -> void:
	for child in camera_tuning_box.get_children():
		child.free()

	for config in CAMERA_TUNABLES:
		var property_name := str(config["property"])
		var tooltip_text := _get_camera_tuning_tooltip(property_name)
		var row := VBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 2)
		row.tooltip_text = tooltip_text

		var label := Label.new()
		label.add_theme_font_size_override("font_size", 17)
		label.tooltip_text = tooltip_text
		row.add_child(label)

		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = float(config["min"])
		slider.max_value = float(config["max"])
		slider.step = float(config["step"])
		slider.value = float(get(property_name))
		slider.tooltip_text = tooltip_text
		slider.value_changed.connect(_on_camera_tuning_changed.bind(property_name, str(config["label"]), label, float(config["step"])))
		row.add_child(slider)

		camera_tuning_box.add_child(row)
		_update_jetski_tuning_label(label, str(config["label"]), slider.value, float(config["step"]))


func _update_camera(delta: float) -> void:
	if jetski == null or follow_camera == null:
		return

	follow_camera.fov = camera_fov
	follow_camera.near = camera_near
	follow_camera.far = camera_far
	var target: Vector3 = _camera_target_position()
	var orbit_basis := Basis(Vector3.UP, camera_orbit_yaw) * Basis(Vector3.RIGHT, camera_orbit_pitch)
	var desired: Vector3 = target + jetski.global_basis * (orbit_basis * _camera_follow_offset())
	var alpha: float = 1.0 - exp(-delta * camera_smoothing)
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
	hud_label.text = "Speed: %d kph\nLap: %d\nCheckpoint: %d/%d\nLap time: %s\nBest: %s\nAmp: %.2fx\nFreq: %.2fx\nWave Speed: %.2fx" % [
		int(speed),
		lap,
		checkpoint_index + 1,
		CHECKPOINT_COUNT,
		_fmt_time(lap_time),
		best_text,
		wave_amplitude,
		wave_frequency,
		wave_speed,
	]


func _update_jetski_stats() -> void:
	if jetski == null:
		return

	var speed_kph := float(jetski.call("speed_kph"))
	var forward_speed := float(jetski.get("forward_speed")) * 3.6
	var slip_speed := float(jetski.get("slip_speed")) * 3.6
	var grounded := bool(jetski.get("grounded"))
	var traction := float(jetski.get("traction_amount"))
	var support := float(jetski.get("support_amount"))
	var clearance := float(jetski.get("water_clearance"))
	var target_clearance := float(jetski.get("target_clearance"))
	var planing := float(jetski.get("planing_amount"))
	var pitch_deg := rad_to_deg(float(jetski.get("pitch_angle")))
	var roll_deg := rad_to_deg(float(jetski.get("roll_angle")))
	var yaw_deg := rad_to_deg(float(jetski.get("heading")))
	var surface_height := float(jetski.get("surface_height"))
	var body_height: float = jetski.global_position.y

	jetski_stats_label.text = "Jetski Live Stats\nSpeed: %.1f kph\nForward: %.1f kph\nSlide: %.1f kph\nGrounded: %s\nTraction: %.2f\nSupport: %.2f\nClearance: %.2f m\nTarget Height: %.2f m\nPlaning: %.2f\nPitch: %.1f deg\nRoll: %.1f deg\nHeading: %.1f deg" % [
		speed_kph,
		forward_speed,
		slip_speed,
		"Yes" if grounded else "No",
		traction,
		support,
		clearance,
		target_clearance,
		planing,
		pitch_deg,
		roll_deg,
		yaw_deg,
	]
	wave_collision_graph.call("push_sample", body_height, surface_height)


func _reset_run() -> void:
	lap = 1
	lap_time = 0.0
	checkpoint_index = 0
	camera_orbit_yaw = camera_default_orbit_yaw
	camera_orbit_pitch = camera_default_orbit_pitch
	camera_dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if jetski:
		jetski.call("hard_reset", _start_position(), 0.0)
	wave_collision_graph.call("clear_samples")
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
	material.set_shader_parameter("wave_speed", wave_speed)
	material.set_shader_parameter("mesh_origin", Vector2(mesh_pos.x, mesh_pos.z))


func _configure_ocean_patch(material: ShaderMaterial, inner_radius: float, outer_radius: float) -> void:
	material.set_shader_parameter("patch_inner_radius", inner_radius)
	material.set_shader_parameter("patch_outer_radius", outer_radius)


func _start_position() -> Vector3:
	var start := START_POS
	start.y = wave_height_at(start) + 1.20
	return start


func _camera_follow_offset() -> Vector3:
	return Vector3(camera_follow_offset_x, camera_follow_offset_y, camera_follow_offset_z)


func _camera_target_offset() -> Vector3:
	return Vector3(camera_target_offset_x, camera_target_offset_y, camera_target_offset_z)


func _camera_target_position() -> Vector3:
	if jetski == null:
		return _start_position() + _camera_target_offset()
	return jetski.global_position + _camera_target_offset()


func _camera_desired_position() -> Vector3:
	var target: Vector3 = _camera_target_position()
	var orbit_basis := Basis(Vector3.UP, camera_orbit_yaw) * Basis(Vector3.RIGHT, camera_orbit_pitch)
	if jetski == null:
		return target + orbit_basis * _camera_follow_offset()
	return target + jetski.global_basis * (orbit_basis * _camera_follow_offset())


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
		var phase: float = p.dot(dir) * freq + t * WAVE_SPEEDS[i] * frequency_speed_scale * wave_speed + WAVE_PHASES[i]
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


func _on_speed_slider_changed(value: float) -> void:
	wave_speed = value
	_apply_wave_controls()


func _apply_wave_controls() -> void:
	amplitude_value_label.text = "Amplitude %.2fx" % wave_amplitude
	frequency_value_label.text = "Frequency %.2fx" % wave_frequency
	speed_value_label.text = "Speed %.2fx" % wave_speed
	if ocean_material:
		ocean_material.set_shader_parameter("wave_amplitude", wave_amplitude)
		ocean_material.set_shader_parameter("wave_frequency", wave_frequency)
		ocean_material.set_shader_parameter("wave_speed", wave_speed)
	if ocean_mid_material:
		ocean_mid_material.set_shader_parameter("wave_amplitude", wave_amplitude)
		ocean_mid_material.set_shader_parameter("wave_frequency", wave_frequency)
		ocean_mid_material.set_shader_parameter("wave_speed", wave_speed)
	if ocean_detail_material:
		ocean_detail_material.set_shader_parameter("wave_amplitude", wave_amplitude)
		ocean_detail_material.set_shader_parameter("wave_frequency", wave_frequency)
		ocean_detail_material.set_shader_parameter("wave_speed", wave_speed)


func _on_jetski_tuning_changed(value: float, property_name: String, display_name: String, value_label: Label, step: float) -> void:
	if jetski == null:
		return

	jetski.set(property_name, value)
	_update_jetski_tuning_label(value_label, display_name, value, step)


func _on_camera_tuning_changed(value: float, property_name: String, display_name: String, value_label: Label, step: float) -> void:
	set(property_name, value)
	if property_name == "camera_pitch_min" and camera_pitch_min > camera_pitch_max:
		camera_pitch_max = camera_pitch_min
	elif property_name == "camera_pitch_max" and camera_pitch_max < camera_pitch_min:
		camera_pitch_min = camera_pitch_max
	camera_orbit_pitch = clampf(camera_orbit_pitch, camera_pitch_min, camera_pitch_max)
	_update_jetski_tuning_label(value_label, display_name, value, step)


func _update_jetski_tuning_label(value_label: Label, display_name: String, value: float, step: float) -> void:
	value_label.text = "%s: %s" % [display_name, _format_slider_value(value, step)]


func _format_slider_value(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(value)))
	return str(snappedf(value, step))


func _on_copy_settings_button_pressed() -> void:
	if jetski == null:
		return

	var settings_text := _serialize_jetski_settings()
	DisplayServer.clipboard_set(settings_text)
	copy_settings_button.text = "Copied Jetski Settings"


func _on_copy_camera_settings_button_pressed() -> void:
	var settings_text := _serialize_camera_settings()
	DisplayServer.clipboard_set(settings_text)
	copy_camera_settings_button.text = "Copied Camera Settings"


func _serialize_jetski_settings() -> String:
	var lines: Array[String] = ["Jetski settings:"]

	for config in JETSKI_TUNABLES:
		var property_name := str(config["property"])
		var value := float(jetski.get(property_name))
		var step := float(config["step"])
		lines.append("%s = %s" % [property_name, _format_slider_value(value, step)])

	return "\n".join(lines)


func _serialize_camera_settings() -> String:
	var lines: Array[String] = ["Camera settings:"]

	for config in CAMERA_TUNABLES:
		var property_name := str(config["property"])
		var value := float(get(property_name))
		var step := float(config["step"])
		lines.append("%s = %s" % [property_name, _format_slider_value(value, step)])

	return "\n".join(lines)


func _get_jetski_tuning_tooltip(property_name: String) -> String:
	return str(JETSKI_TUNING_TOOLTIPS.get(property_name, "Adjusts how this part of the jetski handling feels."))


func _get_camera_tuning_tooltip(property_name: String) -> String:
	return str(CAMERA_TUNING_TOOLTIPS.get(property_name, "Adjusts how the follow camera behaves."))

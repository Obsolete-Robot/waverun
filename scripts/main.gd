extends Node2D

const PLAYER_SPEED := 460.0
const PLAYER_RADIUS := 16.0
const OBSTACLE_RADIUS := 25.0

var player_x := 0.0
var score := 0.0
var game_over := false
var spawn_timer := 0.0
var spawn_interval := 0.9
var obstacles: Array[Dictionary] = []

@onready var score_label: Label = $UI/Score
@onready var status_label: Label = $UI/Status

func _ready() -> void:
	_new_run()


func _new_run() -> void:
	randomize()
	score = 0.0
	game_over = false
	spawn_interval = 0.9
	spawn_timer = 0.3
	obstacles.clear()
	player_x = get_viewport_rect().size.x * 0.5
	_update_ui()
	queue_redraw()


func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_R):
			_new_run()
		return

	var axis := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D):
		axis += 1.0

	var view_size := get_viewport_rect().size
	player_x = clamp(player_x + axis * PLAYER_SPEED * delta, PLAYER_RADIUS, view_size.x - PLAYER_RADIUS)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_row()
		spawn_interval = clamp(spawn_interval - 0.003, 0.45, 1.0)
		spawn_timer = spawn_interval + randf_range(-0.15, 0.18)

	for obstacle in obstacles:
		obstacle["position"].y += obstacle["speed"] * delta

	obstacles = obstacles.filter(func(o: Dictionary) -> bool:
		return o["position"].y < view_size.y + 90.0
	)

	_check_collisions()
	score += delta * 10.0
	_update_ui()
	queue_redraw()


func _spawn_row() -> void:
	var view_size := get_viewport_rect().size
	var lane_count := 9
	var lane_width := view_size.x / float(lane_count)
	var blocked := {}
	var count := randi_range(2, 4)

	while blocked.size() < count:
		blocked[randi_range(0, lane_count - 1)] = true

	for lane in blocked.keys():
		var x := (float(lane) + 0.5) * lane_width
		obstacles.append({
			"position": Vector2(x, -60.0),
			"speed": randf_range(180.0, 280.0),
			"radius": OBSTACLE_RADIUS
		})


func _check_collisions() -> void:
	var p := Vector2(player_x, _player_y())
	for obstacle in obstacles:
		var dist := p.distance_to(obstacle["position"])
		if dist < PLAYER_RADIUS + obstacle["radius"] - 3.0:
			game_over = true
			status_label.text = "Hull breach! Press Enter or R to run again."
			return


func _player_y() -> float:
	return get_viewport_rect().size.y - 74.0


func _update_ui() -> void:
	score_label.text = "Score: %d" % int(score)
	if not game_over:
		status_label.text = "Dodge the wave cores • Move: ← → or A/D"


func _draw() -> void:
	var rect := get_viewport_rect()
	draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.043, 0.071, 0.125, 1.0), true)

	# Subtle lane guides
	var lane_count := 9
	for i in range(1, lane_count):
		var x := rect.size.x * float(i) / float(lane_count)
		draw_line(Vector2(x, 0), Vector2(x, rect.size.y), Color(0.18, 0.28, 0.42, 0.28), 1.0)

	# Obstacles
	for obstacle in obstacles:
		var pos: Vector2 = obstacle["position"]
		var radius: float = obstacle["radius"]
		draw_circle(pos, radius, Color(0.21, 0.78, 0.98, 0.95))
		draw_arc(pos, radius + 9.0, 0.0, TAU, 24, Color(0.4, 0.9, 1.0, 0.55), 2.0)

	# Player
	var py := _player_y()
	var p1 := Vector2(player_x, py - (PLAYER_RADIUS + 6.0))
	var p2 := Vector2(player_x - PLAYER_RADIUS, py + PLAYER_RADIUS)
	var p3 := Vector2(player_x + PLAYER_RADIUS, py + PLAYER_RADIUS)
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1, 0.92, 0.5, 1.0))
	draw_circle(Vector2(player_x, py + 2.0), 6.0, Color(0.1, 0.1, 0.14, 1.0))

	if game_over:
		draw_rect(Rect2(0, 0, rect.size.x, rect.size.y), Color(0, 0, 0, 0.42), true)

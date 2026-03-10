extends Control

const MAX_SAMPLES := 120
const BG_COLOR := Color(0.05, 0.09, 0.14, 0.92)
const GRID_COLOR := Color(1.0, 1.0, 1.0, 0.10)
const AXIS_COLOR := Color(1.0, 1.0, 1.0, 0.22)
const WAVE_COLOR := Color(0.22, 0.74, 1.0, 1.0)
const JETSKI_COLOR := Color(1.0, 0.88, 0.28, 1.0)
const TEXT_COLOR := Color(0.92, 0.96, 1.0, 1.0)
const MIN_VISIBLE_SAMPLES := 20
const DRAG_X_SCALE := 0.40
const DRAG_Y_SCALE := 0.015

var _wave_samples: Array[float] = []
var _jetski_samples: Array[float] = []
var _visible_samples: int = MAX_SAMPLES
var _y_zoom: float = 1.0
var _middle_dragging: bool = false
var _drag_accum: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Blue line is the water surface. Yellow line is the jetski body height. Middle-drag left/right to change time scale, up/down to change height scale. Middle click resets."


func push_sample(jetski_y: float, wave_y: float) -> void:
	_wave_samples.append(wave_y)
	_jetski_samples.append(jetski_y)

	if _wave_samples.size() > MAX_SAMPLES:
		_wave_samples.remove_at(0)
	if _jetski_samples.size() > MAX_SAMPLES:
		_jetski_samples.remove_at(0)

	queue_redraw()


func clear_samples() -> void:
	_wave_samples.clear()
	_jetski_samples.clear()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.double_click:
			return
		_middle_dragging = event.pressed
		if event.pressed:
			_drag_accum = Vector2.ZERO
			accept_event()
		else:
			if _drag_accum.length() < 6.0:
				_reset_drag_scales()
	elif event is InputEventMouseMotion and _middle_dragging:
		_drag_accum += event.relative
		_adjust_drag_scales(event.relative)
		accept_event()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, BG_COLOR, true)

	if size.x <= 4.0 or size.y <= 4.0:
		return

	var plot := rect.grow_individual(-8.0, -8.0, -8.0, -24.0)
	draw_rect(plot, Color(1.0, 1.0, 1.0, 0.03), true)
	draw_rect(plot, AXIS_COLOR, false, 1.0)

	for i in range(1, 4):
		var y := plot.position.y + plot.size.y * float(i) / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), GRID_COLOR, 1.0)

	if _wave_samples.is_empty() or _jetski_samples.is_empty():
		_draw_caption("Waiting for samples...")
		return

	var sample_count: int = mini(_visible_samples, _wave_samples.size())
	var start_index: int = maxi(_wave_samples.size() - sample_count, 0)

	var min_value: float = _slice_min(_wave_samples, start_index)
	var max_value: float = _slice_max(_wave_samples, start_index)
	min_value = minf(min_value, _slice_min(_jetski_samples, start_index))
	max_value = maxf(max_value, _slice_max(_jetski_samples, start_index))
	var span: float = maxf(max_value - min_value, 0.2)
	var center: float = (min_value + max_value) * 0.5
	var half_span: float = maxf((span * 0.5 + maxf(span * 0.18, 0.08)) / _y_zoom, 0.1)
	min_value = center - half_span
	max_value = center + half_span

	_draw_series(_wave_samples, start_index, plot, min_value, max_value, WAVE_COLOR, 2.0)
	_draw_series(_jetski_samples, start_index, plot, min_value, max_value, JETSKI_COLOR, 2.0)

	var latest_wave: float = _wave_samples[_wave_samples.size() - 1]
	var latest_jetski: float = _jetski_samples[_jetski_samples.size() - 1]
	var gap: float = latest_jetski - latest_wave
	_draw_caption("Blue water  Yellow jetski  Gap %.2fm  X %d  Y %.2fx" % [gap, sample_count, _y_zoom])


func _draw_series(samples: Array[float], start_index: int, plot: Rect2, min_value: float, max_value: float, color: Color, width: float) -> void:
	var count: int = samples.size() - start_index
	if count < 2:
		return

	var prev: Vector2 = _sample_point(samples[start_index], 0, count, plot, min_value, max_value)
	for i in range(1, count):
		var current: Vector2 = _sample_point(samples[start_index + i], i, count, plot, min_value, max_value)
		draw_line(prev, current, color, width, true)
		prev = current


func _sample_point(value: float, index: int, count: int, plot: Rect2, min_value: float, max_value: float) -> Vector2:
	var x_ratio: float = 0.0 if count <= 1 else float(index) / float(count - 1)
	var y_ratio: float = inverse_lerp(max_value, min_value, value)
	return Vector2(
		plot.position.x + plot.size.x * x_ratio,
		plot.position.y + plot.size.y * y_ratio
	)


func _draw_caption(text: String) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 12
	if font == null:
		return
	draw_string(font, Vector2(10, size.y - 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, TEXT_COLOR)


func _slice_min(samples: Array[float], start_index: int) -> float:
	var min_value: float = samples[start_index]
	for i in range(start_index + 1, samples.size()):
		min_value = minf(min_value, samples[i])
	return min_value


func _slice_max(samples: Array[float], start_index: int) -> float:
	var max_value: float = samples[start_index]
	for i in range(start_index + 1, samples.size()):
		max_value = maxf(max_value, samples[i])
	return max_value


func _adjust_drag_scales(relative: Vector2) -> void:
	var sample_delta: int = int(round(relative.x * DRAG_X_SCALE))
	_visible_samples = clampi(_visible_samples + sample_delta, MIN_VISIBLE_SAMPLES, MAX_SAMPLES)

	var next_y_zoom: float = _y_zoom * exp(-relative.y * DRAG_Y_SCALE)
	_y_zoom = clampf(next_y_zoom, 0.35, 6.0)
	queue_redraw()


func _reset_drag_scales() -> void:
	_visible_samples = MAX_SAMPLES
	_y_zoom = 1.0
	queue_redraw()

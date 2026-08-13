# 挂到 Line2D 上，把实线渲染成虚线
extends Line2D

@export var dash_length: float = 10.0
@export var gap_length: float = 6.0

func _draw() -> void:
	if points.size() < 2:
		return

	var color := default_color
	var w := width

	var i := 0
	while i < points.size() - 1:
		var p1 := points[i]
		var p2 := points[i + 1]
		var segment := p2 - p1
		var seg_len := segment.length()
		if seg_len <= 0.0:
			i += 1
			continue

		var dir := segment.normalized()
		var cursor := 0.0
		while cursor < seg_len:
			var remaining := seg_len - cursor
			var dash := minf(dash_length, remaining)
			var start := p1 + dir * cursor
			var end := p1 + dir * (cursor + dash)
			draw_line(start, end, color, w, true)
			cursor += dash + gap_length
		i += 1

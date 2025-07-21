extends Control
class_name LineDrawer

var lines: Array = []

func add_line(from: Vector2, to: Vector2, color: Color = Color.WHITE, width: float = 4.0, dotted: bool = true, arrow: bool = true) -> void:
	lines.append({
		"from": from,
		"to": to, 
		"color": color,
		"width": width,
		"dotted": dotted,
		"arrow": arrow
	})
	queue_redraw()

func clear_lines() -> void:
	lines.clear()
	queue_redraw()

func _draw() -> void:
	for line_data in lines:
		if line_data.dotted:
			_draw_dotted_line(line_data.from, line_data.to, line_data.color, line_data.width)
		else:
			draw_line(line_data.from, line_data.to, line_data.color, line_data.width)
		
		# Draw arrow if requested
		if line_data.get("arrow", true):
			_draw_arrow(line_data.from, line_data.to, line_data.color, line_data.width)

func _draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (to - from).normalized()
	var distance: float = from.distance_to(to)
	var dot_length: float = 8.0
	var gap_length: float = 12.0
	var pattern_length: float = dot_length + gap_length
	
	var current_distance: float = 0.0
	while current_distance < distance:
		var start_pos: Vector2 = from + direction * current_distance
		var end_distance: float = min(current_distance + dot_length, distance)
		var end_pos: Vector2 = from + direction * end_distance
		
		draw_line(start_pos, end_pos, color, width)
		current_distance += pattern_length

func _draw_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var direction: Vector2 = (to - from).normalized()
	var arrow_length: float = 15.0
	var arrow_width: float = 8.0
	
	# Position the arrow at 70% along the line (not at the very end to avoid overlap with node)
	var arrow_pos: Vector2 = from + direction * (from.distance_to(to) * 0.7)
	
	# Calculate arrow points
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	var arrow_tip: Vector2 = arrow_pos + direction * arrow_length * 0.5
	var arrow_left: Vector2 = arrow_pos - direction * arrow_length * 0.5 + perpendicular * arrow_width * 0.5
	var arrow_right: Vector2 = arrow_pos - direction * arrow_length * 0.5 - perpendicular * arrow_width * 0.5
	
	# Draw filled triangle arrow
	var arrow_points: PackedVector2Array = PackedVector2Array([arrow_tip, arrow_left, arrow_right])
	draw_colored_polygon(arrow_points, color)

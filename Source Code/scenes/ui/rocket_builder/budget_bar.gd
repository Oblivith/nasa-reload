# SI assistance metadata: This code used the help of SI.
class_name BudgetBar
extends Control

var cost: float = 0.0
var budget: float = 1.0

func _init() -> void:
	custom_minimum_size = Vector2(380, 40)

func set_values(new_cost: float, new_budget: float, breakdown: String) -> void:
	cost = new_cost
	budget = maxf(new_budget, 0.001)
	tooltip_text = breakdown
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(0, 4), Vector2(size.x, size.y - 8))
	draw_rect(rect, Color("c9bd9f"))
	var fraction := cost / budget
	var color := ConsoleTheme.PASS
	if fraction > 1.0:
		color = ConsoleTheme.FAIL
	elif fraction > 0.85:
		color = ConsoleTheme.WARN
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)), color)
	for i in range(1, 10):
		var x := rect.size.x * i / 10.0
		draw_line(Vector2(x, rect.end.y - 7), Vector2(x, rect.end.y), ConsoleTheme.INK, 1.5)
	draw_rect(rect, ConsoleTheme.INK, false, 3.0)
	var text := "$%.1fM of $%.0fM" % [cost, budget]
	draw_string(ConsoleTheme.typewriter(), Vector2(0, rect.position.y + rect.size.y / 2.0 + 7), text,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, ConsoleTheme.INK)

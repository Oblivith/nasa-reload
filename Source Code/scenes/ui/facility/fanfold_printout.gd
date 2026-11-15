# SI assistance metadata: This code used the help of SI.
class_name FanfoldPrintout
extends Control

signal printed

const LINE_HEIGHT := 22.0
const MARGIN := 64.0
const LINES_PER_PAGE := 44
const FONT_SIZE := 16
const GREEN_BAR := Color("dcefd8")
const PAPER := Color("fbfbf4")
const HOLE := Color("1d3b3a")
const INK := Color("2b2622")

var lines: PackedStringArray = []
var lines_per_second: float = 45.0
var _shown: float = 0.0
var _done: bool = false

func set_text(text: String, wrap_columns: int = 116) -> void:
	lines = []
	for raw in text.split("\n"):
		var line := raw
		while line.length() > wrap_columns:
			var cut := line.substr(0, wrap_columns).rfind(" ")
			if cut < 20:
				cut = wrap_columns
			lines.append(line.substr(0, cut))
			line = "        " + line.substr(cut).strip_edges()
		lines.append(line)
	_shown = 0.0
	_done = false
	custom_minimum_size = Vector2(MARGIN * 2.0 + wrap_columns * 9.7, (lines.size() + 4) * LINE_HEIGHT)
	queue_redraw()

func finish_now() -> void:
	_shown = float(lines.size())

func _process(delta: float) -> void:
	if _done:
		return
	_shown = minf(float(lines.size()), _shown + delta * lines_per_second)
	queue_redraw()
	if _shown >= float(lines.size()):
		_done = true
		printed.emit()

func _draw() -> void:
	var visible_count := int(_shown)
	var paper_h := (visible_count + 4) * LINE_HEIGHT
	draw_rect(Rect2(0, 0, size.x, paper_h), PAPER)

	var row := 0
	while row * LINE_HEIGHT < paper_h:
		if (row / 3) % 2 == 0:
			draw_rect(Rect2(MARGIN - 10, row * LINE_HEIGHT, size.x - 2 * MARGIN + 20, LINE_HEIGHT), GREEN_BAR)
		row += 1

	var y := LINE_HEIGHT * 0.5
	while y < paper_h:
		draw_circle(Vector2(MARGIN * 0.4, y), 6.0, HOLE)
		draw_circle(Vector2(size.x - MARGIN * 0.4, y), 6.0, HOLE)
		y += LINE_HEIGHT
	for x: float in [MARGIN * 0.8, size.x - MARGIN * 0.8]:
		var dy := 0.0
		while dy < paper_h:
			draw_line(Vector2(x, dy), Vector2(x, dy + 4), Color(0.6, 0.6, 0.55), 1.0)
			dy += 8.0

	var page := LINES_PER_PAGE
	while page * LINE_HEIGHT < paper_h:
		var py := page * LINE_HEIGHT
		var dx := 0.0
		while dx < size.x:
			draw_line(Vector2(dx, py), Vector2(dx + 6, py), Color(0.55, 0.55, 0.5), 1.0)
			dx += 12.0
		page += LINES_PER_PAGE
	var font := ConsoleTheme.mono()
	for i in visible_count:
		draw_string(font, Vector2(MARGIN + 6, (i + 2) * LINE_HEIGHT - 5), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)

	if not _done:
		var head_y := (visible_count + 2) * LINE_HEIGHT
		draw_rect(Rect2(MARGIN, head_y - 4, size.x - 2 * MARGIN, 6), Color(0.15, 0.15, 0.15, 0.7))

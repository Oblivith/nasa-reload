# Code generated with AI assistance (Claude). Reviewed by team.
class_name ConsoleTheme
extends RefCounted
## 1960s mission-console look for the Rocket Builder: cream panels on a dark teal desk,
## mustard and burnt-orange accents, chunky borders, monospace + typewriter type.
## Fonts: drop OFL .ttf/.otf files at res://assets/ui/fonts/typewriter.* and mono.* to
## bundle them (needed for the Web export); otherwise system fonts are used.

const DESK := Color("1d3b3a")
const DESK_DARK := Color("142a29")
const CREAM := Color("f2e8cf")
const PAPER := Color("fbf5e6")
const TEAL := Color("2a7b7b")
const TEAL_DARK := Color("1f5c5c")
const TEAL_LIGHT := Color("8fc1b5")
const MUSTARD := Color("d9a42b")
const ORANGE := Color("c8551f")
const INK := Color("2b2622")
const INK_SOFT := Color("6b5f53")
const PASS := Color("3f8f4f")
const WARN := Color("d9a42b")
const FAIL := Color("c0392b")
const CG_BLUE := Color("2456a6")
const CP_RED := Color("c0392b")

static var _typewriter: Font
static var _mono: Font


static func typewriter() -> Font:
	if _typewriter == null:
		_typewriter = _load_font("typewriter", ["Courier Prime", "American Typewriter", "Courier New", "Courier", "monospace"], 700)
	return _typewriter


static func mono() -> Font:
	if _mono == null:
		_mono = _load_font("mono", ["IBM Plex Mono", "Consolas", "Lucida Console", "Menlo", "Courier New", "monospace"], 400)
	return _mono


static func status_color(status: String) -> Color:
	match status:
		"pass":
			return PASS
		"warn":
			return WARN
	return FAIL


static func panel(bg: Color, border: Color = INK, border_width: int = 4, radius: int = 10, pad: int = 14) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 0
	box.shadow_offset = Vector2(0, 5)
	return box


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = mono()
	theme.default_font_size = 18

	theme.set_stylebox("panel", "PanelContainer", panel(CREAM))
	theme.set_color("font_color", "Label", INK)

	# Buttons: chunky cream keys with an ink outline; pressed/toggled = burnt orange.
	var normal := panel(PAPER, INK, 3, 8, 8)
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(0, 3)
	var hover := panel(Color("fff3c9"), INK, 3, 8, 8)
	hover.shadow_size = 1
	hover.shadow_offset = Vector2(0, 3)
	var pressed := panel(ORANGE, INK, 3, 8, 8)
	var disabled := panel(Color("d8cfb8"), INK_SOFT, 3, 8, 8)
	var focus := panel(Color(0, 0, 0, 0), MUSTARD, 3, 8, 8)
	focus.draw_center = false
	for type in ["Button", "OptionButton", "CheckBox"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, PAPER)
		theme.set_color("font_hover_pressed_color", type, PAPER)
		theme.set_color("font_focus_color", type, INK)
		theme.set_color("font_disabled_color", type, INK_SOFT)
		theme.set_font("font", type, typewriter())
	# CheckBox keeps a flat look; its box icon carries the state.
	var flat := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		theme.set_stylebox(state, "CheckBox", flat)
	theme.set_color("font_pressed_color", "CheckBox", INK)
	theme.set_color("font_hover_pressed_color", "CheckBox", INK)

	var field := panel(PAPER, TEAL_DARK, 2, 4, 6)
	var field_focus := panel(Color("fffbea"), ORANGE, 3, 4, 6)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_stylebox("read_only", "LineEdit", panel(Color("e6dcc2"), INK_SOFT, 2, 4, 6))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(INK_SOFT, 0.7))
	theme.set_color("caret_color", "LineEdit", ORANGE)
	theme.set_color("selection_color", "LineEdit", Color(MUSTARD, 0.5))

	# Sliders: a teal slot with a mustard grabber area.
	var slot := StyleBoxFlat.new()
	slot.bg_color = Color("c9bd9f")
	slot.border_color = INK
	slot.set_border_width_all(2)
	slot.set_corner_radius_all(6)
	slot.content_margin_top = 5
	slot.content_margin_bottom = 5
	var area := slot.duplicate() as StyleBoxFlat
	area.bg_color = TEAL
	theme.set_stylebox("slider", "HSlider", slot)
	theme.set_stylebox("grabber_area", "HSlider", area)
	theme.set_stylebox("grabber_area_highlight", "HSlider", area)
	theme.set_icon("grabber", "HSlider", _grabber_icon(MUSTARD))
	theme.set_icon("grabber_highlight", "HSlider", _grabber_icon(ORANGE))

	theme.set_stylebox("panel", "PopupMenu", panel(PAPER, INK, 3, 6, 6))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", PAPER)
	theme.set_stylebox("hover", "PopupMenu", panel(ORANGE, ORANGE, 0, 4, 4))
	theme.set_stylebox("panel", "TooltipPanel", panel(Color("fff3c9"), INK, 2, 4, 8))
	theme.set_color("font_color", "TooltipLabel", INK)
	theme.set_font("font", "TooltipLabel", mono())
	theme.set_font_size("font_size", "TooltipLabel", 16)

	var grab := StyleBoxFlat.new()
	grab.bg_color = TEAL
	grab.set_corner_radius_all(4)
	theme.set_stylebox("grabber", "VScrollBar", grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grab)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("e2d6b8")
	track.set_corner_radius_all(4)
	track.content_margin_left = 6
	track.content_margin_right = 6
	theme.set_stylebox("scroll", "VScrollBar", track)
	return theme


## A heading label in the typewriter face.
static func heading(text: String, size: int = 24, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", typewriter())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## A strip header: teal band with cream typewriter text, like a console placard.
static func placard(text: String, size: int = 20) -> PanelContainer:
	var strip := PanelContainer.new()
	var box := panel(TEAL, INK, 3, 6, 6)
	box.content_margin_left = 12
	strip.add_theme_stylebox_override("panel", box)
	strip.add_child(heading(text, size, CREAM))
	return strip


static func body(text: String, size: int = 17, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _grabber_icon(color: Color) -> ImageTexture:
	var size := 26
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var c := Vector2(size / 2.0 - 0.5, size / 2.0 - 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if d <= size / 2.0 - 1.0:
				image.set_pixel(x, y, INK if d > size / 2.0 - 4.0 else color)
	return ImageTexture.create_from_image(image)


static func _load_font(base: String, system_names: Array, weight: int) -> Font:
	for ext in ["ttf", "otf"]:
		var path := "res://assets/ui/fonts/%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			var bundled := load(path) as Font
			if bundled != null:
				return bundled
	var font := SystemFont.new()
	font.font_names = PackedStringArray(system_names)
	font.font_weight = weight
	return font

## ThemeManager.gd — Selectable theme system with StyleBox helpers
## Autoload singleton: ThemeManager
extends Node

signal theme_changed(theme_name: String)

enum AppTheme { DARK_RPG, NEON_CYBERPUNK, CLEAN_GAME, MINIMAL_WARRIOR }

var themes: Dictionary = {
	"dark_rpg": {
		"name": "Dark RPG",
		"description": "Deep dark with gold accents — dungeon crawler vibes",
		"background": Color(0.051, 0.051, 0.102),    # 0D0D1A
		"surface": Color(0.102, 0.102, 0.180),        # 1A1A2E
		"surface_variant": Color(0.145, 0.145, 0.251), # 252540
		"primary_accent": Color(0.788, 0.635, 0.153),  # C9A227
		"primary_light": Color(0.910, 0.831, 0.545),   # E8D48B
		"text_primary": Color(0.902, 0.863, 0.784),    # E6DCC8
		"text_secondary": Color(0.620, 0.580, 0.518),  # 9E9484
		"success": Color(0.298, 0.686, 0.314),
		"warning": Color(1.0, 0.596, 0.0),
		"error": Color(0.812, 0.384, 0.475),
		"gold": Color(1.0, 0.843, 0.0),
		"fire": Color(1.0, 0.420, 0.263),
	},
	"neon_cyberpunk": {
		"name": "Neon Cyberpunk",
		"description": "Glowing cyan and hot pink — futuristic tech",
		"background": Color(0.039, 0.039, 0.039),     # 0A0A0A
		"surface": Color(0.078, 0.078, 0.157),         # 141428
		"surface_variant": Color(0.118, 0.118, 0.227), # 1E1E3A
		"primary_accent": Color(0.0, 0.941, 1.0),      # 00F0FF
		"primary_light": Color(0.4, 0.969, 1.0),       # 66F7FF
		"text_primary": Color(0.878, 0.878, 0.878),
		"text_secondary": Color(0.541, 0.541, 0.604),
		"success": Color(0.0, 1.0, 0.533),
		"warning": Color(1.0, 0.667, 0.0),
		"error": Color(1.0, 0.176, 0.333),
		"gold": Color(1.0, 0.843, 0.0),
		"fire": Color(1.0, 0.420, 0.263),
	},
	"clean_game": {
		"name": "Clean Game",
		"description": "Soft gradients and rounded corners — polished mobile game",
		"background": Color(0.071, 0.071, 0.094),      # 121218
		"surface": Color(0.118, 0.118, 0.180),         # 1E1E2E
		"surface_variant": Color(0.165, 0.165, 0.243), # 2A2A3E
		"primary_accent": Color(0.392, 0.404, 0.949),  # 6467F2
		"primary_light": Color(0.545, 0.557, 1.0),     # 8B8EFF
		"text_primary": Color(0.902, 0.902, 0.902),
		"text_secondary": Color(0.620, 0.620, 0.620),
		"success": Color(0.298, 0.686, 0.314),
		"warning": Color(1.0, 0.596, 0.0),
		"error": Color(0.957, 0.263, 0.212),
		"gold": Color(1.0, 0.843, 0.0),
		"fire": Color(1.0, 0.420, 0.263),
	},
	"minimal_warrior": {
		"name": "Minimal Warrior",
		"description": "Bold contrast, fire accents — premium fitness",
		"background": Color(0.059, 0.059, 0.059),      # 0F0F0F
		"surface": Color(0.102, 0.102, 0.102),         # 1A1A1A
		"surface_variant": Color(0.145, 0.145, 0.145), # 252525
		"primary_accent": Color(0.392, 0.404, 0.949),  # 6467F2
		"primary_light": Color(0.545, 0.557, 1.0),
		"text_primary": Color(1.0, 1.0, 1.0),
		"text_secondary": Color(0.667, 0.667, 0.667),
		"success": Color(0.298, 0.686, 0.314),
		"warning": Color(1.0, 0.596, 0.0),
		"error": Color(0.957, 0.263, 0.212),
		"gold": Color(1.0, 0.843, 0.0),
		"fire": Color(1.0, 0.420, 0.263),
	}
}

var current_theme_key: String = "clean_game"
var current: Dictionary = {}

func _ready():
	apply_theme(Database.get_setting("theme", "clean_game"))

func apply_theme(theme_key: String):
	if theme_key in themes:
		current_theme_key = theme_key
		current = themes[theme_key]
		Database.set_setting("theme", theme_key)
		theme_changed.emit(theme_key)

func get_color(color_name: String, fallback: Color = Color.WHITE) -> Color:
	if color_name in current:
		return current[color_name]
	# Fallback to clean_game
	if color_name in themes["clean_game"]:
		return themes["clean_game"][color_name]
	return fallback

func get_theme_list() -> Array:
	var list = []
	for key in themes:
		list.append({"key": key, "name": themes[key]["name"], "description": themes[key]["description"]})
	return list


# ── StyleBox Factory Methods ───────────────────────────────────────

## Card style: 12px corner radius, 16px content margins, surface bg, surface_variant border
func make_card_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = StyleBoxFlat.new()
	style.bg_color = t["surface"]
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.border_color = t["surface_variant"]
	style.set_border_width_all(1)
	style.draw_center = true
	return style

## Button style: 8px corner radius, 12px h / 8px v padding, primary_accent bg, white text
func make_button_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = StyleBoxFlat.new()
	style.bg_color = t["primary_accent"]
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.draw_center = true
	return style

## Button hover: slightly lighter
func make_button_hover_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = make_button_style(theme_key)
	style.bg_color = t["primary_accent"].lerp(Color.WHITE, 0.15)
	return style

## Button pressed: slightly darker
func make_button_pressed_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = make_button_style(theme_key)
	style.bg_color = t["primary_accent"].lerp(Color.BLACK, 0.2)
	return style

## Button focus: accent border
func make_button_focus_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = make_button_style(theme_key)
	style.border_color = t["primary_light"]
	style.set_border_width_all(2)
	return style

## Input style: 8px corner radius, 12px padding, surface_variant bg, 1px border
func make_input_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = StyleBoxFlat.new()
	style.bg_color = t["surface_variant"]
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.border_color = t["surface_variant"]
	style.set_border_width_all(1)
	style.draw_center = true
	return style

## Input focus: primary_accent border
func make_input_focus_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = make_input_style(theme_key)
	style.border_color = t["primary_accent"]
	style.set_border_width_all(2)
	return style

## Progress bar background: 6px corner radius, surface_variant fill
func make_progress_bg_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = StyleBoxFlat.new()
	style.bg_color = t["surface_variant"]
	style.set_corner_radius_all(6)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	style.draw_center = true
	return style

## Progress bar fill: 6px corner radius, primary_accent fill
func make_progress_fill_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = StyleBoxFlat.new()
	style.bg_color = t["primary_accent"]
	style.set_corner_radius_all(6)
	style.draw_center = true
	return style

## Header style: no bg, just bottom border line
func make_header_style(theme_key: String = current_theme_key) -> StyleBoxFlat:
	var t = themes.get(theme_key, themes["clean_game"])
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	style.border_color = t["primary_accent"]
	style.border_width_bottom = 1
	style.border_width_top = 0
	style.border_width_left = 0
	style.border_width_right = 0
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 8
	return style


# ── Apply Methods ──────────────────────────────────────────────────

## Apply card styling to a Panel or PanelContainer node
func apply_card(node: Control):
	if node == null:
		return
	node.add_theme_stylebox_override("panel", make_card_style())

## Apply button styling with press/hover color shift and animation
func apply_button(node: Button):
	if node == null:
		return
	node.add_theme_stylebox_override("normal", make_button_style())
	node.add_theme_stylebox_override("hover", make_button_hover_style())
	node.add_theme_stylebox_override("pressed", make_button_pressed_style())
	node.add_theme_stylebox_override("focus", make_button_focus_style())
	node.add_theme_color_override("font_color", Color.WHITE)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.85))
	animate_button_press(node)

## Apply input styling to a LineEdit node
func apply_input(node: LineEdit):
	if node == null:
		return
	node.add_theme_stylebox_override("normal", make_input_style())
	node.add_theme_stylebox_override("focus", make_input_focus_style())
	node.add_theme_color_override("font_color", get_color("text_primary"))
	node.add_theme_color_override("font_placeholder_color", get_color("text_secondary"))

## Apply progress bar styling
func apply_progress(node: ProgressBar):
	if node == null:
		return
	node.add_theme_stylebox_override("background", make_progress_bg_style())
	node.add_theme_stylebox_override("fill", make_progress_fill_style())

## Apply gradient-like background to a ColorRect (slightly lighter at top)
func apply_gradient_bg(node: ColorRect):
	if node == null:
		return
	var bg_top = get_color("background").lerp(Color.WHITE, 0.04)
	node.color = bg_top

## Fix ScrollContainer for mobile-friendly behavior
func fix_scroll_container(scroll: ScrollContainer):
	if scroll == null:
		return
	scroll.scroll_deadzone = 8
	scroll.scroll_follow_focus = true
	# Hide vertical scrollbar
	var vbar = scroll.get_v_scrollbar()
	if vbar:
		vbar.modulate.a = 0.0

## Animate button press: brief white flash + scale to 0.95 then back to 1.0
func animate_button_press(button: Button):
	if button == null:
		return
	if not button.pressed.is_connected(_on_button_animate.bind(button)):
		button.pressed.connect(_on_button_animate.bind(button))

func _on_button_animate(button: Button):
	if not is_instance_valid(button):
		return
	# Visual haptic feedback: brief modulate flash
	var flash_tween = button.create_tween()
	flash_tween.tween_property(button, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.05)
	flash_tween.tween_property(button, "modulate", Color.WHITE, 0.1)
	
	# Scale animation
	var tween = button.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)


# ── Particle / Effect Helpers ──────────────────────────────────────

## Floating "+XP" popup label
func create_xp_popup(parent: Node, pos: Vector2, amount: int):
	if parent == null:
		return
	var label = Label.new()
	label.text = "+%d XP" % amount
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", get_color("gold"))
	label.position = pos
	label.z_index = 100
	parent.add_child(label)
	
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", pos.y - 100.0, 1.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

## Level-up particle burst: 20 small squares exploding outward from center
func create_level_up_effect(parent: Node):
	if parent == null:
		return
	var accent = get_color("primary_accent")
	var particles: Array[ColorRect] = []
	for i in range(10):
		var p = ColorRect.new()
		p.custom_minimum_size = Vector2(4, 4)
		p.size = Vector2(4, 4)
		p.color = accent
		p.position = Vector2(parent.size.x * 0.5, parent.size.y * 0.5)
		p.z_index = 100
		parent.add_child(p)
		particles.append(p)
	
	# Animate each particle to a random position
	var longest_tween: Tween = null
	for p in particles:
		var angle = randf() * TAU
		var dist = randf_range(80.0, 200.0)
		var target_pos = p.position + Vector2(cos(angle), sin(angle)) * dist
		var delay = randf() * 0.5
		
		var tween = p.create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.8).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.8)
		tween.chain().tween_callback(p.queue_free)
		longest_tween = tween

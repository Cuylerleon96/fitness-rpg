## ThemeManager.gd — Selectable theme system
## Autoload singleton: ThemeManager
extends Node

signal theme_changed(theme_name: String)

enum Theme { DARK_RPG, NEON_CYBERPUNK, CLEAN_GAME, MINIMAL_WARRIOR }

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

func get_color(color_name: String) -> Color:
	if color_name in current:
		return current[color_name]
	# Fallback to clean_game
	if color_name in themes["clean_game"]:
		return themes["clean_game"][color_name]
	return Color.WHITE

func get_theme_list() -> Array:
	var list = []
	for key in themes:
		list.append({"key": key, "name": themes[key]["name"], "description": themes[key]["description"]})
	return list

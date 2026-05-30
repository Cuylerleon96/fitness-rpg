extends Control

@onready var bg = $Background
@onready var power_label = $ScrollContainer/VBox/PowerLevel
@onready var radar = $ScrollContainer/VBox/RadarChart
@onready var str_bar = $ScrollContainer/VBox/StrengthBar
@onready var end_bar = $ScrollContainer/VBox/EnduranceBar
@onready var con_bar = $ScrollContainer/VBox/ConsistencyBar
@onready var ver_bar = $ScrollContainer/VBox/VersatilityBar
@onready var stats_label = $ScrollContainer/VBox/StatsLabel

var stats: Dictionary = {}
var anim_progress: float = 0.0

func _ready():
	bg.color = ThemeManager.get_color("background")
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	
	var sessions = Database.get_recent_sessions(50)
	stats = Gamification.calculate_player_stats(GameManager.profile, sessions)
	
	power_label.text = "POWER LEVEL: %d" % stats["power_level"]
	power_label.add_theme_font_size_override("font_size", 36)
	power_label.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	
	stats_label.text = "Workouts: %d | Streak: %d | Level: %d" % [
		GameManager.profile.get("total_workouts", 0),
		GameManager.profile.get("current_streak", 0),
		GameManager.get_level_from_xp(GameManager.profile.get("total_xp", 0))
	]
	stats_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	
	# Animate bars
	_animate_bars()

func _animate_bars():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(str_bar, "value", float(stats["strength"]), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
	tween.tween_property(end_bar, "value", float(stats["endurance"]), 1.0).set_delay(0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(con_bar, "value", float(stats["consistency"]), 1.0).set_delay(0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(ver_bar, "value", float(stats["versatility"]), 1.0).set_delay(0.3).set_ease(Tween.EASE_OUT)

func _draw():
	# Draw radar chart
	if stats.is_empty():
		return
	var center = radar.global_position + radar.size / 2
	var radius = 120.0
	var values = [stats["strength"], stats["endurance"], stats["consistency"], stats["versatility"]]
	var labels = ["STR", "END", "CON", "VER"]
	var accent = ThemeManager.get_color("primary_accent")
	
	# Draw axes
	for i in 4:
		var angle = -PI / 2 + i * PI / 2
		var end_pos = center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(center, end_pos, ThemeManager.get_color("surface_variant"), 2.0)
		# Draw axis labels
		var label_pos = center + Vector2(cos(angle), sin(angle)) * (radius + 20)
	
	# Draw filled polygon
	var points = PackedVector2Array()
	for i in 4:
		var angle = -PI / 2 + i * PI / 2
		var r = radius * values[i] / 100.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	
	# Fill
	draw_colored_polygon(points, accent * Color(1, 1, 1, 0.3))
	# Outline
	points.append(points[0])
	draw_polyline(points, accent, 3.0)

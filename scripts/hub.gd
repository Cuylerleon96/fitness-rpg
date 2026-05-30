extends Control

@onready var bg = $Background
@onready var level_num = $ScrollContainer/VBox/TopBar/LevelBadge/LevelNum
@onready var xp_bar = $ScrollContainer/VBox/TopBar/XPBar
@onready var rank_label = $ScrollContainer/VBox/TopBar/RankLabel
@onready var streak_num = $ScrollContainer/VBox/StreakCard/StreakHBox/StreakNum
@onready var boss_card = $ScrollContainer/VBox/BossCard
@onready var boss_title = $ScrollContainer/VBox/BossCard/BossHBox/BossInfo/BossTitle
@onready var title_label = $TitleLabel

func _ready():
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)
	GameManager.xp_gained.connect(_on_xp_gained)
	_refresh()
	
	# Button connections
	$ScrollContainer/VBox/NavButtons/WorkoutBtn.pressed.connect(_on_workout)
	$ScrollContainer/VBox/NavButtons/CharacterBtn.pressed.connect(_on_character)
	$ScrollContainer/VBox/NavButtons/RoutinesBtn.pressed.connect(_on_routines)
	$ScrollContainer/VBox/NavButtons/AchievementsBtn.pressed.connect(_on_achievements)
	$ScrollContainer/VBox/NavButtons/SettingsBtn.pressed.connect(_on_settings)
	$ScrollContainer/VBox/BossCard/BossHBox.pressed.connect(_on_boss)

func _apply_theme():
	bg.color = ThemeManager.get_color("background")
	title_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	level_num.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	rank_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	streak_num.add_theme_color_override("font_color", ThemeManager.get_color("fire"))
	$ScrollContainer/VBox/StreakCard/StreakHBox/FireIcon.add_theme_font_size_override("font_size", 36)
	$ScrollContainer/VBox/StreakCard/StreakHBox/StreakNum.add_theme_font_size_override("font_size", 36)

func _refresh():
	GameManager.refresh()
	var p = GameManager.profile
	var level = GameManager.get_level_from_xp(p.get("total_xp", 0))
	var rank = GameManager.get_rank_title(level)
	
	level_num.text = str(level)
	level_num.add_theme_font_size_override("font_size", 48)
	rank_label.text = rank
	rank_label.add_theme_font_size_override("font_size", 20)
	
	xp_bar.value = GameManager.get_xp_progress_fraction() * 100.0
	streak_num.text = str(p.get("current_streak", 0))
	
	# Boss availability
	if GameManager.is_boss_available():
		boss_card.visible = true
		boss_card.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(boss_card, "modulate:a", 1.0, 0.5)
	else:
		boss_card.visible = false

func _on_xp_gained(amount: int):
	_refresh()

func _on_workout():
	GameManager.go_to_scene("res://scenes/routine_list.tscn")

func _on_character():
	GameManager.go_to_scene("res://scenes/character_sheet.tscn")

func _on_routines():
	GameManager.go_to_scene("res://scenes/routine_list.tscn")

func _on_achievements():
	GameManager.go_to_scene("res://scenes/achievements.tscn")

func _on_settings():
	GameManager.go_to_scene("res://scenes/settings.tscn")

func _on_boss():
	var boss = Gamification.generate_boss(
		GameManager.profile.get("total_workouts", 0),
		GameManager.get_level_from_xp(GameManager.profile.get("total_xp", 0))
	)
	GameManager.go_to_scene("res://scenes/boss_battle.tscn")
	# Pass boss data via GameManager
	GameManager._pending_boss = boss

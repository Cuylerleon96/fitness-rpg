extends Control

@onready var bg = $Background
@onready var boss_icon = $VBox/BossIcon
@onready var boss_name_label = $VBox/BossName
@onready var difficulty_label = $VBox/DifficultyBadge
@onready var boss_desc = $VBox/BossDesc
@onready var hp_bar = $VBox/HPBar
@onready var hp_label = $VBox/HPLabel
@onready var exercises_label = $VBox/ExercisesLeft
@onready var attack_btn = $VBox/AttackBtn
@onready var victory_overlay = $VictoryOverlay
@onready var victory_text = $VictoryOverlay/VictoryText
@onready var xp_earned = $VictoryOverlay/XpEarned

var boss: Dictionary = {}
var exercises_done: int = 0
var is_defeated: bool = false

func _ready():
	bg.color = ThemeManager.get_color("background")
	$VBox/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	attack_btn.pressed.connect(_on_attack)
	
	# Get boss data
	boss = GameManager._pending_boss if " _pending_boss" in GameManager else {}
	if boss.is_empty():
		boss = Gamification.generate_boss(
			GameManager.profile.get("total_workouts", 0),
			GameManager.get_level_from_xp(GameManager.profile.get("total_xp", 0))
		)
	
	_display_boss()

func _display_boss():
	boss_icon.text = boss.get("icon", "🐉")
	boss_icon.add_theme_font_size_override("font_size", 80)
	boss_name_label.text = boss.get("name", "UNKNOWN").to_upper()
	boss_name_label.add_theme_font_size_override("font_size", 28)
	boss_name_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	
	var diff = boss.get("difficulty", "normal")
	difficulty_label.text = diff.to_upper()
	var diff_color = ThemeManager.get_color("text_secondary")
	if diff == "hard": diff_color = ThemeManager.get_color("warning")
	elif diff == "legendary": diff_color = ThemeManager.get_color("gold")
	difficulty_label.add_theme_color_override("font_color", diff_color)
	
	boss_desc.text = boss.get("description", "")
	boss_desc.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	
	hp_bar.max_value = boss.get("max_hp", 100)
	hp_bar.value = boss.get("current_hp", hp_bar.max_value)
	
	_update_display()

func _update_display():
	var max_hp = boss.get("max_hp", 100)
	var current_hp = boss.get("current_hp", max_hp)
	var exercise_count = boss.get("exercise_count", 5)
	
	hp_label.text = "HP: %d / %d" % [current_hp, max_hp]
	hp_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	exercises_label.text = "Exercises: %d / %d" % [exercises_done, exercise_count]
	exercises_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	
	# HP bar color
	var fraction = float(current_hp) / float(max_hp)
	if fraction > 0.5:
		hp_bar.modulate = ThemeManager.get_color("success")
	elif fraction > 0.25:
		hp_bar.modulate = ThemeManager.get_color("warning")
	else:
		hp_bar.modulate = ThemeManager.get_color("error")

func _on_attack():
	if is_defeated:
		return
	
	exercises_done += 1
	var max_hp = boss.get("max_hp", 100)
	var exercise_count = boss.get("exercise_count", 5)
	var hp_per_exercise = max_hp / exercise_count
	var new_hp = maxi(boss.get("current_hp", max_hp) - hp_per_exercise, 0)
	boss["current_hp"] = new_hp
	
	# Animate HP bar
	var tween = create_tween()
	tween.tween_property(hp_bar, "value", float(new_hp), 0.5).set_ease(Tween.EASE_OUT)
	
	_update_display()
	
	if exercises_done >= exercise_count or new_hp <= 0:
		_defeat_boss()

func _defeat_boss():
	is_defeated = true
	boss["current_hp"] = 0
	hp_bar.value = 0
	GameManager.defeat_boss(boss)
	
	# Show victory
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	victory_text.text = "VICTORY!"
	victory_text.add_theme_font_size_override("font_size", 48)
	victory_text.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	xp_earned.text = "+%d XP" % boss.get("xp_reward", 200)
	xp_earned.add_theme_font_size_override("font_size", 32)
	xp_earned.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	
	var tween = create_tween()
	tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.5)
	
	# Return to hub after 3 seconds
	await get_tree().create_timer(3.0).timeout
	GameManager.go_to_hub()

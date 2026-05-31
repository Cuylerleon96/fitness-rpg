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
	ThemeManager.apply_gradient_bg(bg)
	$VBox/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	attack_btn.pressed.connect(_on_attack)
	
	# Apply styles
	ThemeManager.apply_button($VBox/BackBtn)
	ThemeManager.apply_button(attack_btn)
	ThemeManager.apply_progress(hp_bar)
	
	# Get boss data
	boss = GameManager._pending_boss if GameManager._pending_boss.size() > 0 else {}
	if boss.is_empty():
		boss = Gamification.generate_boss(
			GameManager.profile.get("total_workouts", 0),
			GameManager.get_level_from_xp(GameManager.profile.get("total_xp", 0))
		)
	
	_display_boss()
	_play_boss_intro()

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

# ── Boss Intro Animation ──────────────────────────────────────────

func _play_boss_intro():
	# Boss icon starts at scale 0, bounces to 1.2 then settles to 1.0
	boss_icon.scale = Vector2.ZERO
	boss_icon.pivot_offset = boss_icon.size * 0.5
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(boss_icon, "scale", Vector2(1.2, 1.2), 0.6)
	tween.tween_property(boss_icon, "scale", Vector2(1.0, 1.0), 0.4)
	# Fade in name and details
	boss_name_label.modulate.a = 0.0
	difficulty_label.modulate.a = 0.0
	boss_desc.modulate.a = 0.0
	var tween2 = create_tween()
	tween2.tween_interval(0.3)
	tween2.tween_property(boss_name_label, "modulate:a", 1.0, 0.3)
	tween2.tween_property(difficulty_label, "modulate:a", 1.0, 0.2)
	tween2.tween_property(boss_desc, "modulate:a", 1.0, 0.2)

# ── Screen Shake ──────────────────────────────────────────────────

func _screen_shake():
	var original_pos = position
	var tween = create_tween()
	for i in range(4):
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		tween.tween_property(self, "position", original_pos + offset, 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

# ── Floating Damage Numbers ───────────────────────────────────────

func _spawn_damage_number(damage: int):
	var label = Label.new()
	label.text = "-%d" % damage
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", ThemeManager.get_color("error"))
	label.z_index = 200
	label.position = Vector2(hp_bar.global_position.x + hp_bar.size.x * 0.5 - 20, hp_bar.global_position.y - 10)
	add_child(label)
	
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

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
	
	# Screen shake on hit
	_screen_shake()
	# Floating damage number
	_spawn_damage_number(hp_per_exercise)
	
	# Animate HP bar
	var tween = create_tween()
	tween.tween_property(hp_bar, "value", float(new_hp), 0.5).set_ease(Tween.EASE_OUT)
	
	_update_display()
	
	if exercises_done >= exercise_count or new_hp <= 0:
		_defeat_boss()

# ── Victory ───────────────────────────────────────────────────────

func _spawn_victory_particles():
	for i in range(15):
		var p = ColorRect.new()
		p.custom_minimum_size = Vector2(6, 6)
		p.size = Vector2(6, 6)
		p.color = ThemeManager.get_color("gold") if i % 2 == 0 else ThemeManager.get_color("primary_accent")
		p.position = Vector2(size.x * 0.5, size.y * 0.5)
		p.z_index = 150
		add_child(p)
		
		var angle = randf() * TAU
		var dist = randf_range(100.0, 400.0)
		var target = p.position + Vector2(cos(angle), sin(angle)) * dist
		var delay = randf() * 0.3
		
		var tween = p.create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(p, "position", target, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(p, "modulate:a", 0.0, 1.0)
		tween.chain().tween_callback(p.queue_free)

func _defeat_boss():
	is_defeated = true
	boss["current_hp"] = 0
	hp_bar.value = 0
	GameManager.defeat_boss(boss)
	
	# Victory particles
	_spawn_victory_particles()
	
	# Show victory
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	victory_text.text = "VICTORY!"
	victory_text.add_theme_font_size_override("font_size", 48)
	victory_text.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	xp_earned.text = "+%d XP" % boss.get("xp_reward", 200)
	xp_earned.add_theme_font_size_override("font_size", 32)
	xp_earned.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	
	# Animate victory text with bounce
	victory_text.scale = Vector2(0.5, 0.5)
	victory_text.pivot_offset = victory_text.size * 0.5
	var tween = create_tween()
	tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(victory_text, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(victory_text, "scale", Vector2(1.0, 1.0), 0.2)
	
	# Return to hub after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		GameManager.go_to_hub()

extends Control

@onready var bg = $Background
@onready var level_num = $ScrollContainer/VBox/TopBar/LevelBadge/LevelNum
@onready var xp_bar = $ScrollContainer/VBox/TopBar/XPBar
@onready var rank_label = $ScrollContainer/VBox/TopBar/RankLabel
@onready var streak_num = $ScrollContainer/VBox/StreakCard/StreakHBox/StreakNum
@onready var boss_card = $ScrollContainer/VBox/BossCard
@onready var boss_title = $ScrollContainer/VBox/BossCard/BossHBox/BossInfo/BossTitle
@onready var title_label = $TitleLabel

# New cards for daily reward, quest, weekly challenge, latest achievement, calories
@onready var daily_reward_dialog = $DailyRewardDialog
@onready var quest_card = $ScrollContainer/VBox/QuestCard
@onready var quest_title = $ScrollContainer/VBox/QuestCard/QuestTitle
@onready var quest_flavor_label = $ScrollContainer/VBox/QuestCard/QuestFlavor
@onready var challenge_card = $ScrollContainer/VBox/ChallengeCard
@onready var challenge_title = $ScrollContainer/VBox/ChallengeCard/ChallengeTitle
@onready var challenge_progress_bar = $ScrollContainer/VBox/ChallengeCard/ChallengeProgressBar
@onready var achievement_card = $ScrollContainer/VBox/AchievementCard
@onready var achievement_title = $ScrollContainer/VBox/AchievementCard/AchievementTitle
@onready var calories_card = $ScrollContainer/VBox/CaloriesCard
@onready var calories_label = $ScrollContainer/VBox/CaloriesCard/CaloriesLabel

var _stored_level: int = 0
var _toast_queue: Array = []

func _ready():
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)
	GameManager.xp_gained.connect(_on_xp_gained)
	GameManager.level_up.connect(_on_level_up)
	GameManager.achievement_unlocked.connect(_on_achievement_unlocked)
	_refresh()
	
	# Fix scroll container for mobile
	ThemeManager.fix_scroll_container($ScrollContainer)
	
	# Button connections
	$ScrollContainer/VBox/NavButtons/WorkoutBtn.pressed.connect(_on_workout)
	$ScrollContainer/VBox/NavButtons/CalendarBtn.pressed.connect(_on_calendar)
	$ScrollContainer/VBox/NavButtons/ProgressBtn.pressed.connect(_on_progress)
	$ScrollContainer/VBox/NavButtons/ChatBtn.pressed.connect(_on_chat)
	$ScrollContainer/VBox/NavButtons/CharacterBtn.pressed.connect(_on_character)
	$ScrollContainer/VBox/NavButtons/RoutinesBtn.pressed.connect(_on_routines)
	$ScrollContainer/VBox/NavButtons/AchievementsBtn.pressed.connect(_on_achievements)
	$ScrollContainer/VBox/NavButtons/SettingsBtn.pressed.connect(_on_settings)
	# Boss card click — use gui_input on the Panel (HBoxContainer has no pressed signal)
	boss_card.gui_input.connect(_on_boss_input)
	
	# Daily reward dialog setup
	daily_reward_dialog.confirmed.connect(_on_daily_reward_claimed)
	
	# Check daily reward on load
	_check_daily_reward()
	# Store initial level for level-up detection
	_stored_level = GameManager.get_level_from_xp(GameManager.profile.get("total_xp", 0))

func _apply_theme():
	ThemeManager.apply_gradient_bg(bg)
	title_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	level_num.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	rank_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	streak_num.add_theme_color_override("font_color", ThemeManager.get_color("fire"))
	$ScrollContainer/VBox/StreakCard/StreakHBox/FireIcon.add_theme_font_size_override("font_size", 36)
	$ScrollContainer/VBox/StreakCard/StreakHBox/StreakNum.add_theme_font_size_override("font_size", 36)
	
	# Apply card styles
	ThemeManager.apply_card(streak_card)
	ThemeManager.apply_card(boss_card)
	ThemeManager.apply_card(quest_card)
	ThemeManager.apply_card(challenge_card)
	ThemeManager.apply_card(achievement_card)
	ThemeManager.apply_card(calories_card)
	
	# Apply progress bar style
	ThemeManager.apply_progress(xp_bar)
	ThemeManager.apply_progress(challenge_progress_bar)
	
	# Apply button styles
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/WorkoutBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/CalendarBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/ProgressBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/ChatBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/CharacterBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/RoutinesBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/AchievementsBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavButtons/SettingsBtn)

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
	
	# Quest card
	var quest = Gamification.get_current_quest()
	if quest.get("quest_name", "") != "":
		quest_card.visible = true
		quest_title.text = "⚔️ Quest: %s" % quest["quest_name"]
		quest_flavor_label.text = quest.get("quest_flavor", "")
		if quest.get("quest_completed", false):
			quest_title.text = "✅ Quest Complete: %s" % quest["quest_name"]
	else:
		quest_card.visible = false
	
	# Weekly challenge card
	var challenges = Database.get_weekly_challenges()
	if challenges.size() > 0:
		var active_challenge = null
		for c in challenges:
			if not c.get("is_completed", false):
				active_challenge = c
				break
		if active_challenge == null:
			active_challenge = challenges[0]
		challenge_card.visible = true
		challenge_title.text = "🎯 %s" % active_challenge.get("name", active_challenge.get("description", ""))
		var target = active_challenge.get("target", 1)
		var progress = active_challenge.get("progress", 0)
		challenge_progress_bar.max_value = target
		challenge_progress_bar.value = progress
	else:
		challenge_card.visible = false
	
	# Latest achievement card
	var achievements = Database.get_achievements()
	var latest_ach = null
	for a in achievements:
		if a.get("is_unlocked", false):
			if latest_ach == null or a.get("unlocked_at", 0) > latest_ach.get("unlocked_at", 0):
				latest_ach = a
	if latest_ach != null:
		achievement_card.visible = true
		achievement_title.text = "🏅 %s - %s" % [latest_ach.get("icon", ""), latest_ach.get("name", "")]
	else:
		achievement_card.visible = false
	
	# Calories burned today
	var calories_today = _get_calories_burned_today()
	if calories_today > 0:
		calories_card.visible = true
		calories_label.text = "🔥 %d kcal burned today" % calories_today
	else:
		calories_card.visible = false

func _get_calories_burned_today() -> int:
	var today_start = _get_today_start_timestamp()
	var sessions = Database.get_recent_sessions(50)
	var total_calories = 0
	for session in sessions:
		if session.get("date", 0) >= today_start:
			total_calories += session.get("calories_burned", 0)
	return total_calories

func _get_today_start_timestamp() -> int:
	var now = Time.get_unix_time_from_system()
	var dt = Time.get_datetime_dict_from_unix_time(now)
	var seconds_today = dt.get("hour", 0) * 3600 + dt.get("minute", 0) * 60 + dt.get("second", 0)
	return int(now - seconds_today)

func _check_daily_reward():
	var now = Time.get_unix_time_from_system()
	var last_claim = Database.get_setting("last_daily_claim", 0)
	var today_day = int(now / 86400)
	var last_day = int(last_claim / 86400)
	
	if today_day > last_day:
		# Show daily reward dialog
		var streak = Database.get_setting("daily_claim_streak", 0)
		var next_day = streak + 1
		var rewards = [10, 15, 20, 25, 30, 40, 50]
		var xp = rewards[(next_day - 1) % 7]
		daily_reward_dialog.title_text = "Daily Reward"
		daily_reward_dialog.dialog_text = "Day %d streak! Claim %d XP today!" % [next_day, xp]
		daily_reward_dialog.popup_centered()

func _on_daily_reward_claimed():
	var xp = Database.claim_daily_reward()
	if xp > 0:
		GameManager.add_xp(xp)
		_refresh()

func _on_xp_gained(amount: int):
	_refresh()
	# Show XP popup on level badge
	ThemeManager.create_xp_popup(self, level_num.global_position, amount)

func _on_level_up(new_level: int, rank: String):
	_stored_level = new_level
	_show_level_up_celebration(new_level)

func _show_level_up_celebration(new_level: int):
	# Fullscreen overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 500
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Particle burst
	ThemeManager.create_level_up_effect(overlay)
	
	# "LEVEL UP!" text
	var title = Label.new()
	title.text = "LEVEL UP!"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.position = Vector2(size.x * 0.5 - 150, size.y * 0.35)
	title.z_index = 501
	overlay.add_child(title)
	
	# Level number with bounce
	var lvl_label = Label.new()
	lvl_label.text = str(new_level)
	lvl_label.add_theme_font_size_override("font_size", 72)
	lvl_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_label.set_anchors_preset(Control.PRESET_CENTER)
	lvl_label.position = Vector2(size.x * 0.5 - 40, size.y * 0.5)
	lvl_label.z_index = 501
	overlay.add_child(lvl_label)
	
	# Animate: fade in overlay, bounce level number
	overlay.modulate.a = 0.0
	lvl_label.scale = Vector2(0.1, 0.1)
	lvl_label.pivot_offset = lvl_label.size * 0.5
	
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(lvl_label, "scale", Vector2(1.2, 1.2), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(lvl_label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(overlay.queue_free)

# ── Achievement Toast ─────────────────────────────────────────────

func _on_achievement_unlocked(achievement: Dictionary):
	_show_achievement_toast(achievement)

func _show_achievement_toast(achievement: Dictionary):
	# Toast panel at top
	var toast = PanelContainer.new()
	toast.z_index = 400
	toast.custom_minimum_size = Vector2(size.x - 40, 60)
	toast.position = Vector2(20, -70)
	toast.size = Vector2(size.x - 40, 60)
	
	# Style the toast
	var style = StyleBoxFlat.new()
	style.bg_color = ThemeManager.get_color("surface").lerp(ThemeManager.get_color("gold"), 0.15)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.border_color = ThemeManager.get_color("gold")
	style.set_border_width_all(1)
	toast.add_theme_stylebox_override("panel", style)
	add_child(toast)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	toast.add_child(hbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = achievement.get("icon", "🏅")
	icon_label.add_theme_font_size_override("font_size", 28)
	hbox.add_child(icon_label)
	
	# Text
	var text_label = Label.new()
	text_label.text = "%s Unlocked!" % achievement.get("name", "Achievement")
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_label)
	
	# Animate: slide down, wait, slide up
	var tween = create_tween()
	tween.tween_property(toast, "position:y", 20.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(3.0)
	tween.tween_property(toast, "position:y", -70.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(toast.queue_free)

func _on_workout():
	GameManager.go_to_scene("res://scenes/routine_list.tscn")

func _on_calendar():
	GameManager.go_to_calendar()

func _on_progress():
	GameManager.go_to_progress()

func _on_chat():
	GameManager.go_to_chat()

func _on_character():
	GameManager.go_to_scene("res://scenes/character_sheet.tscn")

func _on_routines():
	GameManager.go_to_scene("res://scenes/routine_list.tscn")

func _on_achievements():
	GameManager.go_to_scene("res://scenes/achievements.tscn")

func _on_settings():
	GameManager.go_to_scene("res://scenes/settings.tscn")

func _on_boss_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_boss()

func _on_boss():
	var boss = Gamification.generate_boss(
		GameManager.profile.get("total_workouts", 0),
		GameManager.get_level_from_xp(GameManager.profile.get("total_xp", 0))
	)
	GameManager.go_to_scene("res://scenes/boss_battle.tscn")
	# Pass boss data via GameManager
	GameManager._pending_boss = boss

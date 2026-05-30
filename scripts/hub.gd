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

func _ready():
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)
	GameManager.xp_gained.connect(_on_xp_gained)
	_refresh()
	
	# Button connections
	$ScrollContainer/VBox/NavButtons/WorkoutBtn.pressed.connect(_on_workout)
	$ScrollContainer/VBox/NavButtons/CalendarBtn.pressed.connect(_on_calendar)
	$ScrollContainer/VBox/NavButtons/ProgressBtn.pressed.connect(_on_progress)
	$ScrollContainer/VBox/NavButtons/ChatBtn.pressed.connect(_on_chat)
	$ScrollContainer/VBox/NavButtons/CharacterBtn.pressed.connect(_on_character)
	$ScrollContainer/VBox/NavButtons/RoutinesBtn.pressed.connect(_on_routines)
	$ScrollContainer/VBox/NavButtons/AchievementsBtn.pressed.connect(_on_achievements)
	$ScrollContainer/VBox/NavButtons/SettingsBtn.pressed.connect(_on_settings)
	$ScrollContainer/VBox/BossCard/BossHBox.pressed.connect(_on_boss)
	
	# Daily reward dialog setup
	daily_reward_dialog.confirmed.connect(_on_daily_reward_claimed)
	
	# Check daily reward on load
	_check_daily_reward()

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

func _on_boss():
	var boss = Gamification.generate_boss(
		GameManager.profile.get("total_workouts", 0),
		GameManager.get_level_from_xp(GameManager.profile.get("total_xp", 0))
	)
	GameManager.go_to_scene("res://scenes/boss_battle.tscn")
	# Pass boss data via GameManager
	GameManager._pending_boss = boss

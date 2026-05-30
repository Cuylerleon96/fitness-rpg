extends Control

@onready var bg = $Background
@onready var vbox = $ScrollContainer/VBox

func _ready():
	bg.color = ThemeManager.get_color("background")
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	$ScrollContainer/VBox/AchievementsBtn.pressed.connect(func(): GameManager.go_to_scene("res://scenes/achievements.tscn"))
	_refresh()

func _refresh():
	# Clear dynamic children (keep static headers and the achievements button)
	for child in vbox.get_children():
		if child.name not in ["StatsHeader", "AchievementsBtn", "XPHeader", "WeeklyHeader"]:
			child.queue_free()

	GameManager.refresh()
	var profile = GameManager.profile
	var sessions = Database.get_recent_sessions(500)
	var total_xp = profile.get("total_xp", 0)
	var level = GameManager.get_level_from_xp(total_xp)
	var rank = GameManager.get_rank_title(level)
	var xp_progress = GameManager.get_xp_progress_fraction()

	# ── Stats Section ──
	var stats_card = _make_card()
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 8)

	# Current streak / longest streak / total workouts row
	var streak_row = _make_stat_row("🔥 Current Streak", "%d days" % profile.get("current_streak", 0))
	var longest_row = _make_stat_row("⭐ Longest Streak", "%d days" % profile.get("longest_streak", 0))
	var total_row = _make_stat_row("💪 Total Workouts", str(profile.get("total_workouts", 0)))
	var rank_row = _make_stat_row("🏅 Rank", "%s (Lv.%d)" % [rank, level])

	stats_vbox.add_child(streak_row)
	stats_vbox.add_child(longest_row)
	stats_vbox.add_child(total_row)
	stats_vbox.add_child(rank_row)
	stats_card.add_child(stats_vbox)
	vbox.add_child(stats_card)

	# ── XP Progress Section ──
	var xp_card = _make_card()
	var xp_vbox = VBoxContainer.new()
	xp_vbox.add_theme_constant_override("separation", 8)

	var xp_label = Label.new()
	xp_label.text = "Level %d — %s" % [level, rank]
	xp_label.add_theme_font_size_override("font_size", 20)
	xp_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	xp_vbox.add_child(xp_label)

	var xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 24)
	xp_bar.value = xp_progress * 100.0
	xp_bar.show_percentage = false
	xp_vbox.add_child(xp_bar)

	var xp_text = Label.new()
	var xp_for_next = GameManager.get_xp_for_next_level(total_xp, level)
	xp_text.text = "Total XP: %d  |  %d XP to next level" % [total_xp, xp_for_next]
	xp_text.add_theme_font_size_override("font_size", 14)
	xp_text.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	xp_vbox.add_child(xp_text)

	xp_card.add_child(xp_vbox)
	vbox.add_child(xp_card)

	# ── Weekly Stats Section ──
	var weekly_card = _make_card()
	var weekly_vbox = VBoxContainer.new()
	weekly_vbox.add_theme_constant_override("separation", 8)

	var today_epoch = int(Time.get_unix_time_from_system() / 86400)
	var week_start = today_epoch - 6  # last 7 days

	var weekly_workouts = 0
	var weekly_volume = 0.0
	var weekly_calories = 0

	for s in sessions:
		var day = s.get("date", 0)
		if day >= week_start and day <= today_epoch:
			weekly_workouts += 1
			weekly_volume += s.get("total_volume", 0.0)
			weekly_calories += s.get("calories_burned", 0)

	var week_workout_row = _make_stat_row("🏋️ Workouts (7 days)", str(weekly_workouts))
	var week_volume_row = _make_stat_row("📦 Volume (7 days)", "%.0f kg" % weekly_volume)
	var week_cal_row = _make_stat_row("🔥 Calories (7 days)", "%d kcal" % weekly_calories)

	weekly_vbox.add_child(week_workout_row)
	weekly_vbox.add_child(week_volume_row)
	weekly_vbox.add_child(week_cal_row)
	weekly_card.add_child(weekly_vbox)
	vbox.add_child(weekly_card)

	# ── Bar Chart: Last 7 days ──
	var chart_card = _make_card()
	var chart_vbox = VBoxContainer.new()
	chart_vbox.add_theme_constant_override("separation", 4)

	var chart_title = Label.new()
	chart_title.text = "Last 7 Days"
	chart_title.add_theme_font_size_override("font_size", 18)
	chart_title.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	chart_vbox.add_child(chart_title)

	var day_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	var max_volume = 0.0
	var day_volumes: Array = []

	for i in range(7):
		var epoch = week_start + i
		var vol = 0.0
		for s in sessions:
			if s.get("date", 0) == epoch:
				vol += s.get("total_volume", 0.0)
		day_volumes.append(vol)
		if vol > max_volume:
			max_volume = vol

	for i in range(7):
		var epoch = week_start + i
		var dt = Time.get_datetime_dict_from_unix_time(epoch * 86400)
		var day_name = day_names[dt.weekday]
		var vol = day_volumes[i]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label = Label.new()
		label.text = day_name
		label.custom_minimum_size = Vector2(50, 0)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		row.add_child(label)

		var bar_bg = ColorRect.new()
		bar_bg.custom_minimum_size = Vector2(0, 20)
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.color = ThemeManager.get_color("surface_variant")
		row.add_child(bar_bg)

		if vol > 0 and max_volume > 0:
			var bar = ColorRect.new()
			var fraction = vol / max_volume
			bar.custom_minimum_size = Vector2(0, 20)
			bar.color = ThemeManager.get_color("primary_accent")
			bar.size_flags_horizontal = 0
			# We use a timer to set width after layout
			bar.name = "Bar_%d" % i
			bar_bg.add_child(bar)

		chart_vbox.add_child(row)

	chart_card.add_child(chart_vbox)
	vbox.add_child(chart_card)

func _make_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 0)
	return card

func _make_stat_row(icon_text: String, value_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label = Label.new()
	label.text = icon_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	row.add_child(value)

	return row

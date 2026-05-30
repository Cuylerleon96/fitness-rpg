extends Control

@onready var bg = $Background
@onready var month_label = $ScrollContainer/VBox/NavRow/MonthLabel
@onready var grid = $ScrollContainer/VBox/CalendarGrid
@onready var detail_panel = $ScrollContainer/VBox/DetailPanel
@onready var detail_label = $ScrollContainer/VBox/DetailPanel/DetailLabel

var current_year: int = 0
var current_month: int = 0  # 1-12
var workout_days: Dictionary = {}  # epoch_day -> session data

func _ready():
	bg.color = ThemeManager.get_color("background")
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	$ScrollContainer/VBox/NavRow/PrevBtn.pressed.connect(_on_prev_month)
	$ScrollContainer/VBox/NavRow/NextBtn.pressed.connect(_on_next_month)
	$ScrollContainer/VBox/WeekDaysRow.visible = true
	detail_panel.visible = false

	var now = Time.get_datetime_dict_from_system()
	current_year = now.year
	current_month = now.month
	_load_workout_days()
	_render_month()

func _load_workout_days():
	workout_days.clear()
	var sessions = Database.get_recent_sessions(500)
	for s in sessions:
		var day = s.get("date", 0)
		if day > 0:
			workout_days[day] = s

func _on_prev_month():
	current_month -= 1
	if current_month < 1:
		current_month = 12
		current_year -= 1
	_render_month()

func _on_next_month():
	current_month += 1
	if current_month > 12:
		current_month = 1
		current_year += 1
	_render_month()

func _render_month():
	month_label.text = "%s %d" % [_month_name(current_month), current_year]
	month_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	month_label.add_theme_font_size_override("font_size", 22)
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Clear old day buttons
	for child in grid.get_children():
		child.queue_free()

	# Calculate first day of month and number of days
	var first_day = _day_of_week(current_year, current_month, 1)
	var days_in_month = _days_in_month(current_year, current_month)
	var today_epoch = int(Time.get_unix_time_from_system() / 86400)

	# Add empty spacers for days before the 1st
	for i in range(first_day):
		var spacer = ColorRect.new()
		spacer.custom_minimum_size = Vector2(0, 50)
		spacer.color = Color(0, 0, 0, 0)
		grid.add_child(spacer)

	# Add day buttons
	for day in range(1, days_in_month + 1):
		var epoch_day = _date_to_epoch_day(current_year, current_month, day)
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = str(day)

		if epoch_day in workout_days:
			# Completed workout day - green
			btn.add_theme_color_override("font_color", ThemeManager.get_color("success"))
			btn.add_theme_color_override("font_color_hover", ThemeManager.get_color("success"))
			btn.tooltip_text = "Workout completed"
		elif epoch_day == today_epoch:
			# Today - accent color
			btn.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
			btn.tooltip_text = "Today"
		elif epoch_day < today_epoch:
			# Past day with no workout - dim
			btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary") * Color(1, 1, 1, 0.5))
			btn.tooltip_text = "No workout"
		else:
			# Future day
			btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

		var d = day
		btn.pressed.connect(func(): _on_day_pressed(d))
		grid.add_child(btn)

func _on_day_pressed(day: int):
	var epoch_day = _date_to_epoch_day(current_year, current_month, day)
	var today_epoch = int(Time.get_unix_time_from_system() / 86400)

	if epoch_day in workout_days:
		var session = workout_days[epoch_day]
		var routine_name = session.get("routine_name", "Workout")
		var volume = session.get("total_volume", 0.0)
		var logs = session.get("exercise_logs", [])
		var ex_count = 0
		if logs is Array:
			ex_count = logs.size()
		elif logs is String:
			var parsed = JSON.parse_string(logs)
			ex_count = parsed.size() if parsed else 0
		detail_label.text = "%s\nExercises: %d\nTotal Volume: %.0f kg" % [routine_name, ex_count, volume]
		detail_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
		detail_panel.visible = true
	elif epoch_day <= today_epoch:
		detail_label.text = "No workout on %s %d\nTap a routine to schedule one!" % [_month_name(current_month), day]
		detail_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		detail_panel.visible = true
	else:
		detail_panel.visible = false

func _month_name(m: int) -> String:
	var names = ["January", "February", "March", "April", "May", "June",
				 "July", "August", "September", "October", "November", "December"]
	return names[m - 1]

func _days_in_month(year: int, month: int) -> int:
	var days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month == 2 and (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)):
		return 29
	return days[month - 1]

func _day_of_week(year: int, month: int, day: int) -> int:
	# Zeller's congruence - returns 0=Sun, 1=Mon, ..., 6=Sat
	var m = month
	var y = year
	if m < 3:
		m += 12
		y -= 1
	var k = y % 100
	var j = y / 100
	var h = (day + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 - 2 * j) % 7
	return (h + 6) % 7  # Convert so 0=Sunday

func _date_to_epoch_day(year: int, month: int, day: int) -> int:
	var dt = Time.get_unix_time_from_datetime_string("%04d-%02d-%02dT00:00:00" % [year, month, day])
	return int(dt / 86400)

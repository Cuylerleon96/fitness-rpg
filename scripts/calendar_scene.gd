extends Control

@onready var bg = $Background
@onready var month_label = $ScrollContainer/VBox/NavRow/MonthLabel
@onready var grid = $ScrollContainer/VBox/CalendarGrid
@onready var detail_panel = $ScrollContainer/VBox/DetailPanel
@onready var detail_label = $ScrollContainer/VBox/DetailPanel/DetailLabel
@onready var schedule_dialog = $ScheduleDialog
@onready var action_dialog = $ActionDialog
@onready var upcoming_list = $ScrollContainer/VBox/UpcomingSection/UpcomingList

@onready var routine_list = $ScheduleDialog/RoutineList

var current_year: int = 0
var current_month: int = 0  # 1-12
var workout_days: Dictionary = {}  # epoch_day -> session data
var scheduled_workouts: Dictionary = {}  # date_string -> routine_id
var pending_date_string: String = ""
var pending_epoch_day: int = 0

func _ready():
	ThemeManager.apply_gradient_bg(bg)
	ThemeManager.fix_scroll_container($ScrollContainer)
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	ThemeManager.apply_button($TopBar/BackBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavRow/PrevBtn)
	ThemeManager.apply_button($ScrollContainer/VBox/NavRow/NextBtn)
	$ScrollContainer/VBox/NavRow/PrevBtn.pressed.connect(_on_prev_month)
	$ScrollContainer/VBox/NavRow/NextBtn.pressed.connect(_on_next_month)
	$ScrollContainer/VBox/WeekDaysRow.visible = true
	detail_panel.visible = false

	# Apply card style to detail panel
	ThemeManager.apply_card(detail_panel)

	var now = Time.get_datetime_dict_from_system()
	current_year = now.year
	current_month = now.month
	_load_workout_days()
	_load_scheduled_workouts()
	schedule_dialog.confirmed.connect(_on_schedule_dialog_confirmed)
	action_dialog.custom_action.connect(_on_action_dialog_custom_action)
	_render_month()
	_render_upcoming()

func _load_workout_days():
	workout_days.clear()
	var sessions = Database.get_recent_sessions(100)
	for s in sessions:
		var day = s.get("date", 0)
		if day > 0:
			workout_days[day] = s

func _load_scheduled_workouts():
	scheduled_workouts = Database.get_setting("scheduled_workouts", {})

func _save_scheduled_workouts():
	Database.set_setting("scheduled_workouts", scheduled_workouts)

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
	month_label.add_theme_font_size_override("font_size", 24)
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
		var date_str = "%04d-%02d-%02d" % [current_year, current_month, day]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)

		if epoch_day in workout_days:
			# Completed workout day - green
			btn.text = str(day)
			btn.add_theme_color_override("font_color", ThemeManager.get_color("success"))
			btn.add_theme_color_override("font_color_hover", ThemeManager.get_color("success"))
			btn.tooltip_text = "Workout completed"
		elif epoch_day == today_epoch:
			# Today - highlight
			btn.text = str(day)
			btn.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
			btn.tooltip_text = "Today"
			if date_str in scheduled_workouts:
				var routine_name = _get_routine_name(scheduled_workouts[date_str])
				btn.text = "·%d" % day
				btn.tooltip_text = "Today - Scheduled: %s" % routine_name
		elif date_str in scheduled_workouts:
			# Scheduled future day - accent colored dot
			var routine_name = _get_routine_name(scheduled_workouts[date_str])
			btn.text = "·%d" % day
			btn.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
			btn.add_theme_color_override("font_color_hover", ThemeManager.get_color("primary_accent"))
			btn.tooltip_text = "Scheduled: %s" % routine_name
		elif epoch_day < today_epoch:
			# Past day with no workout - dim
			btn.text = str(day)
			btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary") * Color(1, 1, 1, 0.5))
			btn.tooltip_text = "No workout"
		else:
			# Future day, unscheduled
			btn.text = str(day)
			btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

		var d = day
		btn.pressed.connect(func(): _on_day_pressed(d))
		ThemeManager.apply_button(btn)
		grid.add_child(btn)

func _on_day_pressed(day: int):
	var epoch_day = _date_to_epoch_day(current_year, current_month, day)
	var today_epoch = int(Time.get_unix_time_from_system() / 86400)
	var date_str = "%04d-%02d-%02d" % [current_year, current_month, day]

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
	elif epoch_day > today_epoch:
		# Future day - show action dialog (schedule or start/unschedule if already scheduled)
		pending_date_string = date_str
		pending_epoch_day = epoch_day
		if date_str in scheduled_workouts:
			_show_action_dialog(date_str)
		else:
			_show_schedule_dialog(date_str)
	elif epoch_day == today_epoch:
		# Today - if scheduled, show action dialog; else show schedule dialog
		pending_date_string = date_str
		pending_epoch_day = epoch_day
		if date_str in scheduled_workouts:
			_show_action_dialog(date_str)
		else:
			_show_schedule_dialog(date_str)
	else:
		detail_label.text = "No workout on %s %d" % [_month_name(current_month), day]
		detail_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		detail_panel.visible = true

func _show_schedule_dialog(date_str: String):
	schedule_dialog.title = "Schedule Workout for %s" % date_str
	routine_list.clear()
	var routines = Database._data.get("routines", {})
	if routines.is_empty():
		routine_list.add_item("No routines available")
		schedule_dialog.visible = true
		return
	for routine_id in routines:
		var routine = routines[routine_id]
		var r_name = routine.get("name", "Routine")
		routine_list.add_item(r_name)
		routine_list.set_item_metadata(routine_list.item_count - 1, routine_id)
	schedule_dialog.visible = true

func _on_schedule_dialog_confirmed():
	if routine_list.get_selected_items().is_empty():
		return
	var idx = routine_list.get_selected_items()[0]
	var routine_id = routine_list.get_item_metadata(idx)
	if routine_id == null:
		return
	scheduled_workouts[pending_date_string] = routine_id
	_save_scheduled_workouts()
	_render_month()
	_render_upcoming()
	detail_label.text = "Scheduled %s for %s" % [_get_routine_name(routine_id), pending_date_string]
	detail_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	detail_panel.visible = true

func _show_action_dialog(date_str: String):
	var routine_id = scheduled_workouts[date_str]
	var routine_name = _get_routine_name(routine_id)
	action_dialog.title = "%s - %s" % [date_str, routine_name]
	# Clear existing custom buttons to prevent accumulation
	action_dialog.remove_action("start_workout")
	action_dialog.remove_action("unschedule")
	action_dialog.ok_button_text = "Cancel"
	action_dialog.add_button("Start Workout", true, "start_workout")
	action_dialog.add_button("Unschedule", false, "unschedule")
	action_dialog.dialog_text = "What would you like to do?"
	action_dialog.visible = true

func _on_action_dialog_custom_action(action: String):
	action_dialog.remove_action("start_workout")
	action_dialog.remove_action("unschedule")
	if action == "start_workout":
		var routine_id = scheduled_workouts.get(pending_date_string, "")
		if routine_id != "":
			GameManager.go_to_workout(routine_id)
	elif action == "unschedule":
		scheduled_workouts.erase(pending_date_string)
		_save_scheduled_workouts()
		_render_month()
		_render_upcoming()
		detail_label.text = "Unscheduled workout for %s" % pending_date_string
		detail_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		detail_panel.visible = true


func _get_routine_name(routine_id) -> String:
	var routines = Database._data.get("routines", {})
	if routine_id in routines:
		return routines[routine_id].get("name", "Unknown")
	return "Unknown"

func _render_upcoming():
	for child in upcoming_list.get_children():
		child.queue_free()

	var today_str = "%04d-%02d-%02d" % [
		Time.get_datetime_dict_from_system().year,
		Time.get_datetime_dict_from_system().month,
		Time.get_datetime_dict_from_system().day
	]

	# Get all scheduled dates >= today, sorted
	var upcoming_dates: Array = []
	for date_str in scheduled_workouts:
		if date_str >= today_str:
			upcoming_dates.append(date_str)
	upcoming_dates.sort()

	# Show next 5
	var count = mini(upcoming_dates.size(), 5)
	if count == 0:
		var empty_label = Label.new()
		empty_label.text = "No upcoming workouts scheduled."
		empty_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		upcoming_list.add_child(empty_label)
		return

	for i in range(count):
		var date_str = upcoming_dates[i]
		var routine_id = scheduled_workouts[date_str]
		var routine_name = _get_routine_name(routine_id)
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 48)
		ThemeManager.apply_card(card)
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		var date_label = Label.new()
		date_label.text = date_str
		date_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
		var sep = Label.new()
		sep.text = "-"
		sep.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		var name_label = Label.new()
		name_label.text = routine_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
		hbox.add_child(date_label)
		hbox.add_child(sep)
		hbox.add_child(name_label)
		card.add_child(hbox)
		upcoming_list.add_child(card)

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
	var m = month
	var y = year
	if m < 3:
		m += 12
		y -= 1
	var k = y % 100
	var j = y / 100
	var h = (day + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 - 2 * j) % 7
	return (h + 6) % 7  # 0=Sunday

func _date_to_epoch_day(year: int, month: int, day: int) -> int:
	var dt = Time.get_unix_time_from_datetime_string("%04d-%02d-%02dT00:00:00" % [year, month, day])
	return int(dt / 86400)

extends Control

@onready var bg = $Background
@onready var routine_name_label = $TopBar/RoutineName
@onready var timer_label = $TopBar/TimerLabel
@onready var progress_dots = $ProgressDots
@onready var ex_label = $ExerciseCard/ExerciseVBox/ExLabel
@onready var ex_name = $ExerciseCard/ExerciseVBox/ExName
@onready var muscle_badge = $ExerciseCard/ExerciseVBox/MuscleGroupBadge
@onready var target_label = $ExerciseCard/ExerciseVBox/TargetLabel
@onready var notes_label = $ExerciseCard/ExerciseVBox/NotesLabel
@onready var sets_container = $SetsContainer
@onready var prev_btn = $NavButtons/PrevBtn
@onready var next_btn = $NavButtons/NextBtn
@onready var finish_btn = $TopBar/FinishBtn
@onready var rest_overlay = $RestOverlay
@onready var rest_time_label = $RestOverlay/RestVBox/RestTime
@onready var rest_bg = $RestOverlay/RestBg
@onready var timer_circle = $RestOverlay/RestVBox/TimerCircle
@onready var next_exercise_label = $RestOverlay/RestVBox/NextExerciseLabel
@onready var skip_btn = $RestOverlay/RestVBox/SkipBtn
@onready var duration_input = $DurationInput
@onready var pr_badge = $PRBadge
@onready var finish_confirm_dialog = $FinishConfirmDialog
@onready var finish_summary = $FinishSummary
@onready var total_time_label = $FinishSummary/SummaryVBox/TotalTimeLabel
@onready var total_sets_label = $FinishSummary/SummaryVBox/TotalSetsLabel
@onready var total_volume_label = $FinishSummary/SummaryVBox/TotalVolumeLabel
@onready var xp_earned_label = $FinishSummary/SummaryVBox/XPEarnedLabel
@onready var boss_available_label = $FinishSummary/SummaryVBox/BossAvailableLabel
@onready var continue_button = $FinishSummary/SummaryVBox/ContinueButton

# Muscle group colors
const MUSCLE_COLORS := {
	"chest": Color(0.9, 0.2, 0.2),       # red
	"back": Color(0.2, 0.4, 0.9),        # blue
	"legs": Color(0.2, 0.8, 0.3),        # green
	"shoulders": Color(0.85, 0.75, 0.1), # gold
	"arms": Color(0.6, 0.2, 0.8),        # purple
	"core": Color(1.0, 0.5, 0.1),        # orange
}

var routine: Dictionary = {}
var exercises: Array = []
var current_exercise_index: int = 0
var set_logs: Array = []  # Array of Arrays of set data
var exercise_logs: Array = []
var elapsed_seconds: int = 0
var workout_start_time: int = 0
var is_resting: bool = false
var rest_remaining: int = 0
var rest_total: int = 0
var _timer_accumulator: float = 0.0
var _rest_accumulator: float = 0.0
var personal_bests: Dictionary = {}
var total_xp_earned: int = 0
var _last_session: Dictionary = {}

func _ready():
	ThemeManager.apply_gradient_bg(bg)
	
	var routine_id = GameManager.get_pending_routine_id()
	if routine_id.is_empty():
		# Try first available routine
		var routines = Database.get_routines()
		if routines.size() > 0:
			routine_id = routines[0]["id"]
	
	routine = Database.get_routine(routine_id)
	exercises = JSON.parse_string(routine.get("exercises", "[]")) if routine else []
	routine_name_label.text = routine.get("name", "Workout")
	routine_name_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	workout_start_time = int(Time.get_unix_time_from_system())
	
	# Load personal bests for PR detection
	personal_bests = Database.get_personal_bests()
	
	# Initialize set logs
	for ex in exercises:
		var ex_sets = []
		for i in range(ex.get("sets", 3)):
			ex_sets.append({"weight": 0.0, "reps": 0, "duration": 0, "completed": false})
		set_logs.append(ex_sets)
	
	# Hide overlays by default
	duration_input.visible = false
	pr_badge.visible = false
	finish_summary.visible = false
	
	# Apply styles to buttons
	ThemeManager.apply_button(prev_btn)
	ThemeManager.apply_button(next_btn)
	ThemeManager.apply_button(finish_btn)
	ThemeManager.apply_button(skip_btn)
	ThemeManager.apply_button(continue_button)
	
	prev_btn.pressed.connect(_on_prev)
	next_btn.pressed.connect(_on_next)
	finish_btn.pressed.connect(_on_finish_pressed)
	skip_btn.pressed.connect(_on_skip_rest)
	finish_confirm_dialog.confirmed.connect(_on_finish_confirmed)
	continue_button.pressed.connect(_on_continue_from_summary)
	
	_display_exercise()
	_build_progress_dots()

func _process(delta: float):
	if is_resting:
		_process_rest(delta)
	else:
		_timer_accumulator += delta
		if _timer_accumulator >= 1.0:
			_timer_accumulator -= 1.0
			elapsed_seconds += 1
			timer_label.text = _format_time(elapsed_seconds)

func _build_progress_dots():
	for child in progress_dots.get_children():
		child.queue_free()
	for i in range(exercises.size()):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.color = ThemeManager.get_color("surface_variant") if i != current_exercise_index else ThemeManager.get_color("primary_accent")
		progress_dots.add_child(dot)

func _is_duration_exercise(ex: Dictionary) -> bool:
	var ex_type = ex.get("exerciseType", "strength").to_lower()
	return ex_type in ["cardio", "duration", "stretch"]

func _get_muscle_group_color(muscle_group: String) -> Color:
	var mg = muscle_group.to_lower()
	for key in MUSCLE_COLORS:
		if mg.contains(key):
			return MUSCLE_COLORS[key]
	return ThemeManager.get_color("text_secondary")

func _display_exercise():
	if current_exercise_index >= exercises.size():
		return
	var ex = exercises[current_exercise_index]
	ex_label.text = "Exercise %d of %d" % [current_exercise_index + 1, exercises.size()]
	ex_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	ex_name.text = ex.get("name", "")
	ex_name.add_theme_font_size_override("font_size", 24)
	ex_name.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	
	# Muscle group badge
	var muscle_group = ex.get("muscleGroup", "")
	if muscle_group != "":
		muscle_badge.text = muscle_group
		muscle_badge.visible = true
		muscle_badge.add_theme_color_override("font_color", _get_muscle_group_color(muscle_group))
	else:
		muscle_badge.visible = false
	
	# Exercise notes
	var notes = ex.get("notes", "")
	if notes != "":
		notes_label.text = notes
		notes_label.visible = true
		notes_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	else:
		notes_label.visible = false
	
	# Target label - differ for duration vs strength
	var ex_type = ex.get("exerciseType", "strength").to_lower()
	if _is_duration_exercise(ex):
		var target_dur = ex.get("targetDuration", 0)
		if target_dur > 0:
			target_label.text = "🎯 Target: %d:%02d" % [target_dur / 60, target_dur % 60]
			target_label.visible = true
		else:
			target_label.visible = false
	else:
		var tw = ex.get("targetWeight", 0.0)
		var tr = ex.get("targetReps", 0)
		if tw > 0 or tr > 0:
			target_label.text = "🎯 Target: %.1fkg × %d reps" % [tw, tr]
			target_label.visible = true
		else:
			target_label.visible = false
	target_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	
	prev_btn.disabled = current_exercise_index <= 0
	next_btn.text = "Next →" if current_exercise_index < exercises.size() - 1 else "✓ Done"
	
	_build_set_rows()
	_build_progress_dots()

func _build_set_rows():
	for child in sets_container.get_children():
		child.queue_free()
	
	if current_exercise_index >= set_logs.size():
		return
	
	var ex = exercises[current_exercise_index]
	var sets = set_logs[current_exercise_index]
	var is_duration = _is_duration_exercise(ex)
	
	for i in range(sets.size()):
		var set_data = sets[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		# Set number circle
		var set_num = Label.new()
		set_num.text = str(i + 1) if not set_data["completed"] else "✓"
		set_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		set_num.custom_minimum_size = Vector2(40, 40)
		set_num.add_theme_color_override("font_color", ThemeManager.get_color("success") if set_data["completed"] else ThemeManager.get_color("text_primary"))
		row.add_child(set_num)
		
		if not set_data["completed"]:
			if is_duration:
				# Duration input (minutes:seconds)
				var dur_input = LineEdit.new()
				dur_input.custom_minimum_size = Vector2(140, 45)
				dur_input.placeholder_text = "mm:ss"
				dur_input.name = "duration_%d" % i
				ThemeManager.apply_input(dur_input)
				row.add_child(dur_input)
			else:
				# Weight input (only for strength)
				if ex.get("exerciseType", "strength") == "strength":
					var weight_input = LineEdit.new()
					weight_input.custom_minimum_size = Vector2(100, 45)
					weight_input.placeholder_text = "%.0f kg" % ex.get("targetWeight", 0.0)
					weight_input.name = "weight_%d" % i
					ThemeManager.apply_input(weight_input)
					row.add_child(weight_input)
				
				# Reps input
				var reps_input = LineEdit.new()
				reps_input.custom_minimum_size = Vector2(80, 45)
				reps_input.placeholder_text = "reps"
				reps_input.name = "reps_%d" % i
				ThemeManager.apply_input(reps_input)
				row.add_child(reps_input)
			
			# Complete button
			var complete_btn = Button.new()
			complete_btn.text = "✓"
			complete_btn.custom_minimum_size = Vector2(50, 45)
			ThemeManager.apply_button(complete_btn)
			var idx = i
			complete_btn.pressed.connect(func(): _complete_set(idx))
			row.add_child(complete_btn)
		else:
			var done_label = Label.new()
			if is_duration:
				var mins = int(set_data["duration"]) / 60
				var secs = int(set_data["duration"]) % 60
				done_label.text = "%d:%02d" % [mins, secs]
			else:
				done_label.text = "%.1fkg × %d" % [set_data["weight"], set_data["reps"]]
			done_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
			row.add_child(done_label)
			
			# Check if PR (strength exercises only)
			if not is_duration:
				var ex_name_str = ex.get("name", "")
				var current_weight = set_data["weight"]
				var best_weight = personal_bests.get(ex_name_str, 0.0)
				if current_weight > best_weight and current_weight > 0:
					var pr_label = Label.new()
					pr_label.text = "🏆 PR!"
					pr_label.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
					row.add_child(pr_label)
				elif current_weight >= ex.get("targetWeight", 0.0) and ex.get("targetWeight", 0.0) > 0:
					var hit = Label.new()
					hit.text = "✓ HIT"
					hit.add_theme_color_override("font_color", ThemeManager.get_color("success"))
					row.add_child(hit)
		
		sets_container.add_child(row)

func _complete_set(set_index: int):
	if current_exercise_index >= set_logs.size() or set_index >= set_logs[current_exercise_index].size():
		return
	
	var rows = sets_container.get_children()
	if set_index >= rows.size():
		return
	var row = rows[set_index]
	
	var ex = exercises[current_exercise_index]
	var is_duration = _is_duration_exercise(ex)
	var weight = 0.0
	var reps = 0
	var duration = 0
	
	for child in row.get_children():
		if child is LineEdit:
			if child.name.begins_with("weight"):
				weight = child.text.to_float()
			elif child.name.begins_with("reps"):
				reps = child.text.to_int()
			elif child.name.begins_with("duration"):
				# Parse mm:ss format
				duration = _parse_duration_input(child.text)
	
	set_logs[current_exercise_index][set_index] = {
		"weight": weight, "reps": reps, "duration": duration, "completed": true
	}
	
	# Show PR badge if this is a new personal record (strength only)
	if not is_duration:
		var ex_name_str = ex.get("name", "")
		var best_weight = personal_bests.get(ex_name_str, 0.0)
		if weight > best_weight and weight > 0:
			_show_pr_badge()
	
	_build_set_rows()
	
	# Check if all sets done -> trigger rest
	var all_done = true
	for s in set_logs[current_exercise_index]:
		if not s["completed"]:
			all_done = false
			break
	
	if all_done:
		var rest = exercises[current_exercise_index].get("restSeconds", 60)
		_start_rest(rest)

func _parse_duration_input(text: String) -> int:
	# Parse "mm:ss" or just seconds
	if ":" in text:
		var parts = text.split(":")
		if parts.size() >= 2:
			return parts[0].to_int() * 60 + parts[1].to_int()
		elif parts.size() == 1:
			return parts[0].to_int()
	return text.to_int()

func _show_pr_badge():
	pr_badge.visible = true
	pr_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
	pr_badge.add_theme_font_size_override("font_size", 32)
	# Auto-hide after 2 seconds
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(pr_badge, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		pr_badge.visible = false
		pr_badge.modulate.a = 1.0
	)

func _start_rest(seconds: int):
	is_resting = true
	rest_total = seconds
	rest_remaining = seconds
	rest_overlay.visible = true
	rest_bg.color = ThemeManager.get_color("background") * Color(1, 1, 1, 0.9)
	rest_time_label.add_theme_font_size_override("font_size", 48)
	rest_time_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	# Show next exercise name
	if current_exercise_index + 1 < exercises.size():
		var next_ex = exercises[current_exercise_index + 1]
		next_exercise_label.text = "Next: %s" % next_ex.get("name", "")
		next_exercise_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		next_exercise_label.visible = true
	else:
		next_exercise_label.text = "Final exercise done!"
		next_exercise_label.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
		next_exercise_label.visible = true
	# Connect draw signal for circle rendering
	if not timer_circle.draw.is_connected(_draw_timer_circle):
		timer_circle.draw.connect(_draw_timer_circle)
	_update_rest_display()

func _draw_timer_circle():
	var center = timer_circle.size * 0.5
	var radius = min(timer_circle.size.x, timer_circle.size.y) * 0.45
	var fraction = float(rest_remaining) / float(rest_total) if rest_total > 0 else 0.0
	# Color: green -> yellow -> red
	var arc_color: Color
	if fraction > 0.5:
		arc_color = Color(0.2, 0.85, 0.3).lerp(Color(1.0, 0.85, 0.0), 1.0 - (fraction - 0.5) * 2.0)
	else:
		arc_color = Color(1.0, 0.85, 0.0).lerp(Color(0.95, 0.2, 0.2), 1.0 - fraction * 2.0)
	# Background circle (dim)
	timer_circle.draw_arc(center, radius, 0, TAU, 64, ThemeManager.get_color("surface_variant"), 8.0)
	# Active arc
	if fraction > 0.001:
		var arc_length = TAU * fraction
		timer_circle.draw_arc(center, radius, PI * 0.5, PI * 0.5 + arc_length, 64, arc_color, 10.0)
	# "GO!" text when timer hits 0
	if rest_remaining <= 0:
		var font = ThemeDB.fallback_font
		timer_circle.draw_string(font, center - Vector2(24, -8), "GO!", HORIZONTAL_ALIGNMENT_CENTER, -1, 36, Color(0.2, 0.9, 0.3))

func _process_rest(delta: float):
	_rest_accumulator += delta
	if _rest_accumulator >= 1.0:
		_rest_accumulator -= 1.0
		rest_remaining -= 1
		_update_rest_display()
		if rest_remaining <= 0:
			_on_skip_rest()

func _update_rest_display():
	rest_time_label.text = "0:%02d" % rest_remaining
	timer_circle.queue_redraw()

func _on_skip_rest():
	is_resting = false
	rest_overlay.visible = false

func _on_prev():
	if current_exercise_index > 0:
		current_exercise_index -= 1
		_display_exercise()

func _on_next():
	if current_exercise_index < exercises.size() - 1:
		current_exercise_index += 1
		_display_exercise()
	else:
		_on_finish_pressed()

# ── Finish Confirmation ──────────────────────────────────────────

func _on_finish_pressed():
	# Calculate totals for the confirmation dialog
	var total_sets = 0
	var total_volume = 0.0
	for i in range(exercises.size()):
		for s in set_logs[i]:
			if s["completed"]:
				total_sets += 1
				total_volume += s["weight"] * s["reps"]
	
	var end_time = int(Time.get_unix_time_from_system())
	var duration_min = max((end_time - workout_start_time) / 60, 1)
	
	finish_confirm_dialog.title_text = "Finish Workout?"
	finish_confirm_dialog.dialog_text = "Time: %s\nSets completed: %d\nVolume: %.0f kg" % [
		_format_time(elapsed_seconds), total_sets, total_volume
	]
	finish_confirm_dialog.popup_centered()

# ── Finish Summary ───────────────────────────────────────────────

func _on_finish_confirmed():
	_save_and_show_summary()

func _save_and_show_summary():
	# Build exercise logs for saving
	var logs = []
	for i in range(exercises.size()):
		var ex = exercises[i]
		var sets = set_logs[i]
		var set_log_data = []
		for s in sets:
			set_log_data.append({
				"set_number": sets.find(s) + 1,
				"weight_kg": s["weight"],
				"reps": s["reps"],
				"duration_seconds": s["duration"],
				"is_completed": s["completed"]
			})
		logs.append({
			"exercise_id": ex.get("id", ""),
			"exercise_name": ex.get("name", ""),
			"muscle_group": ex.get("muscleGroup", ""),
			"exercise_type": ex.get("exerciseType", "strength"),
			"set_logs": set_log_data
		})
	
	var total_volume = 0.0
	var total_sets = 0
	for log in logs:
		for s in log["set_logs"]:
			total_volume += s["weight_kg"] * s["reps"]
			if s["is_completed"]:
				total_sets += 1
	
	var end_time = int(Time.get_unix_time_from_system())
	var duration_min = max((end_time - workout_start_time) / 60, 1)
	
	var session = {
		"id": str(randi()),
		"routine_id": routine.get("id", ""),
		"routine_name": routine.get("name", ""),
		"start_time": workout_start_time,
		"end_time": end_time,
		"date": int(Time.get_unix_time_from_system() / 86400),
		"exercise_logs": logs,
		"total_volume": total_volume,
		"calories_burned": 0,
		"notes": ""
	}
	Database.insert_session(session)
	_last_session = session
	
	# Mark calendar day as completed
	var today_day = int(Time.get_unix_time_from_system() / 86400)
	var completed_days = Database.get_setting("completed_workout_days", [])
	if completed_days is String:
		completed_days = JSON.parse_string(completed_days) if completed_days else []
	if not today_day in completed_days:
		completed_days.append(today_day)
	Database.set_setting("completed_workout_days", completed_days)
	
	# Call Gamification.process_workout_completion
	var gam_result = Gamification.process_workout_completion(session)
	
	# Award XP via GameManager
	var exercise_types = []
	for log in logs:
		if log["exercise_type"] not in exercise_types:
			exercise_types.append(log["exercise_type"])
	GameManager.award_workout_xp(total_sets, total_volume, duration_min, exercise_types)
	total_xp_earned = gam_result.get("xp_gained", 0)
	
	# Check boss battle availability
	var total_workouts = Database.get_gamification_profile().get("total_workouts", 0)
	var boss_available = total_workouts > 0 and total_workouts % 10 == 0
	
	# Show finish summary overlay
	_show_finish_summary(total_sets, total_volume, total_xp_earned, boss_available, gam_result)

func _show_finish_summary(total_sets: int, total_volume: float, xp: int, boss_available: bool, gam_result: Dictionary):
	finish_summary.visible = true
	
	total_time_label.text = "⏱ Total Time: %s" % _format_time(elapsed_seconds)
	total_time_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	
	total_sets_label.text = "💪 Sets Completed: %d" % total_sets
	total_sets_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	
	total_volume_label.text = "🏋️ Total Volume: %.0f kg" % total_volume
	total_volume_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	
	xp_earned_label.text = "⭐ XP Earned: %d" % xp
	xp_earned_label.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	
	if boss_available:
		boss_available_label.text = "🐉 BOSS BATTLE AVAILABLE! Every 10th workout triggers a boss fight!"
		boss_available_label.visible = true
		boss_available_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		boss_available_label.visible = false
	
	# Streak milestone
	var milestone = gam_result.get("streak_milestone", "")
	if milestone != "":
		# Append milestone info
		boss_available_label.text += "\n%s" % milestone
		boss_available_label.visible = true

func _on_continue_from_summary():
	finish_summary.visible = false
	GameManager.workout_completed.emit(_last_session)
	GameManager.go_to_hub()

# ── Utilities ────────────────────────────────────────────────────

func _format_time(seconds: int) -> String:
	var m = seconds / 60
	var s = seconds % 60
	return "%02d:%02d" % [m, s]

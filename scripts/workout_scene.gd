extends Control

@onready var bg = $Background
@onready var routine_name_label = $TopBar/RoutineName
@onready var timer_label = $TopBar/TimerLabel
@onready var progress_dots = $ProgressDots
@onready var ex_label = $ExerciseCard/ExerciseVBox/ExLabel
@onready var ex_name = $ExerciseCard/ExerciseVBox/ExName
@onready var target_label = $ExerciseCard/ExerciseVBox/TargetLabel
@onready var sets_container = $SetsContainer
@onready var prev_btn = $NavButtons/PrevBtn
@onready var next_btn = $NavButtons/NextBtn
@onready var finish_btn = $TopBar/FinishBtn
@onready var rest_overlay = $RestOverlay
@onready var rest_time_label = $RestOverlay/RestVBox/RestTime
@onready var rest_bg = $RestOverlay/RestBg
@onready var timer_circle = $RestOverlay/RestVBox/TimerCircle
@onready var skip_btn = $RestOverlay/RestVBox/SkipBtn

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

func _ready():
	bg.color = ThemeManager.get_color("background")
	
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
	
	# Initialize set logs
	for ex in exercises:
		var ex_sets = []
		for i in range(ex.get("sets", 3)):
			ex_sets.append({"weight": 0.0, "reps": 0, "duration": 0, "completed": false})
		set_logs.append(ex_sets)
	
	prev_btn.pressed.connect(_on_prev)
	next_btn.pressed.connect(_on_next)
	finish_btn.pressed.connect(_on_finish)
	skip_btn.pressed.connect(_on_skip_rest)
	
	_display_exercise()
	_build_progress_dots()

func _process(delta: float):
	if not is_resting:
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

func _display_exercise():
	if current_exercise_index >= exercises.size():
		return
	var ex = exercises[current_exercise_index]
	ex_label.text = "Exercise %d of %d" % [current_exercise_index + 1, exercises.size()]
	ex_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	ex_name.text = ex.get("name", "")
	ex_name.add_theme_font_size_override("font_size", 24)
	ex_name.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	
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
			# Weight input
			if ex.get("exerciseType", "strength") == "strength":
				var weight_input = LineEdit.new()
				weight_input.custom_minimum_size = Vector2(100, 45)
				weight_input.placeholder_text = "%.0f kg" % ex.get("targetWeight", 0.0)
				weight_input.name = "weight_%d" % i
				row.add_child(weight_input)
			
			# Reps input
			var reps_input = LineEdit.new()
			reps_input.custom_minimum_size = Vector2(80, 45)
			reps_input.placeholder_text = "reps"
			reps_input.name = "reps_%d" % i
			row.add_child(reps_input)
			
			# Complete button
			var complete_btn = Button.new()
			complete_btn.text = "✓"
			complete_btn.custom_minimum_size = Vector2(50, 45)
			var idx = i
			complete_btn.pressed.connect(func(): _complete_set(idx))
			row.add_child(complete_btn)
		else:
			var done_label = Label.new()
			done_label.text = "%.1fkg × %d" % [set_data["weight"], set_data["reps"]]
			done_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
			row.add_child(done_label)
			
			# Check if PR
			var target_w = ex.get("targetWeight", 0.0)
			if set_data["weight"] >= target_w and target_w > 0:
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
	
	var weight = 0.0
	var reps = 0
	
	for child in row.get_children():
		if child is LineEdit:
			if child.name.begins_with("weight"):
				weight = child.text.to_float()
			elif child.name.begins_with("reps"):
				reps = child.text.to_int()
	
	set_logs[current_exercise_index][set_index] = {
		"weight": weight, "reps": reps, "duration": 0, "completed": true
	}
	
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

func _start_rest(seconds: int):
	is_resting = true
	rest_total = seconds
	rest_remaining = seconds
	rest_overlay.visible = true
	rest_bg.color = ThemeManager.get_color("background") * Color(1, 1, 1, 0.9)
	rest_time_label.add_theme_font_size_override("font_size", 48)
	rest_time_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	_update_rest_display()

func _process_rest(delta: float):
	if not is_resting:
		return
	_timer_accumulator += delta
	if _timer_accumulator >= 1.0:
		_timer_accumulator -= 1.0
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
		_on_finish()

func _on_finish():
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
	for log in logs:
		for s in log["set_logs"]:
			total_volume += s["weight_kg"] * s["reps"]
	
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
	
	# Award XP
	var exercise_types = []
	for log in logs:
		if log["exercise_type"] not in exercise_types:
			exercise_types.append(log["exercise_type"])
	var sets_completed = 0
	for log in logs:
		for s in log["set_logs"]:
			if s["is_completed"]:
				sets_completed += 1
	
	GameManager.award_workout_xp(sets_completed, total_volume, duration_min, exercise_types)
	GameManager.workout_completed.emit(session)
	GameManager.go_to_hub()

func _format_time(seconds: int) -> String:
	var m = seconds / 60
	var s = seconds % 60
	return "%02d:%02d" % [m, s]

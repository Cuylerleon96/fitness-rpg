extends Control

@onready var bg = $Background
@onready var vbox = $ScrollContainer/VBox
@onready var routine_title = $ScrollContainer/VBox/RoutineTitle
@onready var desc_label = $ScrollContainer/VBox/DescLabel
@onready var meta_label = $ScrollContainer/VBox/MetaLabel
@onready var exercise_list = $ScrollContainer/VBox/ExerciseList
@onready var start_btn = $StartBtn
@onready var edit_btn = $ScrollContainer/VBox/EditBtn

var routine: Dictionary = {}

func _ready():
	ThemeManager.apply_gradient_bg(bg)
	ThemeManager.fix_scroll_container($ScrollContainer)
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_scene("res://scenes/routine_list.tscn"))
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	ThemeManager.apply_button($TopBar/BackBtn)
	ThemeManager.apply_button(start_btn)
	ThemeManager.apply_button(edit_btn)
	start_btn.pressed.connect(_on_start_workout)
	edit_btn.pressed.connect(_on_edit)

	var routine_id = GameManager.get_pending_routine_detail_id()
	if routine_id.is_empty():
		# Fallback: try the generic pending id or first routine
		routine_id = GameManager.get_pending_routine_id()
	if routine_id.is_empty():
		var routines = Database.get_routines()
		if routines.size() > 0:
			routine_id = routines[0]["id"]

	routine = Database.get_routine(routine_id)
	if routine.is_empty():
		routine_title.text = "Routine not found"
		return

	routine_title.text = routine.get("name", "Untitled Routine")
	routine_title.add_theme_font_size_override("font_size", 24)
	routine_title.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))

	desc_label.text = routine.get("description", "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

	var ex_data = routine.get("exercises", "[]")
	var exercises = ex_data if ex_data is Array else JSON.parse_string(ex_data)
	if exercises == null:
		exercises = []

	meta_label.text = "%d exercises  |  ~%d min  |  %s" % [
		exercises.size(),
		routine.get("estimatedDuration", 45),
		routine.get("difficulty", "normal").capitalize()
	]
	meta_label.add_theme_font_size_override("font_size", 14)
	meta_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

	_populate_exercises(exercises)

func _populate_exercises(exercises: Array):
	for child in exercise_list.get_children():
		child.queue_free()

	for i in range(exercises.size()):
		var ex = exercises[i]
		var card = PanelContainer.new()
		ThemeManager.apply_card(card)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		# Number badge
		var num_label = Label.new()
		num_label.text = str(i + 1)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_label.custom_minimum_size = Vector2(36, 36)
		num_label.add_theme_font_size_override("font_size", 18)
		num_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
		hbox.add_child(num_label)

		# Exercise info
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)

		var name_label = Label.new()
		name_label.text = ex.get("name", "Exercise")
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
		info.add_child(name_label)

		# Sets x Reps
		var sets_val = ex.get("sets", 3)
		var reps_val = ex.get("reps", "10")
		var rest_val = ex.get("restSeconds", 60)
		var detail_text = "%d sets × %s reps  |  %ds rest" % [sets_val, reps_val, rest_val]

		var detail_label = Label.new()
		detail_label.text = detail_text
		detail_label.add_theme_font_size_override("font_size", 13)
		detail_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		info.add_child(detail_label)

		# Target weight if available
		var tw = ex.get("targetWeight", 0.0)
		if tw > 0:
			var target_label = Label.new()
			target_label.text = "🎯 Target: %.1f kg" % tw
			target_label.add_theme_font_size_override("font_size", 13)
			target_label.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
			info.add_child(target_label)

		# Notes
		var notes = ex.get("notes", "")
		if notes != "":
			var notes_label = Label.new()
			notes_label.text = "📝 " + notes
			notes_label.add_theme_font_size_override("font_size", 12)
			notes_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
			notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			info.add_child(notes_label)

		# Muscle group tag
		var mg = ex.get("muscleGroup", "")
		if mg != "":
			var tag = Label.new()
			tag.text = mg
			tag.add_theme_font_size_override("font_size", 11)
			tag.add_theme_color_override("font_color", ThemeManager.get_color("primary_light"))
			info.add_child(tag)

		hbox.add_child(info)
		card.add_child(hbox)
		exercise_list.add_child(card)

func _on_start_workout():
	if routine.is_empty():
		return
	GameManager.go_to_workout(routine.get("id", ""))

func _on_edit():
	# Placeholder - show info dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Edit Routine"
	dialog.dialog_text = "Routine editing coming soon!"
	add_child(dialog)
	dialog.popup_centered()

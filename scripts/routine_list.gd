extends Control

@onready var bg = $Background
@onready var vbox = $ScrollContainer/VBox
@onready var generate_btn = $GenerateBtn

func _ready():
	ThemeManager.apply_gradient_bg(bg)
	ThemeManager.fix_scroll_container($ScrollContainer)
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	ThemeManager.apply_button($TopBar/BackBtn)
	ThemeManager.apply_button(generate_btn)
	generate_btn.pressed.connect(_on_generate)
	AIClient.workout_plan_generated.connect(_on_plan_generated)
	AIClient.ai_error.connect(_on_ai_error)
	_refresh()

func _refresh():
	for child in vbox.get_children():
		child.queue_free()
	
	var routines = Database.get_routines()
	if routines.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No routines yet. Generate one with AI!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		vbox.add_child(empty_label)
		return
	
	for r in routines:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 100)
		ThemeManager.apply_card(card)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_label = Label.new()
		name_label.text = r.get("name", "Workout")
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
		
		var desc = Label.new()
		desc.text = r.get("description", "").substr(0, 80)
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		var exercises = JSON.parse_string(r.get("exercises", "[]"))
		var ex_count = exercises.size() if exercises else 0
		var meta = Label.new()
		meta.text = "%d exercises | %s" % [ex_count, r.get("difficulty", "")]
		meta.add_theme_font_size_override("font_size", 16)
		meta.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary") * Color(1, 1, 1, 0.6))
		
		info.add_child(name_label)
		info.add_child(desc)
		info.add_child(meta)
		
		var start_btn = Button.new()
		start_btn.text = "START"
		start_btn.custom_minimum_size = Vector2(80, 60)
		ThemeManager.apply_button(start_btn)
		start_btn.pressed.connect(func(): _start_routine(r["id"]))
		
		var view_btn = Button.new()
		view_btn.text = "VIEW"
		view_btn.custom_minimum_size = Vector2(70, 60)
		ThemeManager.apply_button(view_btn)
		view_btn.pressed.connect(func(): GameManager.go_to_routine_detail(r["id"]))
		
		hbox.add_child(info)
		hbox.add_child(view_btn)
		hbox.add_child(start_btn)
		card.add_child(hbox)
		vbox.add_child(card)

func _on_generate():
	generate_btn.disabled = true
	generate_btn.text = "Generating..."
	AIClient.generate_workout_plan()

func _on_plan_generated(routines: Array):
	generate_btn.disabled = false
	generate_btn.text = "🤖 GENERATE AI WORKOUT"
	_refresh()

func _on_ai_error(message: String):
	generate_btn.disabled = false
	generate_btn.text = "🤖 GENERATE AI WORKOUT"
	# Show error
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()

func _start_routine(routine_id: String):
	GameManager.go_to_workout(routine_id)

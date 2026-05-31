extends Control

@onready var bg = $Background
@onready var theme_list = $ScrollContainer/VBox/ThemeList
@onready var unit_toggle = $ScrollContainer/VBox/UnitToggle
@onready var edit_profile_btn = $ScrollContainer/VBox/EditProfileBtn
@onready var reminder_toggle = $ScrollContainer/VBox/ReminderToggle
@onready var reminder_time_label = $ScrollContainer/VBox/ReminderTimeLabel
@onready var reset_btn = $ScrollContainer/VBox/ResetBtn
@onready var version_label = $ScrollContainer/VBox/VersionLabel
@onready var confirm_dialog = $ConfirmDialog

func _ready():
	ThemeManager.apply_gradient_bg(bg)
	ThemeManager.fix_scroll_container($ScrollContainer)
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	_apply_section_colors()
	_apply_styles()
	_populate_themes()

	# Set up imperial/metric toggle
	unit_toggle.add_item("Metric (kg/cm)")
	unit_toggle.add_item("Imperial (lbs/inches)")
	var stats = Database.get_user_stats()
	if stats.get("use_imperial", false):
		unit_toggle.selected = 1
	unit_toggle.item_selected.connect(_on_unit_changed)

	# Edit Profile button
	edit_profile_btn.pressed.connect(func(): GameManager.go_to_scene("res://scenes/profile_setup.tscn"))

	# Reminder toggle — load saved preference
	var reminders_on = Database.get_setting("workout_reminders", false)
	reminder_toggle.button_pressed = reminders_on
	reminder_toggle.toggled.connect(_on_reminder_toggled)
	reminder_time_label.text = "Reminder time: %s (placeholder)" % Database.get_setting("reminder_time", "08:00")

	# Version label
	version_label.text = "Fitness RPG v1.0.0"

	# Reset button with confirmation
	reset_btn.pressed.connect(_on_reset_pressed)
	confirm_dialog.confirmed.connect(_on_reset_confirmed)

func _apply_styles():
	ThemeManager.apply_button($TopBar/BackBtn)
	ThemeManager.apply_button(edit_profile_btn)
	ThemeManager.apply_button(reset_btn)

func _apply_section_colors():
	var accent = ThemeManager.get_color("primary_accent")
	var secondary = ThemeManager.get_color("text_secondary")
	for header_name in ["ProfileHeader", "UnitsHeader", "ThemeHeader", "NotificationsHeader", "DataHeader", "AboutHeader"]:
		var node = $ScrollContainer/VBox.get_node_or_null(header_name)
		if node:
			node.add_theme_color_override("font_color", accent)
	version_label.add_theme_color_override("font_color", secondary)
	reminder_time_label.add_theme_color_override("font_color", secondary)

func _populate_themes():
	var themes = ThemeManager.get_theme_list()
	for t in themes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		var indicator = "● " if t["key"] == ThemeManager.current_theme_key else "  "
		btn.text = "%s%s — %s" % [indicator, t["name"], t["description"]]
		btn.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
		btn.pressed.connect(func(): _select_theme(t["key"]))
		ThemeManager.apply_button(btn)
		theme_list.add_child(btn)

func _select_theme(key: String):
	ThemeManager.apply_theme(key)
	ThemeManager.apply_gradient_bg(bg)
	_apply_section_colors()
	_apply_styles()
	# Rebuild theme list
	for child in theme_list.get_children():
		child.queue_free()
	_populate_themes()

func _on_unit_changed(index: int):
	var use_imperial = index == 1
	var stats = Database.get_user_stats()
	stats["use_imperial"] = use_imperial
	Database.save_user_stats(stats)
	GameManager.user_stats = stats

func _on_reminder_toggled(pressed: bool):
	Database.set_setting("workout_reminders", pressed)
	if pressed:
		Database.set_setting("reminder_time", "08:00")
		reminder_time_label.text = "Reminder time: 08:00 (placeholder)"
	else:
		reminder_time_label.text = "Reminders disabled"

func _on_reset_pressed():
	confirm_dialog.popup_centered()

func _on_reset_confirmed():
	Database.reset_all_data()
	GameManager.user_stats = Database.get_user_stats()
	ThemeManager.apply_theme("clean_game")
	# Reset UI state
	unit_toggle.selected = 0
	reminder_toggle.button_pressed = false
	reminder_time_label.text = "Reminder time: 08:00 (placeholder)"
	for child in theme_list.get_children():
		child.queue_free()
	_populate_themes()
	ThemeManager.apply_gradient_bg(bg)
	_apply_section_colors()
	_apply_styles()

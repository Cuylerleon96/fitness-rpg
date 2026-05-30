extends Control

@onready var bg = $Background
@onready var name_input = $ScrollContainer/VBox/NameInput
@onready var age_input = $ScrollContainer/VBox/AgeInput
@onready var weight_input = $ScrollContainer/VBox/WeightInput
@onready var height_input = $ScrollContainer/VBox/HeightInput
@onready var goal_input = $ScrollContainer/VBox/GoalInput
@onready var experience_input = $ScrollContainer/VBox/ExperienceInput
@onready var workouts_input = $ScrollContainer/VBox/WorkoutsInput
@onready var save_btn = $SaveBtn

func _ready():
	bg.color = ThemeManager.get_color("background")
	$ScrollContainer/VBox/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	$ScrollContainer/VBox/Title.add_theme_font_size_override("font_size", 28)
	save_btn.pressed.connect(_on_save)

func _on_save():
	var stats = {
		"name": name_input.text,
		"age": age_input.text.to_int(),
		"weight_kg": weight_input.text.to_float(),
		"height_cm": height_input.text.to_float(),
		"fitness_goal": goal_input.text,
		"activity_level": "moderate",
		"workouts_per_week": workouts_input.text.to_int() if workouts_input.text.is_valid_int() else 3,
		"experience_level": experience_input.text,
		"preferred_duration": 45,
		"daily_calories": 2000,
		"daily_protein": 150,
		"training_types": "",
		"available_equipment": ""
	}
	Database.save_user_stats(stats)
	GameManager.user_stats = stats
	GameManager.go_to_hub()

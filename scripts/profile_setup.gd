extends Control

@onready var bg = $Background
@onready var name_input = $ScrollContainer/VBox/NameInput
@onready var age_input = $ScrollContainer/VBox/AgeInput
@onready var weight_input = $ScrollContainer/VBox/WeightInput
@onready var height_input = $ScrollContainer/VBox/HeightInput
@onready var goal_input = $ScrollContainer/VBox/GoalInput
@onready var experience_input = $ScrollContainer/VBox/ExperienceInput
@onready var workouts_input = $ScrollContainer/VBox/WorkoutsInput
@onready var unit_toggle = $ScrollContainer/VBox/UnitToggle
@onready var activity_dropdown = $ScrollContainer/VBox/ActivityDropdown
@onready var calories_input = $ScrollContainer/VBox/CaloriesInput
@onready var protein_input = $ScrollContainer/VBox/ProteinInput
@onready var duration_input = $ScrollContainer/VBox/DurationInput
@onready var save_btn = $SaveBtn

var _use_imperial: bool = false

var _training_types = [
	"strength", "cardio", "hiit", "yoga", "flexibility", "calisthenics",
	"pilates", "powerlifting", "bodybuilding", "crossfit", "stretching"
]

var _equipment_categories = {
	"Free Weights": ["dumbbells", "barbell", "kettlebell", "weight_plates", "ez_curl_bar", "trap_bar", "ankle_weights"],
	"Machines": ["cable_machine", "leg_press", "lat_pulldown", "leg_curl", "smith_machine", "preacher_curl_station", "cable_crossover", "pec_fly_rear_delt"],
	"Benches & Racks": ["bench", "squat_rack", "power_rack", "dip_station", "parallettes"],
	"Cardio": ["treadmill", "rowing_machine", "stationary_bike", "elliptical", "stair_climber", "jump_rope"],
	"Cables & Bands": ["resistance_bands", "resistance_loops", "trx_suspension_trainer", "pull_up_bar", "gymnastics_rings"],
	"Accessories": ["medicine_ball", "foam_roller", "ab_roller", "yoga_mat", "wrist_wraps", "hip_thrust_platform", "battle_ropes", "plyo_box"],
	"Bodyweight Only": ["bodyweight_only", "yoga", "stretching"]
}

var _activity_levels = ["sedentary", "light", "moderate", "active", "very_active"]

var _training_checks: Dictionary = {}
var _equipment_checks: Dictionary = {}

func _ready():
	bg.color = ThemeManager.get_color("background")
	$ScrollContainer/VBox/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	$ScrollContainer/VBox/Title.add_theme_font_size_override("font_size", 28)
	save_btn.pressed.connect(_on_save)

	# Set up unit toggle
	unit_toggle.add_item("Metric (kg/cm)")
	unit_toggle.add_item("Imperial (lbs/inches)")
	unit_toggle.item_selected.connect(_on_unit_changed)

	# Set up activity level dropdown
	for level in _activity_levels:
		activity_dropdown.add_item(level.capitalize())
	activity_dropdown.selected = 2 # default moderate

	# Build training type checkboxes
	var training_section = $ScrollContainer/VBox/TrainingSection
	for t in _training_types:
		var cb = CheckBox.new()
		cb.text = t.capitalize()
		cb.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
		training_section.add_child(cb)
		_training_checks[t] = cb

	# Build equipment checkboxes with category headers
	var equipment_section = $ScrollContainer/VBox/EquipmentSection
	for category in _equipment_categories:
		var header = Label.new()
		header.text = category
		header.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
		header.add_theme_font_size_override("font_size", 18)
		equipment_section.add_child(header)
		for e in _equipment_categories[category]:
			var cb = CheckBox.new()
			cb.text = e.replace("_", " ").capitalize()
			cb.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
			equipment_section.add_child(cb)
			_equipment_checks[e] = cb

	# Set labels for default unit
	_update_unit_labels()

	# Load existing data if available
	var stats = Database.get_user_stats()
	if stats.has("name") and stats["name"] != "":
		name_input.text = str(stats.get("name", ""))
		age_input.text = str(stats.get("age", ""))
		if stats.get("use_imperial", false):
			unit_toggle.selected = 1
			_use_imperial = true
			weight_input.text = str(snappedf(Database.kg_to_lbs(stats.get("weight_kg", 0.0)), 0.1))
			height_input.text = str(snappedf(Database.cm_to_inches(stats.get("height_cm", 0.0)), 0.1))
		else:
			weight_input.text = str(stats.get("weight_kg", ""))
			height_input.text = str(stats.get("height_cm", ""))
		goal_input.text = str(stats.get("fitness_goal", ""))
		experience_input.text = str(stats.get("experience_level", ""))
		workouts_input.text = str(stats.get("workouts_per_week", 3))
		calories_input.text = str(stats.get("daily_calories", 2000))
		protein_input.text = str(stats.get("daily_protein", 150))
		duration_input.text = str(stats.get("preferred_duration", 45))

		var act_idx = _activity_levels.find(stats.get("activity_level", "moderate"))
		if act_idx >= 0:
			activity_dropdown.selected = act_idx

		# Restore training types
		var saved_types = stats.get("training_types", "")
		if saved_types is String and saved_types != "":
			for t in saved_types.split(","):
				t = t.strip_edges()
				if t in _training_checks:
					_training_checks[t].button_pressed = true

		# Restore equipment
		var saved_equip = stats.get("available_equipment", "")
		if saved_equip is String and saved_equip != "":
			for e in saved_equip.split(","):
				e = e.strip_edges()
				if e in _equipment_checks:
					_equipment_checks[e].button_pressed = true

	_update_unit_labels()

func _on_unit_changed(index: int):
	_use_imperial = index == 1
	# Convert current input values
	var w = weight_input.text.to_float()
	var h = height_input.text.to_float()
	if _use_imperial and index == 1:
		# Was metric, now imperial
		weight_input.text = str(snappedf(Database.kg_to_lbs(w), 0.1)) if w > 0 else ""
		height_input.text = str(snappedf(Database.cm_to_inches(h), 0.1)) if h > 0 else ""
	elif not _use_imperial and index == 0:
		# Was imperial, now metric
		weight_input.text = str(snappedf(Database.lbs_to_kg(w), 0.1)) if w > 0 else ""
		height_input.text = str(snappedf(Database.inches_to_cm(h), 0.1)) if h > 0 else ""
	_update_unit_labels()

func _update_unit_labels():
	if _use_imperial:
		$ScrollContainer/VBox/WeightLabel.text = "Weight (lbs)"
		$ScrollContainer/VBox/HeightLabel.text = "Height (inches)"
	else:
		$ScrollContainer/VBox/WeightLabel.text = "Weight (kg)"
		$ScrollContainer/VBox/HeightLabel.text = "Height (cm)"

func _on_save():
	var weight_val = weight_input.text.to_float()
	var height_val = height_input.text.to_float()

	# Always store in metric (kg/cm)
	var weight_kg = Database.lbs_to_kg(weight_val) if _use_imperial else weight_val
	var height_cm = Database.inches_to_cm(height_val) if _use_imperial else height_val

	# Collect selected training types
	var selected_types = []
	for t in _training_types:
		if _training_checks[t].button_pressed:
			selected_types.append(t)

	# Collect selected equipment
	var selected_equip = []
	for e in _equipment_checks:
		if _equipment_checks[e].button_pressed:
			selected_equip.append(e)

	var stats = {
		"name": name_input.text,
		"age": age_input.text.to_int(),
		"weight_kg": weight_kg,
		"height_cm": height_cm,
		"use_imperial": _use_imperial,
		"fitness_goal": goal_input.text,
		"activity_level": _activity_levels[activity_dropdown.selected],
		"workouts_per_week": workouts_input.text.to_int() if workouts_input.text.is_valid_int() else 3,
		"experience_level": experience_input.text,
		"preferred_duration": duration_input.text.to_int() if duration_input.text.is_valid_int() else 45,
		"daily_calories": calories_input.text.to_int() if calories_input.text.is_valid_int() else 2000,
		"daily_protein": protein_input.text.to_int() if protein_input.text.is_valid_int() else 150,
		"training_types": ",".join(selected_types),
		"available_equipment": ",".join(selected_equip)
	}
	Database.save_user_stats(stats)
	GameManager.user_stats = stats
	GameManager.go_to_hub()

extends Control

@onready var bg = $Background
@onready var grid = $ScrollContainer/Grid

func _ready():
	bg.color = ThemeManager.get_color("background")
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	_populate()

func _populate():
	var achievements = Database.get_achievements()
	for a in achievements:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(160, 180)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var icon = Label.new()
		icon.text = a.get("icon", "?")
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 40)
		
		var name_label = Label.new()
		name_label.text = a.get("name", "")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		var desc_label = Label.new()
		desc_label.text = a.get("description", "")
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		if not a.get("is_unlocked", false):
			icon.modulate = Color(1, 1, 1, 0.3)
			name_label.modulate = Color(1, 1, 1, 0.5)
		
		vbox.add_child(icon)
		vbox.add_child(name_label)
		vbox.add_child(desc_label)
		card.add_child(vbox)
		grid.add_child(card)

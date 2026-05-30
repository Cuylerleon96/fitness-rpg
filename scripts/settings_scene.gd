extends Control

@onready var bg = $Background
@onready var theme_list = $ScrollContainer/VBox/ThemeList

func _ready():
	bg.color = ThemeManager.get_color("background")
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	$ScrollContainer/VBox/ThemeHeader.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	$ScrollContainer/VBox/AboutHeader.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	$ScrollContainer/VBox/VersionLabel.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	_populate_themes()

func _populate_themes():
	var themes = ThemeManager.get_theme_list()
	for t in themes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 60)
		var indicator = "● " if t["key"] == ThemeManager.current_theme_key else "  "
		btn.text = "%s%s — %s" % [indicator, t["name"], t["description"]]
		btn.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
		btn.pressed.connect(func(): _select_theme(t["key"]))
		theme_list.add_child(btn)

func _select_theme(key: String):
	ThemeManager.apply_theme(key)
	bg.color = ThemeManager.get_color("background")
	# Rebuild theme list
	for child in theme_list.get_children():
		child.queue_free()
	_populate_themes()

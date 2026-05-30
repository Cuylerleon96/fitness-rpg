extends Control

@onready var bg = $Background
@onready var title = $VBox/Title
@onready var subtitle = $VBox/Subtitle
@onready var start_btn = $VBox/StartButton

func _ready():
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)
	
	# Style the title
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", ThemeManager.get_color("gold"))
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	
	# Style the button
	start_btn.add_theme_font_size_override("font_size", 32)
	ThemeManager.apply_button(start_btn)
	
	# Animate title
	title.modulate.a = 0.0
	subtitle.modulate.a = 0.0
	start_btn.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_property(title, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(subtitle, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(start_btn, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT)
	
	start_btn.pressed.connect(_on_start_pressed)

func _apply_theme():
	ThemeManager.apply_gradient_bg(bg)

func _on_start_pressed():
	var has_stats = not GameManager.user_stats.is_empty()
	if has_stats:
		GameManager.go_to_hub()
	else:
		GameManager.go_to_scene("res://scenes/profile_setup.tscn")

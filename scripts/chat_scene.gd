extends Control

@onready var bg = $Background
@onready var message_list = $ScrollContainer/VBox/MessageList
@onready var input_field = $BottomBar/InputField
@onready var send_btn = $BottomBar/SendBtn
@onready var scroll = $ScrollContainer

var is_waiting: bool = false

func _ready():
	ThemeManager.apply_gradient_bg(bg)
	ThemeManager.fix_scroll_container(scroll)
	$TopBar/BackBtn.pressed.connect(func(): GameManager.go_to_hub())
	$TopBar/Title.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent"))
	ThemeManager.apply_button($TopBar/BackBtn)
	ThemeManager.apply_button(send_btn)
	ThemeManager.apply_input(input_field)
	send_btn.pressed.connect(_on_send)
	input_field.text_submitted.connect(func(_text): _on_send())
	AIClient.coach_response.connect(_on_coach_response)
	AIClient.ai_error.connect(_on_ai_error)

	# Welcome message
	_add_message("AI Coach", "Hey! I'm your AI fitness coach. Ask me anything about workouts, nutrition, or recovery! 💪", false)

func _on_send():
	var text = input_field.text.strip_edges()
	if text.is_empty() or is_waiting:
		return

	input_field.text = ""
	_add_message("You", text, true)

	is_waiting = true
	_add_typing_indicator()
	AIClient.send_coach_message(text)

func _add_message(sender: String, text: String, is_user: bool):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var bubble_panel = PanelContainer.new()
	bubble_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Style the bubble
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12 if is_user else 4
	style.corner_radius_bottom_right = 4 if is_user else 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	if is_user:
		style.bg_color = ThemeManager.get_color("primary_accent") * Color(1, 1, 1, 0.3)
	else:
		style.bg_color = ThemeManager.get_color("surface_variant")

	bubble_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_font_size_override("font_size", 14)
	sender_label.add_theme_color_override("font_color", ThemeManager.get_color("primary_accent") if not is_user else ThemeManager.get_color("text_secondary"))
	vbox.add_child(sender_label)

	var text_label = Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", ThemeManager.get_color("text_primary"))
	vbox.add_child(text_label)

	bubble_panel.add_child(vbox)

	if is_user:
		# Right-align: add spacer on left
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.custom_minimum_size = Vector2(60, 0)
		row.add_child(spacer)
		row.add_child(bubble_panel)
	else:
		# Left-align: add spacer on right
		row.add_child(bubble_panel)
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.custom_minimum_size = Vector2(60, 0)
		row.add_child(spacer)

	message_list.add_child(row)
	# Scroll to bottom
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _add_typing_indicator():
	var row = HBoxContainer.new()
	row.name = "TypingIndicator"
	row.add_theme_constant_override("separation", 8)

	var bubble_panel = PanelContainer.new()
	bubble_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.bg_color = ThemeManager.get_color("surface_variant")
	bubble_panel.add_theme_stylebox_override("panel", style)

	var typing_label = Label.new()
	typing_label.text = "Coach is typing..."
	typing_label.add_theme_font_size_override("font_size", 16)
	typing_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	typing_label.name = "TypingText"
	bubble_panel.add_child(typing_label)

	row.add_child(bubble_panel)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(60, 0)
	row.add_child(spacer)

	message_list.add_child(row)
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _remove_typing_indicator():
	for child in message_list.get_children():
		if child.name == "TypingIndicator":
			child.queue_free()
			break

func _on_coach_response(text: String):
	is_waiting = false
	_remove_typing_indicator()
	_add_message("AI Coach", text, false)

func _on_ai_error(message: String):
	is_waiting = false
	_remove_typing_indicator()
	_add_message("System", "Sorry, something went wrong: %s" % message, false)

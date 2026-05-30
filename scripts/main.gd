extends Control

func _ready():
	# Start with the title screen
	GameManager.go_to_scene("res://scenes/title_screen.tscn")

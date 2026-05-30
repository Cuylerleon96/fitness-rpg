extends Control

func _ready():
	# Defer scene change to avoid "parent busy" error during _ready
	get_tree().change_scene_to_file.call_deferred("res://scenes/title_screen.tscn")

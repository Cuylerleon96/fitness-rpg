## GameManager.gd — Central state manager (replaces ViewModels)
## Autoload singleton: GameManager
extends Node

signal xp_gained(amount: int)
signal level_up(new_level: int, rank: String)
signal achievement_unlocked(achievement: Dictionary)
signal workout_completed(session: Dictionary)
signal boss_available(boss_id: String)

# ── Current state ──────────────────────────────────────────────────

var user_stats: Dictionary = {}
var profile: Dictionary = {}
var current_theme: String = "clean_game"

# ── Initialization ─────────────────────────────────────────────────

func _ready():
	_load_state()

func _load_state():
	user_stats = Database.get_user_stats()
	profile = Database.get_gamification_profile()
	current_theme = Database.get_setting("theme", "CLEAN_GAME")
	ThemeManager.apply_theme(current_theme)
	_initialize_achievements()

func refresh():
	profile = Database.get_gamification_profile()
	user_stats = Database.get_user_stats()

# ── Achievement Initialization ─────────────────────────────────────

func _initialize_achievements():
	if Database.get_unlocked_count() > 0:
		return
	var achievements = [
		{"id": "first_workout", "name": "First Steps", "description": "Complete your first workout", "icon": "🏋️", "category": "milestones", "xp_reward": 50, "target": 1},
		{"id": "five_workouts", "name": "Getting Started", "description": "Complete 5 workouts", "icon": "💪", "category": "milestones", "xp_reward": 100, "target": 5},
		{"id": "ten_workouts", "name": "Dedicated", "description": "Complete 10 workouts", "icon": "🔥", "category": "milestones", "xp_reward": 150, "target": 10},
		{"id": "twentyfive_workouts", "name": "Committed", "description": "Complete 25 workouts", "icon": "⭐", "category": "milestones", "xp_reward": 250, "target": 25},
		{"id": "fifty_workouts", "name": "Beast Mode", "description": "Complete 50 workouts", "icon": "🦁", "category": "milestones", "xp_reward": 500, "target": 50},
		{"id": "streak_3", "name": "3 Day Streak", "description": "Maintain a 3-day streak", "icon": "🔥", "category": "streaks", "xp_reward": 75, "target": 3},
		{"id": "streak_7", "name": "Week Warrior", "description": "Maintain a 7-day streak", "icon": "⚡", "category": "streaks", "xp_reward": 150, "target": 7},
		{"id": "streak_30", "name": "Monthly Master", "description": "Maintain a 30-day streak", "icon": "👑", "category": "streaks", "xp_reward": 500, "target": 30},
		{"id": "level_5", "name": "Warrior", "description": "Reach level 5", "icon": "⚔️", "category": "levels", "xp_reward": 100, "target": 5},
		{"id": "level_10", "name": "Champion", "description": "Reach level 10", "icon": "🏆", "category": "levels", "xp_reward": 200, "target": 10},
		{"id": "level_20", "name": "Legend", "description": "Reach level 20", "icon": "🌟", "category": "levels", "xp_reward": 500, "target": 20},
		{"id": "boss_slayer", "name": "Boss Slayer", "description": "Defeat your first boss", "icon": "⚔️", "category": "boss", "xp_reward": 200, "target": 1},
		{"id": "boss_hunter", "name": "Boss Hunter", "description": "Defeat 5 bosses", "icon": "🏹", "category": "boss", "xp_reward": 500, "target": 5},
		{"id": "boss_legend", "name": "Boss Legend", "description": "Defeat 10 bosses", "icon": "👑", "category": "boss", "xp_reward": 1000, "target": 10},
	]
	Database.insert_achievements(achievements)

# ── XP & Leveling ──────────────────────────────────────────────────

func calculate_workout_xp(sets_completed: int, total_volume: float, duration_min: int, exercise_types: Array) -> int:
	var base = sets_completed * 10 + int(total_volume * 0.1) + duration_min * 2
	var variety_bonus = 25 if exercise_types.size() >= 3 else 0
	return base + variety_bonus

func get_level_from_xp(total_xp: int) -> int:
	if total_xp <= 0:
		return 1
	return int(floor(log(float(total_xp) / 100.0 + 1.0) / log(2.0))) + 1

func get_xp_for_next_level(total_xp: int, current_level: int) -> int:
	var needed = int(ceil(pow(2.0, float(current_level)) * 100.0))
	return needed - total_xp if needed > total_xp else 0

func get_rank_title(level: int) -> String:
	if level >= 20: return "Legend"
	if level >= 15: return "Elite"
	if level >= 10: return "Champion"
	if level >= 5: return "Warrior"
	return "Rookie"

func get_xp_progress_fraction() -> float:
	var total_xp = profile.get("total_xp", 0)
	var level = get_level_from_xp(total_xp)
	var needed = int(pow(2.0, float(level)) * 100.0)
	var prev_needed = int(pow(2.0, float(level - 1)) * 100.0) if level > 1 else 0
	return float(total_xp - prev_needed) / float(needed - prev_needed) if needed > prev_needed else 1.0

# ── Award XP ───────────────────────────────────────────────────────

func award_workout_xp(sets_completed: int, total_volume: float, duration_min: int, exercise_types: Array):
	var xp = calculate_workout_xp(sets_completed, total_volume, duration_min, exercise_types)
	var old_level = get_level_from_xp(profile.get("total_xp", 0))
	var new_total_xp = profile.get("total_xp", 0) + xp
	var new_level = get_level_from_xp(new_total_xp)
	
	Database.update_gamification_profile({
		"total_xp": new_total_xp,
		"total_workouts": profile.get("total_workouts", 0) + 1,
		"last_workout_date": _today_epoch_day()
	})
	_update_streak()
	profile = Database.get_gamification_profile()
	
	xp_gained.emit(xp)
	if new_level > old_level:
		level_up.emit(new_level, get_rank_title(new_level))
	
	_check_achievements()

# ── Streak ─────────────────────────────────────────────────────────

func _update_streak():
	var today = _today_epoch_day()
	var last_date = profile.get("last_workout_date", 0)
	var current_streak = profile.get("current_streak", 0)
	
	var new_streak = current_streak
	if last_date == today:
		new_streak = current_streak  # already worked out today
	elif last_date == today - 1:
		new_streak = current_streak + 1
	else:
		new_streak = 1
	
	var longest = max(profile.get("longest_streak", 0), new_streak)
	Database.update_gamification_profile({"current_streak": new_streak, "longest_streak": longest})

func _today_epoch_day() -> int:
	return int(Time.get_unix_time_from_system() / 86400)

# ── Boss Battles ───────────────────────────────────────────────────

func is_boss_available() -> bool:
	var tw = profile.get("total_workouts", 0)
	return tw > 0 and tw % 10 == 0

func get_boss_id() -> String:
	return "boss_%d" % profile.get("total_workouts", 0)

func defeat_boss(boss_data: Dictionary):
	var xp_reward = boss_data.get("xp_reward", 200)
	Database.update_gamification_profile({
		"bosses_defeated": profile.get("bosses_defeated", 0) + 1,
		"total_xp": profile.get("total_xp", 0) + xp_reward
	})
	profile = Database.get_gamification_profile()
	_check_achievements()

# ── Achievement Checking ───────────────────────────────────────────

func _check_achievements():
	var achievements = Database.get_achievements()
	var tw = profile.get("total_workouts", 0)
	var streak = profile.get("current_streak", 0)
	var level = get_level_from_xp(profile.get("total_xp", 0))
	var bosses = profile.get("bosses_defeated", 0)
	
	for a in achievements:
		if a["is_unlocked"]:
			continue
		var id = a["id"]
		var target = a["target"]
		var current = 0
		
		if id.begins_with("first_workout") or id == "five_workouts" or id == "ten_workouts" or id == "twentyfive_workouts" or id == "fifty_workouts":
			current = tw
		elif id.begins_with("streak_"):
			current = streak
		elif id.begins_with("level_"):
			current = level
		elif id.begins_with("boss_"):
			current = bosses
		
		Database.update_achievement_progress(id, min(current, target))
		if current >= target:
			Database.unlock_achievement(id)
			a["is_unlocked"] = 1
			achievement_unlocked.emit(a)

# ── Navigation ─────────────────────────────────────────────────────

func go_to_scene(scene_path: String):
	get_tree().change_scene_to_file(scene_path)

func go_to_hub():
	go_to_scene("res://scenes/hub.tscn")

func go_to_workout(routine_id: String):
	# Store routine_id in a temporary var for the workout scene to read
	_pending_routine_id = routine_id
	go_to_scene("res://scenes/workout.tscn")

var _pending_routine_id: String = ""

func get_pending_routine_id() -> String:
	var id = _pending_routine_id
	_pending_routine_id = ""
	return id

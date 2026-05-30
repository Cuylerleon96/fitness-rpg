## Database.gd — JSON file-based storage (replaces SQLite for Godot compatibility)
## Autoload singleton: Database
extends Node

const DATA_PATH = "user://data/"
const DB_FILE = "user://data/fitness_db.json"

var _data: Dictionary = {}

func _ready():
	DirAccess.make_dir_recursive_absolute(DATA_PATH)
	_load()

func _load():
	if FileAccess.file_exists(DB_FILE):
		var file = FileAccess.open(DB_FILE, FileAccess.READ)
		if file:
			var json = JSON.new()
			var result = json.parse(file.get_as_text())
			if result == OK:
				_data = json.data
			file.close()
	
	# Ensure all tables exist
	if not "user_stats" in _data:
		_data["user_stats"] = {}
	if not "gamification_profile" in _data:
		_data["gamification_profile"] = {"total_xp": 0, "current_level": 1, "current_streak": 0, "longest_streak": 0, "total_workouts": 0, "last_workout_date": 0, "streak_freezes": 0, "bosses_defeated": 0}
	if not "achievements" in _data:
		_data["achievements"] = {}
	if not "workout_sessions" in _data:
		_data["workout_sessions"] = {}
	if not "routines" in _data:
		_data["routines"] = {}
	if not "settings" in _data:
		_data["settings"] = {}
	_save()

func _save():
	var file = FileAccess.open(DB_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data, "\t"))
		file.close()

# ── User Stats ─────────────────────────────────────────────────────

func get_user_stats() -> Dictionary:
	return _data["user_stats"]

func save_user_stats(stats: Dictionary):
	_data["user_stats"] = stats
	_save()

# ── Gamification Profile ───────────────────────────────────────────

func get_gamification_profile() -> Dictionary:
	return _data["gamification_profile"]

func update_gamification_profile(fields: Dictionary):
	for key in fields:
		_data["gamification_profile"][key] = fields[key]
	_save()

# ── Achievements ───────────────────────────────────────────────────

func get_achievements() -> Array:
	var list = []
	for id in _data["achievements"]:
		var a = _data["achievements"][id].duplicate()
		a["id"] = id
		list.append(a)
	list.sort_custom(func(a, b):
		if a.get("category", "") != b.get("category", ""):
			return a.get("category", "") < b.get("category", "")
		return a.get("name", "") < b.get("name", "")
	)
	return list

func insert_achievements(achievements: Array):
	for a in achievements:
		var id = a["id"]
		if not id in _data["achievements"]:
			_data["achievements"][id] = {
				"name": a.get("name", ""),
				"description": a.get("description", ""),
				"icon": a.get("icon", ""),
				"category": a.get("category", ""),
				"xp_reward": a.get("xp_reward", 0),
				"is_unlocked": false,
				"unlocked_at": 0,
				"progress": 0,
				"target": a.get("target", 1)
			}
	_save()

func unlock_achievement(achievement_id: String):
	if achievement_id in _data["achievements"]:
		_data["achievements"][achievement_id]["is_unlocked"] = true
		_data["achievements"][achievement_id]["unlocked_at"] = int(Time.get_unix_time_from_system())
		_save()

func update_achievement_progress(achievement_id: String, progress: int):
	if achievement_id in _data["achievements"]:
		_data["achievements"][achievement_id]["progress"] = progress
		_save()

func get_unlocked_count() -> int:
	var count = 0
	for id in _data["achievements"]:
		if _data["achievements"][id].get("is_unlocked", false):
			count += 1
	return count

# ── Workout Sessions ───────────────────────────────────────────────

func insert_session(session: Dictionary):
	var id = session.get("id", str(randi()))
	_data["workout_sessions"][id] = session
	_save()

func get_recent_sessions(limit: int = 50) -> Array:
	var sessions = []
	for id in _data["workout_sessions"]:
		var s = _data["workout_sessions"][id].duplicate()
		s["id"] = id
		sessions.append(s)
	sessions.sort_custom(func(a, b): return a.get("date", 0) > b.get("date", 0))
	return sessions.slice(0, limit)

func get_sessions_for_exercise(exercise_name: String) -> Array:
	var sessions = []
	for id in _data["workout_sessions"]:
		var s = _data["workout_sessions"][id]
		var logs = s.get("exercise_logs", [])
		if logs is String:
			logs = JSON.parse_string(logs) if logs else []
		for log in logs:
			if log.get("exercise_name", "") == exercise_name:
				var entry = s.duplicate()
				entry["id"] = id
				sessions.append(entry)
				break
	return sessions

# ── Routines ───────────────────────────────────────────────────────

func insert_routine(routine: Dictionary):
	var id = routine.get("id", str(randi()))
	_data["routines"][id] = routine
	_save()

func get_routines() -> Array:
	var list = []
	for id in _data["routines"]:
		var r = _data["routines"][id].duplicate()
		r["id"] = id
		list.append(r)
	list.sort_custom(func(a, b): return a.get("created_at", 0) > b.get("created_at", 0))
	return list

func get_routine(routine_id: String) -> Dictionary:
	if routine_id in _data["routines"]:
		var r = _data["routines"][routine_id].duplicate()
		r["id"] = routine_id
		return r
	return {}

func delete_routine(routine_id: String):
	_data["routines"].erase(routine_id)
	_save()

# ── Settings ───────────────────────────────────────────────────────

func get_setting(key: String, default_value: String = "") -> String:
	return _data["settings"].get(key, default_value)

func set_setting(key: String, value: String):
	_data["settings"][key] = value
	_save()

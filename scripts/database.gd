## Database.gd — JSON file-based storage (replaces SQLite for Godot compatibility)
## Autoload singleton: Database
extends Node

const DATA_PATH = "user://data/"
const DB_FILE = "user://data/fitness_db.json"

var _data: Dictionary = {}
var _save_dirty: bool = false
var _save_timer: float = 0.0

func _ready():
	DirAccess.make_dir_recursive_absolute(DATA_PATH)
	_load()

func _process(delta: float):
	if _save_dirty:
		_save_timer += delta
		if _save_timer >= 0.5:
			_flush_save()

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
		_data["gamification_profile"] = {"total_xp": 0, "current_level": 1, "current_streak": 0, "longest_streak": 0, "total_workouts": 0, "last_workout_date": 0, "streak_freezes": 0, "bosses_defeated": 0, "quest_name": "", "quest_flavor": "", "quest_completed": false}
	if not "achievements" in _data:
		_data["achievements"] = {}
	if not "workout_sessions" in _data:
		_data["workout_sessions"] = {}
	if not "routines" in _data:
		_data["routines"] = {}
	if not "settings" in _data:
		_data["settings"] = {}
	if not "weekly_challenges" in _data:
		_data["weekly_challenges"] = {}
	# Ensure use_imperial default in user_stats
	if not "use_imperial" in _data["user_stats"]:
		_data["user_stats"]["use_imperial"] = false
	# Ensure daily reward defaults in settings
	if not "last_daily_claim" in _data["settings"]:
		_data["settings"]["last_daily_claim"] = 0
	if not "daily_claim_streak" in _data["settings"]:
		_data["settings"]["daily_claim_streak"] = 0
	# Ensure quest fields in gamification_profile
	if not "quest_name" in _data["gamification_profile"]:
		_data["gamification_profile"]["quest_name"] = ""
	if not "quest_flavor" in _data["gamification_profile"]:
		_data["gamification_profile"]["quest_flavor"] = ""
	if not "quest_completed" in _data["gamification_profile"]:
		_data["gamification_profile"]["quest_completed"] = false
	_save()

func _save():
	_save_dirty = true
	_save_timer = 0.0

func _flush_save():
	_save_dirty = false
	_save_timer = 0.0
	var file = FileAccess.open(DB_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data, "	"))
		file.close()

func _save_now():
	_save_dirty = false
	_save_timer = 0.0
	var file = FileAccess.open(DB_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data, "	"))
		file.close()

# ── Unit Conversion Helpers ──────────────────────────────────────

func kg_to_lbs(kg: float) -> float:
	return kg * 2.20462

func lbs_to_kg(lbs: float) -> float:
	return lbs / 2.20462

func cm_to_inches(cm: float) -> float:
	return cm / 2.54

func inches_to_cm(inches: float) -> float:
	return inches * 2.54

# ── User Stats ─────────────────────────────────────────────────────

func get_user_stats() -> Dictionary:
	if not "user_stats" in _data:
		_data["user_stats"] = {}
	return _data["user_stats"]

func save_user_stats(stats: Dictionary):
	_data["user_stats"] = stats
	_save()

# ── Gamification Profile ───────────────────────────────────────────

func get_gamification_profile() -> Dictionary:
	if not "gamification_profile" in _data:
		_data["gamification_profile"] = {"total_xp": 0, "current_level": 1, "current_streak": 0, "longest_streak": 0, "total_workouts": 0, "last_workout_date": 0, "streak_freezes": 0, "bosses_defeated": 0}
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

func get_setting(key: String, default_value = ""):
	return _data["settings"].get(key, default_value)

func set_setting(key: String, value):
	_data["settings"][key] = value
	_save()

# ── Weekly Challenges ──────────────────────────────────────────────

func get_weekly_challenges() -> Array:
	var list = []
	for id in _data["weekly_challenges"]:
		var c = _data["weekly_challenges"][id].duplicate()
		c["id"] = id
		list.append(c)
	return list

func save_weekly_challenges(challenges: Array):
	for c in challenges:
		var id = c.get("id", str(randi()))
		if not id in _data["weekly_challenges"]:
			_data["weekly_challenges"][id] = {
				"name": c.get("name", c.get("description", "")),
				"description": c.get("description", ""),
				"target": c.get("target", 1),
				"progress": 0,
				"xp_reward": c.get("xp_reward", 50),
				"is_completed": false,
				"week_start": _get_week_start()
			}
	_save()

func update_weekly_challenge_progress(type: String, amount: int = 1):
	var week_start = _get_week_start()
	for id in _data["weekly_challenges"]:
		var c = _data["weekly_challenges"][id]
		if c.get("week_start", 0) != week_start:
			continue
		if c.get("is_completed", false):
			continue
		if c.get("id", "").contains(type) or c.get("description", "").to_lower().contains(type):
			c["progress"] = mini(c.get("progress", 0) + amount, c.get("target", 1))
			if c["progress"] >= c.get("target", 1):
				c["is_completed"] = true
	_save()

func _get_week_start() -> int:
	var now = Time.get_unix_time_from_system()
	var dt = Time.get_datetime_dict_from_unix_time(now)
	var day_of_week = dt.get("weekday", 0) # 0=Sunday
	var seconds_today = dt.get("hour", 0) * 3600 + dt.get("minute", 0) * 60 + dt.get("second", 0)
	return int(now - (day_of_week * 86400) - seconds_today)

# ── Daily Reward ───────────────────────────────────────────────────

func claim_daily_reward() -> int:
	var now = Time.get_unix_time_from_system()
	var last_claim = _data["settings"].get("last_daily_claim", 0)
	var streak = _data["settings"].get("daily_claim_streak", 0)
	
	var last_day = int(last_claim / 86400)
	var today_day = int(now / 86400)
	
	if today_day == last_day:
		return 0 # Already claimed today
	
	if today_day == last_day + 1:
		streak += 1
	else:
		streak = 1 # Reset streak
	
	# XP rewards by streak day (cycles every 7)
	var rewards = [10, 15, 20, 25, 30, 40, 50]
	var xp = rewards[(streak - 1) % 7]
	
	_data["settings"]["last_daily_claim"] = int(now)
	_data["settings"]["daily_claim_streak"] = streak
	_save()
	return xp

# ── Personal Bests ─────────────────────────────────────────────────

func get_personal_bests() -> Dictionary:
	var bests = {}
	for id in _data["workout_sessions"]:
		var s = _data["workout_sessions"][id]
		var logs = s.get("exercise_logs", [])
		if logs is String:
			logs = JSON.parse_string(logs) if logs else []
		for log in logs:
			var ex_name = log.get("exercise_name", "")
			if ex_name == "":
				continue
			for set_log in log.get("set_logs", []):
				var weight = set_log.get("weight", 0.0)
				if not ex_name in bests or weight > bests[ex_name]:
					bests[ex_name] = weight
	return bests

# ── Reset All Data ──────────────────────────────────────────────

func reset_all_data():
	_data = {
		"user_stats": {"use_imperial": false},
		"gamification_profile": {"total_xp": 0, "current_level": 1, "current_streak": 0, "longest_streak": 0, "total_workouts": 0, "last_workout_date": 0, "streak_freezes": 0, "bosses_defeated": 0, "quest_name": "", "quest_flavor": "", "quest_completed": false},
		"achievements": {},
		"workout_sessions": {},
		"routines": {},
		"settings": {"last_daily_claim": 0, "daily_claim_streak": 0},
		"weekly_challenges": {}
	}
	_save()

## Database.gd — SQLite wrapper (replaces Room)
## Autoload singleton: Database
extends Node

var db: SQLite
const DB_PATH = "user://fitness.db"

func _ready():
	db = SQLite.new()
	db.path = DB_PATH
	db.open_db()
	_create_tables()

func _create_tables():
	db.query("""
		CREATE TABLE IF NOT EXISTS user_stats (
			id INTEGER PRIMARY KEY DEFAULT 1,
			name TEXT DEFAULT '',
			age INTEGER DEFAULT 0,
			weight_kg REAL DEFAULT 0.0,
			height_cm REAL DEFAULT 0.0,
			fitness_goal TEXT DEFAULT '',
			activity_level TEXT DEFAULT '',
			workouts_per_week INTEGER DEFAULT 3,
			experience_level TEXT DEFAULT '',
			preferred_duration INTEGER DEFAULT 45,
			daily_calories INTEGER DEFAULT 2000,
			daily_protein INTEGER DEFAULT 150,
			training_types TEXT DEFAULT '',
			available_equipment TEXT DEFAULT ''
		)
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS gamification_profile (
			id INTEGER PRIMARY KEY DEFAULT 1,
			total_xp INTEGER DEFAULT 0,
			current_level INTEGER DEFAULT 1,
			current_streak INTEGER DEFAULT 0,
			longest_streak INTEGER DEFAULT 0,
			total_workouts INTEGER DEFAULT 0,
			last_workout_date INTEGER DEFAULT 0,
			streak_freezes INTEGER DEFAULT 0,
			bosses_defeated INTEGER DEFAULT 0
		)
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS achievements (
			id TEXT PRIMARY KEY,
			name TEXT DEFAULT '',
			description TEXT DEFAULT '',
			icon TEXT DEFAULT '',
			category TEXT DEFAULT '',
			xp_reward INTEGER DEFAULT 0,
			is_unlocked INTEGER DEFAULT 0,
			unlocked_at INTEGER DEFAULT 0,
			progress INTEGER DEFAULT 0,
			target INTEGER DEFAULT 1
		)
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS workout_sessions (
			id TEXT PRIMARY KEY,
			routine_id TEXT DEFAULT '',
			routine_name TEXT DEFAULT '',
			start_time INTEGER DEFAULT 0,
			end_time INTEGER DEFAULT 0,
			date INTEGER DEFAULT 0,
			exercise_logs TEXT DEFAULT '[]',
			total_volume REAL DEFAULT 0.0,
			calories_burned INTEGER DEFAULT 0,
			notes TEXT DEFAULT ''
		)
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS routines (
			id TEXT PRIMARY KEY,
			name TEXT DEFAULT '',
			description TEXT DEFAULT '',
			target_muscle_groups TEXT DEFAULT '',
			estimated_duration INTEGER DEFAULT 45,
			difficulty TEXT DEFAULT 'beginner',
			is_ai_generated INTEGER DEFAULT 0,
			created_at INTEGER DEFAULT 0,
			exercises TEXT DEFAULT '[]'
		)
	""")
	db.query("""
		CREATE TABLE IF NOT EXISTS settings (
			key TEXT PRIMARY KEY,
			value TEXT DEFAULT ''
		)
	""")
	# Ensure gamification profile exists
	db.query("SELECT COUNT(*) as cnt FROM gamification_profile")
	if db.query_result[0]["cnt"] == 0:
		db.query("INSERT INTO gamification_profile (id) VALUES (1)")

# ── User Stats ─────────────────────────────────────────────────────

func get_user_stats() -> Dictionary:
	db.query("SELECT * FROM user_stats WHERE id = 1")
	if db.query_result.size() > 0:
		return db.query_result[0]
	return {}

func save_user_stats(stats: Dictionary):
	db.query("INSERT OR REPLACE INTO user_stats (id, name, age, weight_kg, height_cm, fitness_goal, activity_level, workouts_per_week, experience_level, preferred_duration, daily_calories, daily_protein, training_types, available_equipment) VALUES (1, '%s', %d, %f, %f, '%s', '%s', %d, '%s', %d, %d, %d, '%s', '%s')" % [
		stats.get("name", ""), stats.get("age", 0), stats.get("weight_kg", 0.0),
		stats.get("height_cm", 0.0), stats.get("fitness_goal", ""),
		stats.get("activity_level", ""), stats.get("workouts_per_week", 3),
		stats.get("experience_level", ""), stats.get("preferred_duration", 45),
		stats.get("daily_calories", 2000), stats.get("daily_protein", 150),
		stats.get("training_types", ""), stats.get("available_equipment", "")
	])

# ── Gamification Profile ───────────────────────────────────────────

func get_gamification_profile() -> Dictionary:
	db.query("SELECT * FROM gamification_profile WHERE id = 1")
	return db.query_result[0] if db.query_result.size() > 0 else {}

func update_gamification_profile(fields: Dictionary):
	var set_clauses = []
	for key in fields:
		set_clauses.append("%s = %s" % [key, str(fields[key])])
	db.query("UPDATE gamification_profile SET %s WHERE id = 1" % ", ".join(set_clauses))

# ── Achievements ───────────────────────────────────────────────────

func get_achievements() -> Array:
	db.query("SELECT * FROM achievements ORDER BY category, name")
	return db.query_result

func insert_achievements(achievements: Array):
	for a in achievements:
		db.query("INSERT OR IGNORE INTO achievements (id, name, description, icon, category, xp_reward, target) VALUES ('%s', '%s', '%s', '%s', '%s', %d, %d)" % [
			a["id"], a["name"], a["description"], a["icon"], a["category"], a["xp_reward"], a["target"]
		])

func unlock_achievement(achievement_id: String):
	db.query("UPDATE achievements SET is_unlocked = 1, unlocked_at = %d WHERE id = '%s'" % [Time.get_unix_time_from_system(), achievement_id])

func update_achievement_progress(achievement_id: String, progress: int):
	db.query("UPDATE achievements SET progress = %d WHERE id = '%s'" % [progress, achievement_id])

func get_unlocked_count() -> int:
	db.query("SELECT COUNT(*) as cnt FROM achievements WHERE is_unlocked = 1")
	return db.query_result[0]["cnt"] if db.query_result.size() > 0 else 0

# ── Workout Sessions ───────────────────────────────────────────────

func insert_session(session: Dictionary):
	var logs_json = JSON.stringify(session.get("exercise_logs", []))
	db.query("INSERT OR REPLACE INTO workout_sessions (id, routine_id, routine_name, start_time, end_time, date, exercise_logs, total_volume, calories_burned, notes) VALUES ('%s', '%s', '%s', %d, %d, %d, '%s', %f, %d, '%s')" % [
		session["id"], session.get("routine_id", ""), session.get("routine_name", ""),
		session.get("start_time", 0), session.get("end_time", 0),
		session.get("date", 0), logs_json.replace("'", "''"),
		session.get("total_volume", 0.0), session.get("calories_burned", 0),
		session.get("notes", "").replace("'", "''")
	])

func get_recent_sessions(limit: int = 50) -> Array:
	db.query("SELECT * FROM workout_sessions WHERE end_time > 0 ORDER BY date DESC LIMIT %d" % limit)
	return db.query_result

func get_sessions_for_exercise(exercise_name: String) -> Array:
	db.query("SELECT * FROM workout_sessions WHERE exercise_logs LIKE '%%%s%%' AND end_time > 0 ORDER BY date DESC" % exercise_name.replace("'", "''"))
	return db.query_result

# ── Routines ───────────────────────────────────────────────────────

func insert_routine(routine: Dictionary):
	var exercises_json = JSON.stringify(routine.get("exercises", []))
	db.query("INSERT OR REPLACE INTO routines (id, name, description, target_muscle_groups, estimated_duration, difficulty, is_ai_generated, created_at, exercises) VALUES ('%s', '%s', '%s', '%s', %d, '%s', %d, %d, '%s')" % [
		routine["id"], routine.get("name", "").replace("'", "''"),
		routine.get("description", "").replace("'", "''"),
		routine.get("target_muscle_groups", ""), routine.get("estimated_duration", 45),
		routine.get("difficulty", "beginner"), 1 if routine.get("is_ai_generated", false) else 0,
		routine.get("created_at", 0), exercises_json.replace("'", "''")
	])

func get_routines() -> Array:
	db.query("SELECT * FROM routines ORDER BY created_at DESC")
	return db.query_result

func get_routine(routine_id: String) -> Dictionary:
	db.query("SELECT * FROM routines WHERE id = '%s'" % routine_id)
	return db.query_result[0] if db.query_result.size() > 0 else {}

func delete_routine(routine_id: String):
	db.query("DELETE FROM routines WHERE id = '%s'" % routine_id)

# ── Settings ───────────────────────────────────────────────────────

func get_setting(key: String, default_value: String = "") -> String:
	db.query("SELECT value FROM settings WHERE key = '%s'" % key)
	if db.query_result.size() > 0:
		return db.query_result[0]["value"]
	return default_value

func set_setting(key: String, value: String):
	db.query("INSERT OR REPLACE INTO settings (key, value) VALUES ('%s', '%s')" % [key, value.replace("'", "''")])

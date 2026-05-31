## Gamification.gd — Pure calculation functions (stateless)
## Autoload singleton: Gamification
extends Node

# ── Player Stats Calculation ───────────────────────────────────────

func calculate_player_stats(profile: Dictionary, sessions: Array) -> Dictionary:
	var strength = clampi(int(profile.get("total_xp", 0) / 10000.0 * 100), 0, 100)
	
	var cardio_minutes = 0
	for session in sessions:
		var logs = JSON.parse_string(session.get("exercise_logs", "[]"))
		if logs == null: continue
		for log in logs:
			if log.get("exercise_type", "") in ["cardio", "duration"]:
				for set_log in log.get("set_logs", []):
					cardio_minutes += set_log.get("duration_seconds", 0) / 60
	
	var endurance = clampi(int(cardio_minutes / 500.0 * 100), 0, 100)
	
	var streak_score = clampi(int(profile.get("current_streak", 0) / 30.0 * 50), 0, 50)
	var completion_score = 50 if profile.get("total_workouts", 0) > 0 else 0
	var consistency = clampi(streak_score + completion_score, 0, 100)
	
	var distinct_types = []
	for session in sessions:
		var logs = JSON.parse_string(session.get("exercise_logs", "[]"))
		if logs == null: continue
		for log in logs:
			var t = log.get("exercise_type", "")
			if t != "" and t not in distinct_types:
				distinct_types.append(t)
	
	var versatility = clampi(int(distinct_types.size() / 5.0 * 100), 0, 100)
	var power_level = (strength + endurance + consistency + versatility) / 4
	
	return {
		"strength": strength,
		"endurance": endurance,
		"consistency": consistency,
		"versatility": versatility,
		"power_level": power_level
	}

# ── Boss Generation ────────────────────────────────────────────────

var boss_templates = [
	{"name": "The Deadlift Dragon", "desc": "A mighty dragon forged from iron and steel", "icon": "🐉"},
	{"name": "The Cardio Kraken", "desc": "A sea beast that tests your endurance to the limit", "icon": "🐙"},
	{"name": "The Plank Punisher", "desc": "An ancient guardian of core strength", "icon": "💀"},
	{"name": "The Squat Titan", "desc": "A colossus that demands lower body supremacy", "icon": "🗿"},
	{"name": "The Push-Up Phantom", "desc": "A shadow warrior of upper body mastery", "icon": "👻"},
	{"name": "The Burpee Berserker", "desc": "A chaotic force of full-body destruction", "icon": "🔥"},
	{"name": "The Pull-Up Phoenix", "desc": "Rises from the ashes with back-breaking power", "icon": "🦅"},
	{"name": "The HIIT Hydra", "desc": "Multiple heads, multiple rounds, no mercy", "icon": "🐍"},
]

func generate_boss(total_workouts: int, player_level: int) -> Dictionary:
	var boss_index = total_workouts / 10
	var template = boss_templates[boss_index % boss_templates.size()]
	
	var base_hp = 100 + (player_level * 20)
	var difficulty_multiplier = 1.0 + (boss_index / 8.0)
	var max_hp = int(base_hp * difficulty_multiplier)
	var xp_reward = 200 + (boss_index * 100)
	var exercise_count = 5 + mini(boss_index / 2, 5)
	
	var difficulty = "normal"
	if boss_index >= 6: difficulty = "legendary"
	elif boss_index >= 3: difficulty = "hard"
	
	return {
		"id": "boss_%d" % total_workouts,
		"name": template["name"],
		"description": template["desc"],
		"icon": template["icon"],
		"max_hp": max_hp,
		"current_hp": max_hp,
		"xp_reward": xp_reward,
		"difficulty": difficulty,
		"exercise_count": exercise_count
	}

# ── Weekly Challenge Generation ────────────────────────────────────

func generate_weekly_challenges(profile: Dictionary) -> Array:
	var challenges = []
	var tw = profile.get("total_workouts", 0)
	
	challenges.append({
		"id": "weekly_workouts",
		"name": "Complete 3 workouts this week",
		"description": "Complete 3 workouts this week",
		"target": 3,
		"progress": 0,
		"xp_reward": 100
	})
	
	challenges.append({
		"id": "weekly_cardio",
		"name": "Do a cardio workout",
		"description": "Do a cardio workout",
		"target": 1,
		"progress": 0,
		"xp_reward": 75
	})
	
	challenges.append({
		"id": "weekly_streak",
		"name": "Work out 4 days this week",
		"description": "Work out 4 days this week",
		"target": 4,
		"progress": 0,
		"xp_reward": 125
	})
	
	# Persist to database
	Database.save_weekly_challenges(challenges)
	return challenges

# ── Achievements ────────────────────────────────────────────────────

var achievement_definitions = [
	{"id": "first_workout", "name": "First Steps", "description": "Complete your first workout", "icon": "🏋️", "category": "milestone", "xp_reward": 50, "target": 1},
	{"id": "ten_workouts", "name": "Dedicated", "description": "Complete 10 workouts", "icon": "💪", "category": "milestone", "xp_reward": 100, "target": 10},
	{"id": "twenty-five_workouts", "name": "Iron Will", "description": "Complete 25 workouts", "icon": "🔥", "category": "milestone", "xp_reward": 200, "target": 25},
	{"id": "fifty_workouts", "name": "Half Century", "description": "Complete 50 workouts", "icon": "⚡", "category": "milestone", "xp_reward": 500, "target": 50},
	{"id": "hundred_workouts", "name": "Centurion", "description": "Complete 100 workouts", "icon": "👑", "category": "milestone", "xp_reward": 1000, "target": 100},
	{"id": "week_streak", "name": "Week Warrior", "description": "7-day workout streak", "icon": "📅", "category": "streak", "xp_reward": 100, "target": 7},
	{"id": "month_streak", "name": "Monthly Master", "description": "30-day workout streak", "icon": "🗓️", "category": "streak", "xp_reward": 500, "target": 30},
	{"id": "hundred_streak", "name": "Unstoppable", "description": "100-day workout streak", "icon": "💎", "category": "streak", "xp_reward": 2000, "target": 100},
	{"id": "volume_king", "name": "Volume King", "description": "Lift 100,000 total volume", "icon": "🏆", "category": "strength", "xp_reward": 300, "target": 100000},
	{"id": "pr_master", "name": "PR Master", "description": "Set 10 personal records", "icon": "📈", "category": "strength", "xp_reward": 250, "target": 10},
	{"id": "jack_of_trades", "name": "Jack of All Trades", "description": "Try all training types", "icon": "🃏", "category": "versatility", "xp_reward": 200, "target": 11},
	{"id": "equipment_explorer", "name": "Equipment Explorer", "description": "Use 5+ different equipment types", "icon": "🔧", "category": "versatility", "xp_reward": 150, "target": 5},
	{"id": "early_bird", "name": "Early Bird", "description": "Complete a workout before 7 AM", "icon": "🌅", "category": "special", "xp_reward": 75, "target": 1},
	{"id": "night_owl", "name": "Night Owl", "description": "Complete a workout after 10 PM", "icon": "🦉", "category": "special", "xp_reward": 75, "target": 1},
	{"id": "weekend_warrior", "name": "Weekend Warrior", "description": "Workout on both Saturday and Sunday", "icon": "⚔️", "category": "special", "xp_reward": 100, "target": 2},
	{"id": "perfect_week", "name": "Perfect Week", "description": "Hit all scheduled workouts in a week", "icon": "✨", "category": "special", "xp_reward": 150, "target": 1},
]

# ── Streak Management ──────────────────────────────────────────────

func get_streak_milestone_message(streak: int) -> String:
	var milestones = {
		3: "3 days! You're building momentum! 🔥",
		7: "One week strong! You're on fire! 🔥🔥",
		14: "Two weeks! You're becoming unstoppable! 💪",
		30: "30 days! Legendary dedication! ⚡",
		60: "60 days! You're a fitness titan! 🗿",
		100: "100 DAYS! ABSOLUTE LEGEND! 👑💎"
	}
	if streak in milestones:
		return milestones[streak]
	return ""

func handle_streak_update(profile: Dictionary) -> Dictionary:
	var last_workout = profile.get("last_workout_date", 0)
	var current_streak = profile.get("current_streak", 0)
	var longest_streak = profile.get("longest_streak", 0)
	var streak_freezes = profile.get("streak_freezes", 0)
	
	var now = Time.get_unix_time_from_system()
	var today = int(now / 86400)
	var last_day = int(last_workout / 86400)
	var days_diff = today - last_day
	
	if days_diff == 1:
		# Consecutive day
		current_streak += 1
	elif days_diff > 1:
		# Missed a day - check for streak freeze
		if days_diff == 2 and streak_freezes > 0:
			streak_freezes -= 1
			current_streak += 1 # Freeze used, streak continues
		else:
			current_streak = 1 # Reset streak
	
	# Award streak freeze every 7 days
	if current_streak > 0 and current_streak % 7 == 0 and days_diff == 1:
		streak_freezes += 1
	
	# Update longest streak
	if current_streak > longest_streak:
		longest_streak = current_streak
	
	# Check for milestone
	var milestone_msg = get_streak_milestone_message(current_streak)
	
	profile["current_streak"] = current_streak
	profile["longest_streak"] = longest_streak
	profile["streak_freezes"] = streak_freezes
	profile["last_workout_date"] = int(now)
	
	return {"profile": profile, "milestone_message": milestone_msg}

# ── Achievement Checking ───────────────────────────────────────────

func check_achievements(profile: Dictionary, session: Dictionary = {}) -> Array:
	var new_achievements = []
	var sessions = Database.get_recent_sessions(200)
	
	# Workout count achievements
	var total_workouts = profile.get("total_workouts", 0)
	for ach_id in ["first_workout", "ten_workouts", "twenty-five_workouts", "fifty_workouts", "hundred_workouts"]:
		var ach = Database._data["achievements"].get(ach_id, {})
		if not ach.get("is_unlocked", false):
			if total_workouts >= ach.get("target", 999999):
				Database.unlock_achievement(ach_id)
				new_achievements.append(ach_id)
	
	# Streak achievements
	var current_streak = profile.get("current_streak", 0)
	for ach_id in ["week_streak", "month_streak", "hundred_streak"]:
		var ach = Database._data["achievements"].get(ach_id, {})
		if not ach.get("is_unlocked", false):
			if current_streak >= ach.get("target", 999999):
				Database.unlock_achievement(ach_id)
				new_achievements.append(ach_id)
	
	# Volume King - 100k total volume
	var total_volume = 0.0
	for s in sessions:
		var logs = s.get("exercise_logs", [])
		if logs is String:
			logs = JSON.parse_string(logs) if logs else []
		for log in logs:
			for set_log in log.get("set_logs", []):
				total_volume += set_log.get("weight", 0.0) * set_log.get("reps", 0)
	Database.update_achievement_progress("volume_king", int(total_volume))
	if total_volume >= 100000 and not Database._data["achievements"].get("volume_king", {}).get("is_unlocked", false):
		Database.unlock_achievement("volume_king")
		new_achievements.append("volume_king")
	
	# PR Master - 10 personal records
	var bests = Database.get_personal_bests()
	var pr_count = bests.size()
	Database.update_achievement_progress("pr_master", pr_count)
	if pr_count >= 10 and not Database._data["achievements"].get("pr_master", {}).get("is_unlocked", false):
		Database.unlock_achievement("pr_master")
		new_achievements.append("pr_master")
	
	# Jack of All Trades - all training types
	var all_types = ["strength", "cardio", "hiit", "yoga", "flexibility", "calisthenics", "pilates", "powerlifting", "bodybuilding", "crossfit", "stretching"]
	var used_types = []
	for s in sessions:
		var logs = s.get("exercise_logs", [])
		if logs is String:
			logs = JSON.parse_string(logs) if logs else []
		for log in logs:
			var t = log.get("exercise_type", "")
			if t != "" and t not in used_types:
				used_types.append(t)
	Database.update_achievement_progress("jack_of_trades", used_types.size())
	if used_types.size() >= all_types.size() and not Database._data["achievements"].get("jack_of_trades", {}).get("is_unlocked", false):
		Database.unlock_achievement("jack_of_trades")
		new_achievements.append("jack_of_trades")
	
	# Equipment Explorer - use 5+ equipment types
	var used_equipment = []
	for s in sessions:
		var equip = s.get("equipment", "")
		if equip is String and equip != "":
			for e in equip.split(","):
				e = e.strip_edges()
				if e != "" and e not in used_equipment:
					used_equipment.append(e)
	Database.update_achievement_progress("equipment_explorer", used_equipment.size())
	if used_equipment.size() >= 5 and not Database._data["achievements"].get("equipment_explorer", {}).get("is_unlocked", false):
		Database.unlock_achievement("equipment_explorer")
		new_achievements.append("equipment_explorer")
	
	# Early Bird - workout before 7 AM
	if session.size() > 0:
		var session_time = session.get("date", 0)
		if session_time > 0:
			var dt = Time.get_datetime_dict_from_unix_time(session_time)
			var hour = dt.get("hour", 12)
			if hour < 7 and not Database._data["achievements"].get("early_bird", {}).get("is_unlocked", false):
				Database.unlock_achievement("early_bird")
				new_achievements.append("early_bird")
	
	# Night Owl - workout after 10 PM
	if session.size() > 0:
		var session_time = session.get("date", 0)
		if session_time > 0:
			var dt = Time.get_datetime_dict_from_unix_time(session_time)
			var hour = dt.get("hour", 0)
			if hour >= 22 and not Database._data["achievements"].get("night_owl", {}).get("is_unlocked", false):
				Database.unlock_achievement("night_owl")
				new_achievements.append("night_owl")
	
	# Weekend Warrior - Saturday and Sunday in same week
	if session.size() > 0:
		var session_time = session.get("date", 0)
		if session_time > 0:
			var dt = Time.get_datetime_dict_from_unix_time(session_time)
			var weekday = dt.get("weekday", 0) # 0=Sun, 6=Sat
			if weekday == 0 or weekday == 6:
				var week_start = session_time - (weekday * 86400)
				var has_saturday = false
				var has_sunday = false
				for s in sessions:
					var s_date = s.get("date", 0)
					if s_date >= week_start and s_date < week_start + 604800:
						var s_dt = Time.get_datetime_dict_from_unix_time(s_date)
						var s_weekday = s_dt.get("weekday", 0)
						if s_weekday == 0: has_sunday = true
						if s_weekday == 6: has_saturday = true
				if has_saturday and has_sunday and not Database._data["achievements"].get("weekend_warrior", {}).get("is_unlocked", false):
					Database.unlock_achievement("weekend_warrior")
					new_achievements.append("weekend_warrior")
	
	# Perfect Week - all scheduled workouts in a week
	var user_stats = Database.get_user_stats()
	var workouts_per_week = user_stats.get("workouts_per_week", 3)
	if session.size() > 0:
		var session_time = session.get("date", 0)
		if session_time > 0:
			var dt = Time.get_datetime_dict_from_unix_time(session_time)
			var weekday = dt.get("weekday", 0)
			var week_start = session_time - (weekday * 86400)
			var week_workouts = 0
			for s in sessions:
				var s_date = s.get("date", 0)
				if s_date >= week_start and s_date < week_start + 604800:
					week_workouts += 1
			if week_workouts >= workouts_per_week and not Database._data["achievements"].get("perfect_week", {}).get("is_unlocked", false):
				Database.unlock_achievement("perfect_week")
				new_achievements.append("perfect_week")
	
	return new_achievements

# ── Quest System ────────────────────────────────────────────────────

func assign_quest_from_routine(routine: Dictionary):
	var exercises = routine.get("exercises", [])
	if exercises is String:
		exercises = JSON.parse_string(exercises) if exercises else []
	if exercises.size() == 0:
		return
	
	var first_exercise = exercises[0]
	var quest_name = first_exercise.get("exercise_name", first_exercise.get("name", "Unknown Exercise"))
	var quest_flavor = "Complete %s to prove your might!" % quest_name
	
	Database.update_gamification_profile({
		"quest_name": quest_name,
		"quest_flavor": quest_flavor,
		"quest_completed": false
	})

func complete_quest():
	Database.update_gamification_profile({"quest_completed": true})

func get_current_quest() -> Dictionary:
	var profile = Database.get_gamification_profile()
	return {
		"quest_name": profile.get("quest_name", ""),
		"quest_flavor": profile.get("quest_flavor", ""),
		"quest_completed": profile.get("quest_completed", false)
	}

# ── Post-Workout Processing ───────────────────────────────────────

func process_workout_completion(session: Dictionary) -> Dictionary:
	var result = {
		"new_achievements": [],
		"streak_milestone": "",
		"xp_gained": 0
	}
	
	# Update streak
	var profile = Database.get_gamification_profile()
	var streak_result = handle_streak_update(profile)
	Database.update_gamification_profile(streak_result["profile"])
	result["streak_milestone"] = streak_result["milestone_message"]
	
	# Check achievements
	result["new_achievements"] = check_achievements(streak_result["profile"], session)
	
	# Update weekly challenges
	var session_type = session.get("session_type", "")
	if session_type != "":
		Database.update_weekly_challenge_progress(session_type)
	Database.update_weekly_challenge_progress("workouts")
	
	# Increment total workouts
	var total = streak_result["profile"].get("total_workouts", 0) + 1
	Database.update_gamification_profile({"total_workouts": total})
	
	return result

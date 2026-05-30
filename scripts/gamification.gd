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
		"description": "Complete 3 workouts this week",
		"target": 3,
		"progress": 0,
		"xp_reward": 100
	})
	
	challenges.append({
		"id": "weekly_cardio",
		"description": "Do a cardio workout",
		"target": 1,
		"progress": 0,
		"xp_reward": 75
	})
	
	challenges.append({
		"id": "weekly_streak",
		"description": "Work out 4 days this week",
		"target": 4,
		"progress": 0,
		"xp_reward": 125
	})
	
	return challenges

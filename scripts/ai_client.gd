## AIClient.gd — OpenRouter API wrapper
## Autoload singleton: AIClient
extends Node

signal workout_plan_generated(routines: Array)
signal ai_error(message: String)
signal coach_response(text: String)

var _http: HTTPRequest
var _api_key: String = ""
const BASE_URL = "https://openrouter.ai/api/v1"

func _ready():
	_http = HTTPRequest.new()
	_http.timeout = 120.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

var _current_request_type: String = ""

# ── Generate Workout Plan ──────────────────────────────────────────

func generate_workout_plan():
	_current_request_type = "generate_plan"
	
	var stats = GameManager.user_stats
	if stats.is_empty():
		ai_error.emit("Please save your profile first.")
		return
	
	var recent_sessions = Database.get_recent_sessions(5)
	var history_text = _build_history_text(recent_sessions)
	
	var system_prompt = _build_system_prompt(stats)
	var user_message = _build_plan_request(stats, history_text)
	
	var body = JSON.stringify({
		"model": "openrouter/auto",
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_message}
		],
		"max_tokens": 4096,
		"temperature": 0.7,
		"stream": false,
		"response_format": {"type": "json_object"}
	})
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _api_key,
		"HTTP-Referer: https://fitness-rpg.app",
		"X-Title: Fitness RPG"
	]
	
	_http.request(BASE_URL + "/chat/completions", headers, HTTPClient.METHOD_POST, body)

func _build_history_text(sessions: Array) -> String:
	if sessions.is_empty():
		return "\nNo recent workout history available. Start with conservative weights based on the user's profile."
	
	var text = "\nRecent workout history (last %d sessions):\n" % sessions.size()
	for session in sessions:
		var date_str = Time.get_date_string_from_unix_time(session.get("date", 0) * 86400)
		text += "- %s (%s):\n" % [session.get("routine_name", "Workout"), date_str]
		var logs = JSON.parse_string(session.get("exercise_logs", "[]"))
		if logs == null: continue
		for log in logs:
			var best_weight = 0.0
			var best_reps = 0
			for s in log.get("set_logs", []):
				if s.get("is_completed", false) and s.get("weight_kg", 0.0) > best_weight:
					best_weight = s["weight_kg"]
					best_reps = s.get("reps", 0)
			if best_weight > 0:
				text += "  %s: %.1fkg × %d reps\n" % [log.get("exercise_name", ""), best_weight, best_reps]
	return text

func _build_system_prompt(stats: Dictionary) -> String:
	return """You are an expert fitness trainer and program designer.

User profile:
- Name: %s
- Age: %d
- Weight: %.1f kg
- Height: %.1f cm
- Fitness goal: %s
- Activity level: %s
- Experience level: %s
- Workouts per week: %d
- Preferred duration: %d minutes
- Daily calories: %d kcal
- Daily protein: %dg
- Training types: %s
- Equipment: %s

Design a balanced, periodized workout program. Use progressive overload principles based on history.
If the user completed all reps at a weight, increase by 2.5-5kg. If they struggled, keep or reduce.
For new exercises, estimate starting weight based on the user's profile.""" % [
		stats.get("name", ""), stats.get("age", 0), stats.get("weight_kg", 0.0),
		stats.get("height_cm", 0.0), stats.get("fitness_goal", ""),
		stats.get("activity_level", ""), stats.get("experience_level", ""),
		stats.get("workouts_per_week", 3), stats.get("preferred_duration", 45),
		stats.get("daily_calories", 2000), stats.get("daily_protein", 150),
		stats.get("training_types", ""), stats.get("available_equipment", "")
	]

func _build_plan_request(stats: Dictionary, history: String) -> String:
	return """Generate a complete %d-day workout plan.
Return a JSON object with a "routines" key containing an array of routine objects.
Each routine: name, description, targetMuscleGroups, estimatedDuration (int, minutes), difficulty, exercises (array).
Each exercise: name, muscleGroup, equipment, sets (int), reps (string like "10-12"), restSeconds (int), notes, order (int), exerciseType (one of: strength, bodyweight, cardio, duration, stretch), targetWeight (number, kg, prescribed based on progressive overload), targetReps (number, target reps to hit).

%s""" % [stats.get("workouts_per_week", 3), history]

# ── Coach Chat ─────────────────────────────────────────────────────

var _chat_history: Array = []

func send_coach_message(user_text: String):
	_current_request_type = "coach"
	_chat_history.append({"role": "user", "content": user_text})
	
	var system_msg = {"role": "system", "content": "You are a knowledgeable and motivating fitness coach. Provide concise, actionable advice about workouts, nutrition, and recovery. Keep responses under 200 words unless asked for detail."}
	
	var messages = [system_msg] + _chat_history
	
	var body = JSON.stringify({
		"model": "openrouter/auto",
		"messages": messages,
		"max_tokens": 1024,
		"temperature": 0.8,
		"stream": false
	})
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _api_key,
		"HTTP-Referer: https://fitness-rpg.app",
		"X-Title: Fitness RPG"
	]
	
	_http.request(BASE_URL + "/chat/completions", headers, HTTPClient.METHOD_POST, body)

# ── Response Handler ───────────────────────────────────────────────

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		ai_error.emit("API Error %d: %s" % [response_code, error_text.substr(0, 200)])
		return
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		ai_error.emit("Failed to parse API response")
		return
	
	var data = json.data
	var content = data.get("choices", [{}])[0].get("message", {}).get("content", "")
	
	if _current_request_type == "generate_plan":
		_parse_workout_plan(content)
	elif _current_request_type == "coach":
		_chat_history.append({"role": "assistant", "content": content})
		coach_response.emit(content)

func _parse_workout_plan(content: String):
	var json = JSON.new()
	var cleaned = content.strip_edges()
	
	# Strip markdown code blocks
	if cleaned.begins_with("```"):
		var first_newline = cleaned.find("\n")
		if first_newline > 0:
			cleaned = cleaned.substr(first_newline + 1)
	if cleaned.ends_with("```"):
		cleaned = cleaned.substr(0, cleaned.length() - 3)
	cleaned = cleaned.strip_edges()
	
	var parse_result = json.parse(cleaned)
	if parse_result != OK:
		ai_error.emit("Failed to parse workout plan JSON")
		return
	
	var routines_data = json.data
	var routines_array = []
	
	if routines_data is Array:
		routines_array = routines_data
	elif routines_data is Dictionary:
		for key in ["routines", "plans", "workouts"]:
			if key in routines_data and routines_data[key] is Array:
				routines_array = routines_data[key]
				break
	
	var routines = []
	for r in routines_array:
		var exercises = []
		for e in r.get("exercises", []):
			exercises.append({
				"id": str(randi()),
				"name": e.get("name", ""),
				"muscleGroup": e.get("muscleGroup", ""),
				"equipment": e.get("equipment", ""),
				"sets": e.get("sets", 3),
				"reps": e.get("reps", "10-12"),
				"restSeconds": e.get("restSeconds", 60),
				"notes": e.get("notes", ""),
				"order": e.get("order", 0),
				"exerciseType": e.get("exerciseType", "strength"),
				"targetWeight": e.get("targetWeight", 0.0),
				"targetReps": e.get("targetReps", 0)
			})
		
		var routine = {
			"id": str(randi()),
			"name": r.get("name", "Workout"),
			"description": r.get("description", ""),
			"targetMuscleGroups": r.get("targetMuscleGroups", ""),
			"estimatedDuration": r.get("estimatedDuration", 45),
			"difficulty": r.get("difficulty", "beginner"),
			"is_ai_generated": true,
			"created_at": int(Time.get_unix_time_from_system()),
			"exercises": exercises
		}
		Database.insert_routine(routine)
		routines.append(routine)
	
	workout_plan_generated.emit(routines)

func set_api_key(key: String):
	_api_key = key

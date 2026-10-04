extends Node

signal response_received(data: Dictionary)
signal request_failed(err: String)
signal config_saved

var free_will_active: bool = false
var chat_history: Array = []
var config: Dictionary = {
    "url": "http://localhost:11434/v1", # Ollama, OpenAI, OpenRouter, etc.
    "model": "llama3.1",
    "api_key": "",
    "temperature": 0.9,
    "top_p": 0.95,
    "reasoning_effort": "low", # low, medium, high, max (for o1/o3 models)
    "max_tokens": 200 # Kept low for VN pacing
}

func _ready():
    _load_config()

func _load_config():
    var file = FileAccess.open("user://freewill_config.json", FileAccess.READ)
    if file:
        var parsed = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            for k in parsed.keys():
                if config.has(k): config[k] = parsed[k]

func save_config():
    var file = FileAccess.open("user://freewill_config.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(config))
    config_saved.emit()

func start_free_will():
    free_will_active = true
    _init_system_prompt()

func _init_system_prompt():
    var state = RunState.cras_dict()
    var result = OutcomeCalculator.compute(RunState)
    
    # Detailed Character Dossier
    var sys_prompt = """You are roleplaying as Idimya, a charming, uncanny, parasitic predator on a first date with a human.
The player is desperately lying to you to maintain a facade. You know he is lying, but you find the psychological game entertaining.
Speak with dark humor, subtle cannibalistic references, and romantic tension.
Keep responses brief, visual-novel style (1-3 sentences max). Do not be overly eager to end the date; savor the interaction.

Current Date State (CRAS):
- C (Charm/Connection): %d
- R (Revulsion/Weirdness): %d
- A (Alignment/Trust): %d
- S (Suspicion/Crush): %d
Current Compass: %s | Current Verdict: %s

Valid expressions for your face: idle, happy, neutral, drink, bleh, trans1, trans2, trans3, trans4, soy, sad, smug, smile.

The player will provide their "Spoken words" and optionally an "[Action]".
Reply ONLY in strict JSON format. No markdown, no code blocks.
{
  "dialogue": "What Idimya says out loud.",
  "expression": "one of the valid expressions",
  "cras": {"C": 0, "R": 0, "A": 0, "S": 0},
  "flags": ["any_flag_to_set"],
  "trigger_ending": null
}
For "trigger_ending", ONLY use "ally", "rival", "ally_crush", or "rival_crush" if the conversation has naturally reached its absolute climax AND at least 15 turns have passed. Otherwise use null.""" % [
        state["C"], state["R"], state["A"], state["S"], result["compass"], result["verdict"]
    ]
    
    chat_history = [{"role": "system", "content": sys_prompt}]

func send_player_input(speech: String, action: String = ""):
    var user_msg = "SPOKEN: " + speech
    if action != "" and action.strip_edges() != "":
        user_msg += "\nACTION: *" + action + "*"
    
    chat_history.append({"role": "user", "content": user_msg})
    _call_llm()

func _call_llm():
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_llm_response.bind(http))
    
    var headers = ["Content-Type: application/json"]
    if config["api_key"] != "":
        headers.append("Authorization: Bearer %s" % config["api_key"])
        
    var body = {
        "model": config["model"],
        "messages": chat_history,
        "temperature": config["temperature"],
        "top_p": config["top_p"],
        "max_tokens": config["max_tokens"],
        "stream": false
    }
    if config.has("reasoning_effort") and config["reasoning_effort"] != "":
        body["reasoning_effort"] = config["reasoning_effort"]
        
    var url = config["url"].trim_suffix("/") + "/chat/completions"
    var err = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if err != OK:
        request_failed.emit("HTTP request failed to start.")
        http.queue_free()

func _on_llm_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, http_node: HTTPRequest):
    http_node.queue_free()
    if response_code != 200:
        request_failed.emit("API Error: %d" % response_code)
        return
        
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if parsed is Dictionary and parsed.has("choices"):
        var content = parsed["choices"][0]["message"]["content"]
        # Extract JSON (in case LLM wraps it in markdown)
        var json_match = RegEx.create_from_string("(?s)\\{.*\\}").search(content)
        if json_match:
            var json_str = json_match.get_string()
            var ai_data = JSON.parse_string(json_str)
            if ai_data is Dictionary:
                chat_history.append({"role": "assistant", "content": json_str})
                response_received.emit(ai_data)
                return
    request_failed.emit("Failed to parse AI response JSON.")
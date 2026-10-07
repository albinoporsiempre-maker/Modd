extends Control

signal user_advanced
signal fast_forward_changed(active: bool)

var _free_will_ui: Control = null
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var continue_hint: Label = %ContinueHint
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var click_catcher: Control = %ClickCatcher
@onready var block: VBoxContainer = %Block
@onready var rule: ColorRect = %Rule

const NAMED_SPEAKERS: = {"idimya": "IDIMYA"}
const SKIP_HOLD_DELAY: = 3.0
const SKIP_INTERVAL: = 0.03
const CHOICES_BOTTOM_LIMIT: = 704.0
const CONFIRM_HOLD: = 0.1

const AUTO_CHOICE_DELAY: = 0.4

const CHOICE_HOLD_TIME: = 1.0
const CHOICE_HOLD_DELAY: = 0.15
const CHOICE_RETRACT: = 0.15

var _showing_choices: = false
var _dialogue_over: = false

var _auto_choice_line: = false

var _line_token: = 0

var _plain: = ""
var _typing: = false
var _revealed: = 0
var _type_progress: = 0.0
var _total: = 0

var _accept_was_down: = false
var _hold_time: = 0.0
var _skip_accum: = 0.0
var _ff_active: = false

var _choice_rows: Array = []
var _focused: = -1

var _choice_hold: = 0.0
var _choice_committing: = false
var _confirm_gate: = false

var _arrow_tween: Tween
var _hint_rest_y: = 0.0
var _hint_rest_set: = false
var _block_tween: Tween

var _hist: Array = []
var _review: = -1

const WHEEL_COOLDOWN_MS: = 90
var _last_wheel_ms: = 0

func _ready() -> void :
    add_to_group("dialogue_box")
    _apply_style()
    DialogueManager.line_shown.connect(_on_line_shown)
    DialogueManager.choices_shown.connect(_on_choices_shown)
    DialogueManager.run_ended.connect(_on_run_ended)
    DialogueManager.run_reset.connect(_on_run_reset)
    click_catcher.gui_input.connect(_on_click_catcher_input)
    click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
    move_child(click_catcher, -1)
    rule.color = UIStyle.RULE
    rule.visible = false
    continue_hint.visible = false
    _clear_choices()
    if AIManager:
        AIManager.response_received.connect(_on_ai_response)
        AIManager.request_failed.connect(_on_ai_failed)

func _apply_style() -> void :
    UIStyle.label_bold(speaker_label, UIStyle.SIZE_SPEAKER, UIStyle.TEXT_PRIMARY)
    UIStyle.rich_body(text_label, UIStyle.SIZE_DIALOGUE, UIStyle.TEXT_PRIMARY)
    UIStyle.label_body(continue_hint, 20, UIStyle.TEXT_SECONDARY)
    continue_hint.text = ""
    if not continue_hint.draw.is_connected(_draw_continue_arrow):
        continue_hint.draw.connect(_draw_continue_arrow)
    continue_hint.queue_redraw()

func _draw_continue_arrow() -> void :
    var s: = continue_hint.size
    var w: = 16.0
    var h: = 10.0
    var cx: = s.x * 0.5
    var top: = (s.y - h) * 0.5
    var pts: = PackedVector2Array([
        Vector2(cx - w * 0.5, top),
        Vector2(cx + w * 0.5, top),
        Vector2(cx, top + h),
    ])
    continue_hint.draw_colored_polygon(pts, UIStyle.TEXT_SECONDARY)

func _on_line_shown(speaker: String, text: String, is_last: bool) -> void :
    _showing_choices = false
    _dialogue_over = false
    _line_token += 1
    _auto_choice_line = is_last and \
        str(GameData.get_node_data(DialogueManager.current_id).get("kind", "")) == "choices"
    _clear_choices()
    rule.visible = false
    choices_box.modulate.a = 1.0
    _stop_arrow_bounce()
    continue_hint.visible = false
    _hist.append({"speaker": speaker, "text": text})
    _review = -1
    _render_line(speaker, text)
    _plain = text
    _total = text_label.get_total_character_count()
    _revealed = 0
    _type_progress = 0.0
    _typing = _total > 0
    text_label.visible_characters = 0
    if not _typing:
        _on_line_complete()

func _render_line(speaker: String, text: String) -> void :
    var key: = speaker.to_lower()
    if NAMED_SPEAKERS.has(key):
        speaker_label.visible = true
        speaker_label.text = NAMED_SPEAKERS[key]
        block.offset_top = UIStyle.DIALOGUE_TOP_IDIMYA
        text_label.text = "[center]%s[/center]" % text
    else:
        speaker_label.visible = false
        speaker_label.text = ""
        block.offset_top = UIStyle.DIALOGUE_TOP_YOU
        text_label.text = text
    block.offset_bottom = block.offset_top + 220.0
    _reset_block_pos()

func _on_line_complete() -> void :
    text_label.visible_characters = -1
    _typing = false
    if _showing_choices or _dialogue_over:
        return
    if _auto_choice_line and not DialogueManager._advance_locked:
        _schedule_auto_choice()
    else:
        _start_arrow_bounce()

func _schedule_auto_choice() -> void :
    var tok: = _line_token
    await get_tree().create_timer(AUTO_CHOICE_DELAY).timeout
    if tok != _line_token or _showing_choices or _dialogue_over or _typing or _review != -1:
        return
    if DialogueManager._advance_locked:
        _start_arrow_bounce()
        return
    DialogueManager.advance()

func _complete_typing() -> void :
    _revealed = _total
    text_label.visible_characters = -1
    _on_line_complete()

func _char_cost(i: int) -> float:
    if i < 0 or i >= _plain.length():
        return 1.0
    var ch: = _plain[i]
    if ch == "." or ch == "…":
        return UIStyle.TYPE_DOT_MULT
    if ch == "," or ch == "!" or ch == "?" or ch == ";" or ch == ":" or ch == "-":
        return UIStyle.TYPE_PUNCT_MULT
    return 1.0

func _on_choices_shown(choices: Array) -> void :
    _showing_choices = true
    _dialogue_over = false
    _typing = false
    text_label.visible_characters = -1
    _stop_arrow_bounce()
    continue_hint.visible = false
    rule.visible = true
    _clear_choices()
    _choice_hold = 0.0
    _choice_committing = false

    if AIManager and AIManager.free_will_active:
        show_free_will_ui()
        return

    for choice in choices:
        var row: = ChoiceRow.new()
        choices_box.add_child(row)
        row.setup(0, choice["label"], choice["id"])
        row.set_hold_mode(true)
        _choice_rows.append(row)

    choices_box.modulate.a = 0.0
    var line_top: = block.offset_top
    await get_tree().process_frame
    var h: = block.get_combined_minimum_size().y
    var fit_top: = clampf(CHOICES_BOTTOM_LIMIT - h, 40.0, line_top)
    block.offset_top = fit_top
    block.offset_bottom = fit_top + h
    var start_y: = maxf(line_top, fit_top + 26.0)
    block.position.y = start_y
    if _block_tween and _block_tween.is_valid():
        _block_tween.kill()
    _block_tween = create_tween().set_parallel(true)
    _block_tween.tween_property(block, "position:y", fit_top, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    _block_tween.tween_property(choices_box, "modulate:a", 1.0, 0.24)
    _focused = -1
    _set_focus(0, false)
    _confirm_gate = _any_confirm_down()

func _set_focus(i: int, play_sound: bool = true) -> void :
    if _choice_rows.is_empty():
        return
    i = clampi(i, 0, _choice_rows.size() - 1)
    if i == _focused:
        return
    if _focused >= 0 and _focused < _choice_rows.size():
        _choice_rows[_focused].set_marked(false)
        _choice_rows[_focused].retract(CHOICE_RETRACT)
    _choice_hold = 0.0
    _focused = i
    _choice_rows[i].set_marked(true)
    if play_sound:
        Sfx.play("choice_navigate")

func _any_confirm_down() -> bool:
    return Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _apply_choice_hold_visual() -> void :
    if _focused < 0 or _focused >= _choice_rows.size():
        return
    var vis: = clampf((_choice_hold - CHOICE_HOLD_DELAY) / (CHOICE_HOLD_TIME - CHOICE_HOLD_DELAY), 0.0, 1.0)
    _choice_rows[_focused].set_hold_progress(vis)

func _cancel_choice_hold() -> void :
    _choice_hold = 0.0
    if _focused >= 0 and _focused < _choice_rows.size():
        _choice_rows[_focused].retract(CHOICE_RETRACT)

func _commit_choice_hold() -> void :
    if _choice_committing or not _showing_choices:
        return
    if _focused < 0 or _focused >= _choice_rows.size():
        return
    _choice_committing = true
    _showing_choices = false
    _choice_hold = 0.0
    _choice_rows[_focused].set_hold_progress(1.0)
    Sfx.play("choice_confirm")
    var id: String = _choice_rows[_focused].child_id
    rule.visible = false
    await get_tree().create_timer(CONFIRM_HOLD).timeout
    _focused = -1
    _clear_choices()
    _hist.clear()
    _review = -1
    DialogueManager.choose(id)

func _on_run_ended(_kind: String, _info: Dictionary) -> void :
    _dialogue_over = true
    _showing_choices = false
    _typing = false
    _stop_arrow_bounce()
    continue_hint.visible = false

func _process(delta: float) -> void :
    if _typing and _review == -1 and is_visible_in_tree():
        _type_progress += delta * UIStyle.TYPE_CPS
        while _revealed < _total and _type_progress >= _char_cost(_revealed):
            _type_progress -= _char_cost(_revealed)
            _revealed += 1
        text_label.visible_characters = _revealed
        if _revealed >= _total:
            _on_line_complete()

    var down: = Input.is_action_pressed("ui_accept")

    if _review != -1:
        if down and not _accept_was_down:
            _exit_review()
        _accept_was_down = down
        _hold_time = 0.0
        _skip_accum = 0.0
        _set_ff(false)
        return

    if _dialogue_over:
        _set_ff(false)
        _accept_was_down = down
        return

    if _showing_choices:
        _set_ff(false)
        _hold_time = 0.0
        _skip_accum = 0.0
        _accept_was_down = down
        var cdown: = _any_confirm_down()
        if delta > 0.25:
            _cancel_choice_hold()
            return
        if _choice_committing:
            return
        if _confirm_gate:
            if not cdown:
                _confirm_gate = false
            return
        if cdown:
            _choice_hold += delta
            _apply_choice_hold_visual()
            if _choice_hold >= CHOICE_HOLD_TIME:
                _commit_choice_hold()
        elif _choice_hold > 0.0:
            _cancel_choice_hold()
        return

    if down and not _accept_was_down:
        if is_visible_in_tree():
            _try_advance()
        _hold_time = 0.0
        _skip_accum = 0.0
    elif down:
        _hold_time += delta
        if _hold_time >= SKIP_HOLD_DELAY:
            _set_ff(true)
            _skip_accum += delta
            while _skip_accum >= SKIP_INTERVAL:
                _skip_accum -= SKIP_INTERVAL
                _skip_step()
                if _showing_choices or _dialogue_over:
                    break
    else:
        _hold_time = 0.0
        _skip_accum = 0.0
        _set_ff(false)

    _accept_was_down = down

func _skip_step() -> void :
    if _typing:
        _complete_typing()
        return
    if DialogueManager._advance_locked:
        user_advanced.emit()
        return
    DialogueManager.advance()

func _set_ff(v: bool) -> void :
    if _ff_active == v:
        return
    _ff_active = v
    fast_forward_changed.emit(v)

func _try_advance() -> void :
    if _typing:
        _complete_typing()
        return
    user_advanced.emit()
    DialogueManager.advance()

func _on_click_catcher_input(event: InputEvent) -> void :
    if _dialogue_over:
        return
    if not is_visible_in_tree():
        return
    if _review != -1:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _exit_review()
        return
    if _showing_choices:
        pass
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _try_advance()

func _input(event: InputEvent) -> void :
    if event is InputEventMouseButton and event.pressed:
        var mb: = event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            get_viewport().set_input_as_handled()
            var now: = Time.get_ticks_msec()
            if now - _last_wheel_ms < WHEEL_COOLDOWN_MS:
                return
            _last_wheel_ms = now
            var up: = mb.button_index == MOUSE_BUTTON_WHEEL_UP
            if _showing_choices and _review == -1:
                _set_focus(_focused + (-1 if up else 1))
            else:
                _review_step(-1 if up else 1)
            return
    if _review != -1:
        return
    if not _showing_choices:
        return
    if not (event is InputEventKey and event.pressed and not event.echo):
        return
    if event.is_action("ui_up"):
        _set_focus(_focused - 1)
    elif event.is_action("ui_down"):
        _set_focus(_focused + 1)
    elif not event.is_action("ui_accept"):
        var n: = _digit_pressed(event)
        if n >= 1 and n <= _choice_rows.size():
            _set_focus(n - 1)

func _digit_pressed(event: InputEventKey) -> int:
    var kc: = event.keycode
    if kc >= KEY_1 and kc <= KEY_9:
        return kc - KEY_1 + 1
    if kc >= KEY_KP_1 and kc <= KEY_KP_9:
        return kc - KEY_KP_1 + 1
    return -1

func _review_step(dir: int) -> void :
    if _dialogue_over or not is_visible_in_tree():
        return
    if _hist.size() < 2:
        return
    if dir < 0:
        var target: = (_hist.size() - 2) if _review == -1 else (_review - 1)
        if target < 0:
            return
        if _review == -1 and _typing:
            _typing = false
            _revealed = _total
            text_label.visible_characters = -1
        _review = target
        _show_review_line(_hist[_review])
    else:
        if _review == -1:
            return
        var t: = _review + 1
        if t >= _hist.size() - 1:
            _exit_review()
        else:
            _review = t
            _show_review_line(_hist[_review])

func _show_review_line(entry: Dictionary) -> void :
    _stop_arrow_bounce()
    continue_hint.visible = false
    _render_line(str(entry.get("speaker", "")), str(entry.get("text", "")))
    text_label.visible_characters = -1

func _exit_review() -> void :
    if _review == -1:
        return
    _review = -1
    var live: Dictionary = _hist[_hist.size() - 1]
    _render_line(str(live.get("speaker", "")), str(live.get("text", "")))
    text_label.visible_characters = -1
    _revealed = _total
    _typing = false
    _on_line_complete()

func _on_run_reset() -> void :
    _hist.clear()
    _review = -1

func _reset_block_pos() -> void :
    if _block_tween and _block_tween.is_valid():
        _block_tween.kill()
    block.position.y = block.offset_top

func _start_arrow_bounce() -> void :
    continue_hint.visible = true
    continue_hint.queue_redraw()
    _stop_arrow_bounce()
    if not _hint_rest_set:
        _hint_rest_y = continue_hint.position.y
        _hint_rest_set = true
    continue_hint.position.y = _hint_rest_y
    _arrow_tween = create_tween().set_loops()
    _arrow_tween.tween_property(continue_hint, "position:y", _hint_rest_y - 6.0, 0.35)\
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    _arrow_tween.tween_property(continue_hint, "position:y", _hint_rest_y, 0.35)\
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_arrow_bounce() -> void :
    if _arrow_tween and _arrow_tween.is_valid():
        _arrow_tween.kill()
    if _hint_rest_set:
        continue_hint.position.y = _hint_rest_y

func _clear_choices() -> void :
    for c in choices_box.get_children():
        c.queue_free()
    _choice_rows.clear()
    _focused = -1
    _choice_hold = 0.0
    _confirm_gate = false

func show_free_will_ui() -> void :
    _showing_choices = true
    if not _free_will_ui:
        var FWI = load("res://ui/FreeWillInput.gd")
        _free_will_ui = FWI.new()
        add_child(_free_will_ui)
        _free_will_ui.submit.connect(_on_free_will_submit)
    _free_will_ui.visible = true
    _free_will_ui.reset_and_focus()

func _on_free_will_submit(speech: String, action: String) -> void :
    _free_will_ui.visible = false
    DialogueManager.set_advance_locked(true)
    AIManager.send_player_input(speech, action)

func _on_ai_response(data: Dictionary) -> void :
    DialogueManager.set_advance_locked(false)
    if data.has("cras"):
        RunState.apply_cras(data["cras"])
    if data.has("flags"):
        for f in data["flags"]:
            RunState.set_flag(str(f))
    if data.has("trigger_ending") and data["trigger_ending"] != null and str(data["trigger_ending"]) != "":
        if AIManager.chat_history.size() >= 15:
            AIManager.free_will_active = false
            DialogueManager.enter("ending_" + str(data["trigger_ending"]))
            return
    if data.has("expression"):
        var date_scene = get_tree().get_first_node_in_group("main_date")
        if date_scene and date_scene.has_method("set_idimya_pose"):
            date_scene.set_idimya_pose(str(data["expression"]))
    var say_text = str(data.get("dialogue", "..."))
    _hist.append({"speaker": "idimya", "text": say_text})
    _render_line("idimya", say_text)
    _plain = say_text
    _total = text_label.get_total_character_count()
    _revealed = 0
    _type_progress = 0.0
    _typing = _total > 0
    text_label.visible_characters = 0
    if not _typing:
        _on_line_complete()

func _on_ai_failed(err: String) -> void :
    DialogueManager.set_advance_locked(false)
    push_error("AI Request Failed: " + err)
    show_free_will_ui()
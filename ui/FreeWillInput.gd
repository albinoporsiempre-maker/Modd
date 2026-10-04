extends Control
signal submit(speech: String, action: String)

var speech_edit: LineEdit
var action_edit: LineEdit
var action_toggle_btn: Button
var send_btn: Button
var action_container: VBoxContainer

func _ready():
    # We build the UI in code so you don't need to mess with .tscn files
    var main_vbox = VBoxContainer.new()
    main_vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    main_vbox.offset_top = -160
    main_vbox.offset_bottom = -20
    main_vbox.add_theme_constant_override("separation", 8)
    add_child(main_vbox)
    
    # Action container (hidden by default)
    action_container = VBoxContainer.new()
    var action_label = Label.new()
    action_label.text = "Action (e.g., 'I look away nervously'):"
    action_container.add_child(action_label)
    action_edit = LineEdit.new()
    action_edit.placeholder_text = "*Action...*"
    action_container.add_child(action_edit)
    action_container.visible = false
    main_vbox.add_child(action_container)
    
    # Speech input
    var speech_label = Label.new()
    speech_label.text = "Speak:"
    main_vbox.add_child(speech_label)
    speech_edit = LineEdit.new()
    speech_edit.placeholder_text = "Type your lie..."
    speech_edit.text_submitted.connect(_on_submit)
    main_vbox.add_child(speech_edit)
    
    # Buttons row
    var btn_hbox = HBoxContainer.new()
    main_vbox.add_child(btn_hbox)
    
    action_toggle_btn = Button.new()
    action_toggle_btn.text = "Show Action ▼"
    action_toggle_btn.pressed.connect(_toggle_action)
    btn_hbox.add_child(action_toggle_btn)
    
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn_hbox.add_child(spacer)
    
    send_btn = Button.new()
    send_btn.text = "Send"
    send_btn.pressed.connect(_on_submit)
    btn_hbox.add_child(send_btn)
    
    speech_edit.grab_focus()

func _toggle_action():
    action_container.visible = !action_container.visible
    action_toggle_btn.text = "Hide Action ▲" if action_container.visible else "Show Action ▼"
    if action_container.visible:
        action_edit.grab_focus()
    else:
        speech_edit.grab_focus()

func _on_submit(_text = ""):
    var s = speech_edit.text.strip_edges()
    if s == "": return
    var a = action_edit.text.strip_edges()
    submit.emit(s, a)
    speech_edit.text = ""
    action_edit.text = ""
    speech_edit.grab_focus()

func reset_and_focus():
    speech_edit.text = ""
    action_edit.text = ""
    if action_container.visible:
        action_edit.grab_focus()
    else:
        speech_edit.grab_focus()
extends Control

var config_panel: PanelContainer
var url_edit: LineEdit
var model_edit: LineEdit
var key_edit: LineEdit
var temp_spin: SpinBox
var top_p_spin: SpinBox
var effort_option: OptionButton

func _ready():
    build_ui()

func build_ui():
    var vbox = VBoxContainer.new()
    vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    vbox.add_theme_constant_override("separation", 20)
    add_child(vbox)

    var title = Label.new()
    title.text = "I CAN SMELL YOU FROM HERE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)

    var normal_btn = Button.new()
    normal_btn.text = "Normal Mode"
    normal_btn.pressed.connect(_start_normal)
    vbox.add_child(normal_btn)

    var free_btn = Button.new()
    free_btn.text = "Free Will Mode (AI)"
    free_btn.pressed.connect(_show_config)
    vbox.add_child(free_btn)

    build_config_panel(vbox)

func _start_normal():
    AIManager.free_will_active = false
    get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _show_config():
    config_panel.visible = true

func build_config_panel(parent: VBoxContainer):
    config_panel = PanelContainer.new()
    config_panel.visible = false
    parent.add_child(config_panel)

    var cvbox = VBoxContainer.new()
    cvbox.add_theme_constant_override("separation", 10)
    config_panel.add_child(cvbox)

    var lbl = Label.new()
    lbl.text = "AI Configuration (OpenAI Compatible)"
    cvbox.add_child(lbl)

    url_edit = LineEdit.new()
    url_edit.placeholder_text = "URL (e.g. http://localhost:11434/v1)"
    url_edit.text = AIManager.config["url"]
    cvbox.add_child(url_edit)

    model_edit = LineEdit.new()
    model_edit.placeholder_text = "Model Name"
    model_edit.text = AIManager.config["model"]
    cvbox.add_child(model_edit)

    key_edit = LineEdit.new()
    key_edit.placeholder_text = "API Key (if required)"
    key_edit.secret = true
    key_edit.text = AIManager.config["api_key"]
    cvbox.add_child(key_edit)

    var hbox1 = HBoxContainer.new()
    cvbox.add_child(hbox1)
    hbox1.add_child(Label.new("Temp:"))
    temp_spin = SpinBox.new()
    temp_spin.min_value = 0.0; temp_spin.max_value = 2.0; temp_spin.step = 0.1
    temp_spin.value = AIManager.config["temperature"]
    hbox1.add_child(temp_spin)

    hbox1.add_child(Label.new("Top P:"))
    top_p_spin = SpinBox.new()
    top_p_spin.min_value = 0.0; top_p_spin.max_value = 1.0; top_p_spin.step = 0.05
    top_p_spin.value = AIManager.config["top_p"]
    hbox1.add_child(top_p_spin)

    hbox1.add_child(Label.new("Reasoning:"))
    effort_option = OptionButton.new()
    effort_option.add_item("low")
    effort_option.add_item("medium")
    effort_option.add_item("high")
    effort_option.add_item("max")
    effort_option.select(["low", "medium", "high", "max"].find(AIManager.config["reasoning_effort"]))
    hbox1.add_child(effort_option)

    var start_btn = Button.new()
    start_btn.text = "Save & Start Free Will"
    start_btn.pressed.connect(_start_free_will)
    cvbox.add_child(start_btn)

func _start_free_will():
    AIManager.config["url"] = url_edit.text
    AIManager.config["model"] = model_edit.text
    AIManager.config["api_key"] = key_edit.text
    AIManager.config["temperature"] = temp_spin.value
    AIManager.config["top_p"] = top_p_spin.value
    AIManager.config["reasoning_effort"] = effort_option.get_item_text(effort_option.selected)
    AIManager.save_config()
    
    AIManager.start_free_will()
    get_tree().change_scene_to_file("res://scenes/Main.tscn")
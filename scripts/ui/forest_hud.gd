extends CanvasLayer

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var counter: Label
var objective: Label
var hint: Label
var toast: Label
var toast_clock := 0.0
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var finished := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build_hud()

func _process(delta: float) -> void:
	if toast_clock > 0.0:
		toast_clock -= delta
		toast.modulate.a = clampf(toast_clock, 0.0, 1.0)
	else:
		toast.visible = false

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(22, 20)
	top.custom_minimum_size = Vector2(330, 104)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color("080e12", 0.72)
	top_style.border_color = Color("c9b58f", 0.32)
	top_style.border_width_left = 2
	top_style.content_margin_left = 16
	top_style.content_margin_right = 16
	top_style.content_margin_top = 11
	top_style.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel", top_style)
	root.add_child(top)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	top.add_child(stack)
	counter = Label.new()
	counter.text = "ЛИСТЫ: 0 / 18"
	counter.add_theme_font_size_override("font_size", 19)
	counter.add_theme_color_override("font_color", Color("f0d6a5"))
	stack.add_child(counter)
	objective = Label.new()
	objective.text = "Найди 18 записок на деревьях."
	objective.add_theme_font_size_override("font_size", 14)
	objective.add_theme_color_override("font_color", Color("e5e2d8"))
	stack.add_child(objective)
	var center_mark := Label.new()
	center_mark.text = "+"
	center_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center_mark.position = Vector2(-5, -8)
	center_mark.add_theme_font_size_override("font_size", 17)
	center_mark.add_theme_color_override("font_color", Color("eadbbd", 0.6))
	root.add_child(center_mark)
	hint = Label.new()
	hint.text = "WASD — идти   ·   Shift — бежать   ·   E — лист   ·   Esc — пауза"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 20
	hint.offset_right = -20
	hint.offset_top = -42
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("e4e0d5", 0.82))
	root.add_child(hint)
	toast = Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-360, 136)
	toast.custom_minimum_size = Vector2(720, 68)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_font_size_override("font_size", 22)
	toast.add_theme_color_override("font_color", Color("f1e7d2"))
	toast.visible = false
	root.add_child(toast)
	_build_overlay(root)

func _build_overlay(root: Control) -> void:
	overlay = ColorRect.new()
	overlay.color = Color("020507", 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(490, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10171a", 0.98)
	style.border_color = Color("d1ac72", 0.72)
	style.set_border_width_all(1)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 26
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	panel.add_child(column)
	overlay_title = Label.new()
	overlay_title.text = "ПАУЗА"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 32)
	overlay_title.add_theme_color_override("font_color", Color("e4bc7e"))
	column.add_child(overlay_title)
	overlay_body = Label.new()
	overlay_body.text = "Лес не изменится, пока ты переводишь дыхание."
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_body.add_theme_font_size_override("font_size", 16)
	overlay_body.add_theme_color_override("font_color", Color("e4e0d7"))
	column.add_child(overlay_body)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	column.add_child(spacer)
	overlay_button = Button.new()
	overlay_button.custom_minimum_size = Vector2(0, 48)
	overlay_button.add_theme_font_size_override("font_size", 16)
	overlay_button.pressed.connect(_overlay_action)
	column.add_child(overlay_button)

func update_progress(count: int, nearby_note: bool, at_exit: bool, partner_near: bool) -> void:
	counter.text = "ЛИСТЫ: %d / 18" % count
	if nearby_note:
		hint.text = "E — снять лист с дерева"
	elif count < 18:
		hint.text = "Ищи бледные листы в пятне фонаря. Юна не отстаёт."
	elif not at_exit:
		hint.text = "Все листы собраны. Иди к огню у старой вышки."
	elif not partner_near:
		hint.text = "Подожди Юну у фонаря — вы должны выбраться вместе."
	else:
		hint.text = "Выход рядом. Подойди к Юне и держись света."
	objective.text = "Найди 18 записок на деревьях." if count < 18 else "Доберитесь до вышки вместе."

func show_toast(message: String, duration := 4.0) -> void:
	toast.text = message
	toast.visible = true
	toast.modulate.a = 1.0
	toast_clock = duration

func show_pause() -> void:
	if finished:
		return
	overlay_title.text = "ПАУЗА"
	overlay_body.text = "В тумане всё ещё слышны шаги."
	overlay_button.text = "ПРОДОЛЖИТЬ"
	overlay.visible = true
	overlay_button.grab_focus()

func show_victory() -> void:
	finished = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay_title.text = "ВЫ ВЫБРАЛИСЬ"
	overlay_body.text = "Юна держится рядом. За спиной лес снова поглотил дорогу."
	overlay_button.text = "В ГЛАВНОЕ МЕНЮ"
	overlay.visible = true
	overlay_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and not finished and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_resume()

func _overlay_action() -> void:
	if finished:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		_resume()

func _resume() -> void:
	overlay.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

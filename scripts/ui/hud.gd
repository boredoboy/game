extends CanvasLayer

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const ARENA_SCENE := "res://scenes/levels/arena.tscn"

var player: Node
var root: Control
var health_bar: ProgressBar
var health_value: Label
var ammo_value: Label
var reserve_value: Label
var reload_text: Label
var wave_value: Label
var kills_value: Label
var score_value: Label
var hit_marker: Label
var flash: ColorRect
var modal: Control
var modal_title: Label
var modal_description: Label
var modal_buttons: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build_hud()
	GameManager.stats_changed.connect(_on_stats_changed)
	GameManager.wave_changed.connect(_on_wave_changed)

func setup(player_node: Node) -> void:
	player = player_node
	player.connect("health_changed", _on_health_changed)
	player.connect("ammo_changed", _on_ammo_changed)
	player.connect("hit_confirm", _on_hit_confirm)
	_on_health_changed(float(player.get("health")))
	_on_ammo_changed(int(player.get("magazine")), int(player.get("reserve_ammo")), false)

func set_wave(value: int) -> void:
	wave_value.text = "%02d" % value

func show_pause() -> void:
	_show_modal("ПАУЗА", "СЕКТОР 07  /  СИГНАЛ СОХРАНЁН", false)

func show_game_over() -> void:
	_show_modal("СИГНАЛ ПОТЕРЯН", "ВОЛНА %02d     ·     УБИЙСТВА %03d     ·     СЧЁТ %05d" % [GameManager.current_wave, GameManager.kills, GameManager.score], true)

func _build_hud() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 30
	top.offset_top = 22
	top.offset_right = -30
	top.offset_bottom = 64
	top.add_theme_constant_override("separation", 36)
	root.add_child(top)
	var logo := _label("DEAD RADIO  /  04:17 AM", 17, Color("e6b871"))
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(logo)
	var wave_column := VBoxContainer.new()
	wave_column.alignment = BoxContainer.ALIGNMENT_CENTER
	var wave_caption := _label("ВОЛНА", 11, Color("c8c4ba"))
	wave_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_column.add_child(wave_caption)
	wave_value = _label("01", 27, Color("f2eee5"))
	wave_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_column.add_child(wave_value)
	top.add_child(wave_column)
	var stats := VBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	kills_value = _label("УБИЙСТВА  000", 14, Color("e9e5dc"))
	score_value = _label("СЧЁТ  00000", 14, Color("e9e5dc"))
	kills_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(kills_value)
	stats.add_child(score_value)
	top.add_child(stats)
	var cross := Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-8, -8)
	cross.custom_minimum_size = Vector2(16, 16)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	for spec in [[Vector2(7, 0), Vector2(2, 6)], [Vector2(7, 10), Vector2(2, 6)], [Vector2(0, 7), Vector2(6, 2)], [Vector2(10, 7), Vector2(6, 2)]]:
		var mark := ColorRect.new()
		mark.position = spec[0]
		mark.size = spec[1]
		mark.color = Color("f5edda", 0.88)
		cross.add_child(mark)
	hit_marker = _label("×", 25, Color("f6c475"))
	hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	hit_marker.position = Vector2(-7, -17)
	hit_marker.custom_minimum_size = Vector2(20, 22)
	hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker.modulate.a = 0.0
	root.add_child(hit_marker)
	flash = ColorRect.new()
	flash.color = Color("a8241c", 0.0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 32
	bottom.offset_top = -86
	bottom.offset_right = -32
	bottom.offset_bottom = -22
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	var health_column := VBoxContainer.new()
	health_column.custom_minimum_size.x = 250
	var health_row := HBoxContainer.new()
	health_value = _label("♥  100", 17, Color("f0806b"))
	var health_caption := _label("ЗДОРОВЬЕ", 13, Color("e2ded6"))
	health_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(health_value)
	health_row.add_child(health_caption)
	health_column.add_child(health_row)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 7
	health_bar.show_percentage = false
	health_bar.max_value = 100
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color("d3d5d1", 0.2)
	health_bar.add_theme_stylebox_override("background", bar_background)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("da6054")
	health_bar.add_theme_stylebox_override("fill", bar_fill)
	health_column.add_child(health_bar)
	bottom.add_child(health_column)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(stretch)
	var ammo_column := VBoxContainer.new()
	ammo_column.alignment = BoxContainer.ALIGNMENT_END
	ammo_column.custom_minimum_size.x = 225
	reload_text = _label("ПАТРОНЫ  /  АВТОМАТ", 11, Color("c8c4ba"))
	reload_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_column.add_child(reload_text)
	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	ammo_value = _label("30", 39, Color("f2eee5"))
	reserve_value = _label("/ 180", 18, Color("c8c4ba"))
	reserve_value.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ammo_row.add_child(ammo_value)
	ammo_row.add_child(reserve_value)
	ammo_column.add_child(ammo_row)
	bottom.add_child(ammo_column)
	var hint := _label("WASD ДВИЖЕНИЕ   ·   SHIFT БЕГ   ·   R ПЕРЕЗАРЯДКА   ·   ESC ПАУЗА", 11, Color("e3ded4", 0.72))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-230, -14)
	hint.custom_minimum_size = Vector2(460, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)
	_build_modal()

func _build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.visible = false
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color("090e11", 0.79)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("11191d", 0.98)
	style.border_color = Color("bd935b", 0.72)
	style.set_border_width_all(1)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	modal_title = _label("ПАУЗА", 33, Color("e7b66d"))
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(modal_title)
	modal_description = _label("СЕКТОР 07", 13, Color("d1d0c9"))
	modal_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(modal_description)
	modal_buttons = VBoxContainer.new()
	modal_buttons.add_theme_constant_override("separation", 9)
	column.add_child(modal_buttons)

func _show_modal(title: String, description: String, game_over: bool) -> void:
	modal.visible = true
	modal_title.text = title
	modal_description.text = description
	for child in modal_buttons.get_children():
		child.queue_free()
	if game_over:
		_add_modal_button("НОВЫЙ ЗАБЕГ", func(): _restart())
	else:
		_add_modal_button("ПРОДОЛЖИТЬ", func(): _resume())
	_add_modal_button("ГЛАВНОЕ МЕНЮ", func(): _go_to_menu())

func _add_modal_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("283438")
	style.border_color = Color("c59b61", 0.62)
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("3d4b4d")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", Color("f2eee5"))
	button.pressed.connect(action)
	modal_buttons.add_child(button)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("000000", 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _on_health_changed(value: float) -> void:
	health_bar.value = value
	health_value.text = "♥  %03d" % int(ceil(value))
	if value <= 30.0:
		flash.color = Color("a8241c", 0.17)
		var tween := create_tween()
		tween.tween_property(flash, "color:a", 0.0, 0.32)

func _on_ammo_changed(magazine: int, reserve: int, is_reloading: bool) -> void:
	ammo_value.text = "%02d" % magazine
	reserve_value.text = "/ %03d" % reserve
	reload_text.text = "ПЕРЕЗАРЯДКА..." if is_reloading else "ПАТРОНЫ  /  АВТОМАТ"

func _on_hit_confirm() -> void:
	hit_marker.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(hit_marker, "modulate:a", 0.0, 0.24)

func _on_stats_changed(kills: int, score: int) -> void:
	kills_value.text = "УБИЙСТВА  %03d" % kills
	score_value.text = "СЧЁТ  %05d" % score

func _on_wave_changed(value: int) -> void:
	if value > 0:
		wave_value.text = "%02d" % value

func _resume() -> void:
	modal.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _go_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)

func _restart() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(ARENA_SCENE)

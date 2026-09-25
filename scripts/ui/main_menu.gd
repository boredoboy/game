extends Control

const GAME_SCENE := "res://scenes/levels/arena.tscn"
const BACKDROP_SCRIPT := preload("res://scripts/ui/menu_backdrop.gd")
const UI_CONFIRM := preload("res://assets/audio/packs/core_sfx/ui/menu_confirm.wav")
const UI_HOVER := preload("res://assets/audio/packs/core_sfx/ui/menu_hover.wav")

var settings_overlay: Control
var master_slider: HSlider
var sfx_slider: HSlider
var music_slider: HSlider
var sensitivity_slider: HSlider
var resolution_option: OptionButton
var quality_option: OptionButton
var fullscreen_toggle: CheckButton
var vsync_toggle: CheckButton
var ui_audio: AudioStreamPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui_audio = AudioStreamPlayer.new()
	ui_audio.name = "MenuUIAudio"
	add_child(ui_audio)
	_build_backdrop()
	_build_ui()

func _build_backdrop() -> void:
	var viewport_container := SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport_container.add_child(viewport)
	var backdrop := Node3D.new()
	backdrop.set_script(BACKDROP_SCRIPT)
	viewport.add_child(backdrop)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://assets/shaders/menu_vignette.gdshader")
	shade.material = shader_material
	add_child(shade)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_bottom", 34)
	add_child(margin)
	var layout := VBoxContainer.new()
	margin.add_child(layout)
	var brand_row := HBoxContainer.new()
	brand_row.add_theme_constant_override("separation", 12)
	layout.add_child(brand_row)
	var mark := Label.new()
	mark.text = "DR  /  07"
	mark.add_theme_color_override("font_color", Color("e8b86e"))
	mark.add_theme_font_size_override("font_size", 17)
	brand_row.add_child(mark)
	var separator := ColorRect.new()
	separator.color = Color("d9c5a8", 0.5)
	separator.custom_minimum_size = Vector2(1, 20)
	brand_row.add_child(separator)
	var subtitle := Label.new()
	subtitle.text = "СЕКТОР 07   ·   НОЧНАЯ СМЕНА"
	subtitle.add_theme_color_override("font_color", Color("d3d0c9"))
	subtitle.add_theme_font_size_override("font_size", 13)
	brand_row.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 84
	layout.add_child(spacer)
	var title := Label.new()
	title.text = "DEAD\nRADIO"
	title.add_theme_color_override("font_color", Color("f0ede6"))
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_constant_override("line_spacing", -16)
	layout.add_child(title)
	var edition := Label.new()
	edition.text = "LAST SIGNAL  //  SURVIVAL PROTOCOL"
	edition.add_theme_color_override("font_color", Color("e8b86e"))
	edition.add_theme_font_size_override("font_size", 13)
	layout.add_child(edition)
	var gap := Control.new()
	gap.custom_minimum_size.y = 45
	layout.add_child(gap)
	var start := _menu_button("НАЧАТЬ ЗАБЕГ", true)
	start.custom_minimum_size = Vector2(310, 58)
	start.pressed.connect(_start_game)
	layout.add_child(start)
	var settings := _menu_button("НАСТРОЙКИ", false)
	settings.custom_minimum_size = Vector2(310, 52)
	settings.pressed.connect(_show_settings)
	layout.add_child(settings)
	var quit := _menu_button("ВЫХОД", false)
	quit.custom_minimum_size = Vector2(310, 48)
	quit.pressed.connect(func(): get_tree().quit())
	layout.add_child(quit)
	var foot_spacer := Control.new()
	foot_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(foot_spacer)
	var footer := Label.new()
	footer.text = "АКАРИ  ·  ЮНА  ·  МИКА     /     ТРИ СПУТНИЦЫ. ОДНА ПОСЛЕДНЯЯ ЧАСТОТА."
	footer.add_theme_color_override("font_color", Color("e1dbd0", 0.76))
	footer.add_theme_font_size_override("font_size", 12)
	layout.add_child(footer)
	_build_settings_overlay()

func _menu_button(label_text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("201913") if primary else Color("eee8dd"))
	button.add_theme_color_override("font_hover_color", Color("fff8ec"))
	button.add_theme_constant_override("h_separation", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d9a965") if primary else Color("11191d", 0.62)
	normal.border_color = Color("d9a965", 0.92) if primary else Color("dfd3bf", 0.23)
	normal.set_border_width_all(1)
	normal.content_margin_left = 22
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("edc481") if primary else Color("303c40", 0.88)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_entered.connect(func(): _play_ui_sound(UI_HOVER))
	button.pressed.connect(func(): _play_ui_sound(UI_CONFIRM))
	return button

func _play_ui_sound(stream: AudioStream) -> void:
	ui_audio.stream = stream
	ui_audio.volume_db = linear_to_db(maxf(float(GameSettings.get_value("sfx_volume")), 0.001))
	ui_audio.play()

func _build_settings_overlay() -> void:
	settings_overlay = Control.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.visible = false
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings_overlay)
	var dim := ColorRect.new()
	dim.color = Color("070b0d", 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 650)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("11191d", 0.97)
	panel_style.border_color = Color("bd935b", 0.7)
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 34
	panel_style.content_margin_right = 34
	panel_style.content_margin_top = 26
	panel_style.content_margin_bottom = 25
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 17)
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = "НАСТРОЙКИ"
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("e7b66d"))
	stack.add_child(heading)
	var caption := Label.new()
	caption.text = "ИЗОБРАЖЕНИЕ  ·  ЗВУК  ·  УПРАВЛЕНИЕ"
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("aeb7b4"))
	stack.add_child(caption)
	resolution_option = OptionButton.new()
	resolution_option.add_item("1280 × 720")
	resolution_option.set_item_metadata(0, "1280x720")
	resolution_option.add_item("1600 × 900")
	resolution_option.set_item_metadata(1, "1600x900")
	resolution_option.add_item("1920 × 1080")
	resolution_option.set_item_metadata(2, "1920x1080")
	resolution_option.item_selected.connect(_on_resolution_selected)
	_add_option(stack, "РАЗРЕШЕНИЕ ОКНА", resolution_option)
	quality_option = OptionButton.new()
	for quality_name in ["Высокое", "Среднее", "Низкое"]:
		quality_option.add_item(quality_name)
	quality_option.item_selected.connect(func(index: int): GameSettings.set_value("quality", quality_option.get_item_text(index)))
	_add_option(stack, "КАЧЕСТВО ТЕНЕЙ", quality_option)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "Полноэкранный режим"
	fullscreen_toggle.button_pressed = bool(GameSettings.get_value("fullscreen"))
	fullscreen_toggle.toggled.connect(func(value: bool): GameSettings.set_value("fullscreen", value))
	stack.add_child(fullscreen_toggle)
	vsync_toggle = CheckButton.new()
	vsync_toggle.text = "Вертикальная синхронизация"
	vsync_toggle.button_pressed = bool(GameSettings.get_value("vsync"))
	vsync_toggle.toggled.connect(func(value: bool): GameSettings.set_value("vsync", value))
	stack.add_child(vsync_toggle)
	master_slider = _add_slider(stack, "ОБЩАЯ ГРОМКОСТЬ", float(GameSettings.get_value("master_volume")))
	master_slider.value_changed.connect(func(value: float): GameSettings.set_value("master_volume", value))
	sfx_slider = _add_slider(stack, "ЗВУКОВЫЕ ЭФФЕКТЫ", float(GameSettings.get_value("sfx_volume")))
	sfx_slider.value_changed.connect(func(value: float): GameSettings.set_value("sfx_volume", value))
	music_slider = _add_slider(stack, "АТМОСФЕРА", float(GameSettings.get_value("music_volume")))
	music_slider.value_changed.connect(func(value: float): GameSettings.set_value("music_volume", value))
	sensitivity_slider = _add_slider(stack, "ЧУВСТВИТЕЛЬНОСТЬ МЫШИ", float(GameSettings.get_value("mouse_sensitivity")) / 0.4)
	sensitivity_slider.value_changed.connect(func(value: float): GameSettings.set_value("mouse_sensitivity", value * 0.4))
	var back := _menu_button("СОХРАНЕНО  ·  НАЗАД", true)
	back.custom_minimum_size = Vector2(0, 45)
	back.pressed.connect(func(): settings_overlay.visible = false)
	stack.add_child(back)
	var saved_resolution: String = str(GameSettings.get_value("resolution"))
	for i in resolution_option.item_count:
		if str(resolution_option.get_item_metadata(i)) == saved_resolution:
			resolution_option.select(i)
	for i in quality_option.item_count:
		if quality_option.get_item_text(i) == str(GameSettings.get_value("quality")):
			quality_option.select(i)

func _add_option(parent: VBoxContainer, title: String, option: OptionButton) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("d4d0c8"))
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	option.custom_minimum_size.x = 190
	row.add_child(option)
	parent.add_child(row)

func _add_slider(parent: VBoxContainer, title: String, initial: float) -> HSlider:
	var column := VBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", Color("d4d0c8"))
	label.add_theme_font_size_override("font_size", 12)
	column.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = initial
	column.add_child(slider)
	parent.add_child(column)
	return slider

func _on_resolution_selected(index: int) -> void:
	GameSettings.set_value("resolution", str(resolution_option.get_item_metadata(index)))

func _show_settings() -> void:
	settings_overlay.visible = true

func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)

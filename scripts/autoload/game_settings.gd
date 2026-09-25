extends Node

signal setting_changed(key: String, value: Variant)

const FILE_PATH := "user://dead_radio_settings.cfg"
var config := ConfigFile.new()
var values := {
	"master_volume": 0.78,
	"sfx_volume": 0.86,
	"music_volume": 0.48,
	"mouse_sensitivity": 0.14,
	"fullscreen": false,
	"vsync": true,
	"resolution": "1280x720",
	"quality": "Низкое"
}

func _ready() -> void:
	var error := config.load(FILE_PATH)
	if error == OK:
		for key in values:
			values[key] = config.get_value("settings", key, values[key])
	apply_all()

func get_value(key: StringName) -> Variant:
	return values.get(String(key), null)

func set_value(key: StringName, value: Variant) -> void:
	values[String(key)] = value
	config.set_value("settings", String(key), value)
	config.save(FILE_PATH)
	apply_setting(String(key))
	setting_changed.emit(String(key), value)

func apply_all() -> void:
	for key in values:
		apply_setting(key)

func apply_setting(key: String) -> void:
	match key:
		"master_volume":
			AudioServer.set_bus_volume_linear(0, clampf(float(values[key]), 0.0, 1.0))
		"fullscreen":
			var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values[key]) else DisplayServer.WINDOW_MODE_WINDOWED
			DisplayServer.window_set_mode(mode)
			if not bool(values[key]):
				apply_setting("resolution")
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(values[key]) else DisplayServer.VSYNC_DISABLED)
		"resolution":
			if not bool(values.get("fullscreen", false)):
				var parts: PackedStringArray = str(values[key]).split("x")
				if parts.size() == 2:
					var size := Vector2i(int(parts[0]), int(parts[1]))
					DisplayServer.window_set_size(size)
					DisplayServer.window_set_position((DisplayServer.screen_get_size() - size) / 2)

func mouse_sensitivity() -> float:
	return float(values.get("mouse_sensitivity", 0.14))

func shadows_enabled() -> bool:
	return str(values.get("quality", "Высокое")) != "Низкое"

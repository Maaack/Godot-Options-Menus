@tool
class_name MaaacksOptionsMenus
extends RefCounted

const PLUGIN_NAME = "Maaack's Options Menus"
const PROJECT_SETTINGS_PATH = "maaacks_options_menus/"
const MAIN_SCENE_RELATIVE_PATH = "scenes/menus/options_menu/master_options_menu_with_tabs.tscn"
const COPY_PATH_KEY = "copy_path"

static func get_plugin_name() -> String:
	return PLUGIN_NAME

static func get_settings_path() -> String:
	return PROJECT_SETTINGS_PATH

static func get_main_scene_relative_path() -> String:
	return MAIN_SCENE_RELATIVE_PATH

static func get_copy_path(default_path : String = "") -> String:
	var copy_path = ProjectSettings.get_setting(PROJECT_SETTINGS_PATH + COPY_PATH_KEY, default_path)
	if not copy_path.ends_with("/"):
		copy_path += "/"
	return copy_path

static func set_copy_path(copy_path : String) -> void:
	ProjectSettings.set_setting(PROJECT_SETTINGS_PATH + COPY_PATH_KEY, copy_path)
	ProjectSettings.save()

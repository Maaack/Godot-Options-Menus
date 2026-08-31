@tool
class_name MaaacksOptionsMenusPlugin
extends EditorPlugin

const PLUGIN_REPO_URL = "https://github.com/Maaack/Godot-Options-Menus"
const EXAMPLES_RELATIVE_PATH = "examples/"
const OVERRIDE_RELATIVE_PATH = "installer/override.cfg"
const WINDOW_OPEN_DELAY : float = 0.5
const RUNNING_CHECK_DELAY : float = 0.25
const OPEN_EDITOR_DELAY : float = 0.1
const MAX_PHYSICS_FRAMES_FROM_START : int = 60
const AVAILABLE_TRANSLATIONS : Array = ["en", "fr"]
const CopyAndEdit = preload("installer/copy_and_edit_files.gd")

static var instance : MaaacksOptionsMenusPlugin

func get_plugin_path() -> String:
	return get_script().resource_path.get_base_dir() + "/"

func get_plugin_examples_path() -> String:
	return get_plugin_path() + EXAMPLES_RELATIVE_PATH

func get_copy_path() -> String:
	return MaaacksOptionsMenus.get_copy_path(get_plugin_examples_path())

func _on_visibility_changed_to_hidden(dialog_window : Window) -> void:
	if dialog_window and dialog_window.is_inside_tree() and not dialog_window.visible:
		dialog_window.queue_free()

func open_setup_complete_dialog(_target_path : String) -> void:
	var setup_complete_scene : PackedScene = load(get_plugin_path() + "installer/setup_complete_dialog.tscn")
	var setup_complete_instance : AcceptDialog = setup_complete_scene.instantiate()
	setup_complete_instance.visibility_changed.connect(_on_visibility_changed_to_hidden.bind(setup_complete_instance))
	add_child(setup_complete_instance)

func _delayed_call_with_path(callable : Callable, target_path : String) -> void:
	var timer: Timer = Timer.new()
	var timer_callable := func():
		timer.stop()
		callable.call(target_path)
		timer.queue_free()
	timer.timeout.connect(timer_callable)
	add_child(timer)
	timer.start(WINDOW_OPEN_DELAY)

func _delayed_open_setup_complete_dialog(target_path : String) -> void:
	_delayed_call_with_path(open_setup_complete_dialog, target_path)

func _open_play_opening_confirmation_dialog(target_path : String) -> void:
	var play_confirmation_scene : PackedScene = load(get_plugin_path() + "installer/play_opening_confirmation_dialog.tscn")
	var play_confirmation_instance : ConfirmationDialog = play_confirmation_scene.instantiate()
	play_confirmation_instance.confirmed.connect(_run_opening_scene.bind(target_path))
	play_confirmation_instance.canceled.connect(_delayed_open_setup_complete_dialog.bind(target_path))
	play_confirmation_instance.visibility_changed.connect(_on_visibility_changed_to_hidden.bind(play_confirmation_instance))
	add_child(play_confirmation_instance)

func _open_delete_examples_confirmation_dialog(target_path : String) -> void:
	var delete_confirmation_scene : PackedScene = load(get_plugin_path() + "installer/delete_examples_confirmation_dialog.tscn")
	var delete_confirmation_instance : ConfirmationDialog = delete_confirmation_scene.instantiate()
	delete_confirmation_instance.confirmed.connect(_delete_source_examples_directory.bind(target_path))
	delete_confirmation_instance.canceled.connect(_delayed_open_setup_complete_dialog.bind(target_path))
	delete_confirmation_instance.visibility_changed.connect(_on_visibility_changed_to_hidden.bind(delete_confirmation_instance))
	add_child(delete_confirmation_instance)

func open_delete_examples_short_confirmation_dialog() -> void:
	var copy_path := get_copy_path()
	var delete_confirmation_scene : PackedScene = load(get_plugin_path() + "installer/delete_examples_short_confirmation_dialog.tscn")
	var delete_confirmation_instance : ConfirmationDialog = delete_confirmation_scene.instantiate()
	delete_confirmation_instance.confirmed.connect(_delete_source_examples_directory.bind(copy_path))
	delete_confirmation_instance.canceled.connect(_delayed_call_with_path.bind(open_setup_wizard, copy_path))
	delete_confirmation_instance.visibility_changed.connect(_on_visibility_changed_to_hidden.bind(delete_confirmation_instance))
	add_child(delete_confirmation_instance)

func _run_opening_scene(target_path : String) -> void:
	var opening_scene_path = target_path + MaaacksOptionsMenus.get_main_scene_relative_path()
	EditorInterface.play_custom_scene(opening_scene_path)
	var timer: Timer = Timer.new()
	var callable := func() -> void:
		if EditorInterface.is_playing_scene(): return
		timer.stop()
		_delayed_call_with_path(_open_delete_examples_confirmation_dialog, target_path)
		timer.queue_free()
	timer.timeout.connect(callable)
	add_child(timer)
	timer.start(RUNNING_CHECK_DELAY)

func _delete_directory_recursive(dir_path : String) -> void:
	if not dir_path.ends_with("/"):
		dir_path += "/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var error : Error
		while file_name != "" and error == 0:
			var relative_path = dir_path.trim_prefix(get_plugin_examples_path())
			var full_file_path = dir_path + file_name
			if dir.current_is_dir():
				_delete_directory_recursive(full_file_path)
			else:
				error = dir.remove(file_name)
			file_name = dir.get_next()
		if error:
			push_error("plugin error - deleting path: %s" % error)
	else:
		push_error("plugin error - accessing path: %s" % dir)
	dir.remove(dir_path)

func _delete_source_examples_directory(target_path : String = "") -> void:
	var examples_path = get_plugin_examples_path()
	var dir := DirAccess.open("res://")
	if dir.dir_exists(examples_path):
		_delete_directory_recursive(examples_path)
		EditorInterface.get_resource_filesystem().scan()
	if not target_path.is_empty():
		_delayed_open_setup_complete_dialog(target_path)

func _raw_copy_file_path(file_path : String, destination_path : String) -> Error:
	var dir := DirAccess.open("res://")
	var error := dir.copy(file_path, destination_path)
	return error

func _copy_override_file() -> void:
	var override_path : String = get_plugin_path() + OVERRIDE_RELATIVE_PATH
	_raw_copy_file_path(override_path, "res://"+override_path.get_file())

func _add_translations() -> void:
	var dir := DirAccess.open("res://")
	var translations : PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", [])
	for available_translation in AVAILABLE_TRANSLATIONS:
		var translation_path = get_plugin_path() + ("base/translations/menus_translations.%s.translation" % available_translation)
		if dir.file_exists(translation_path) and translation_path not in translations:
			translations.append(translation_path)
	ProjectSettings.set_setting("internationalization/locale/translations", translations)

func _on_completed_copy_to_directory(target_path : String) -> void:
	MaaacksOptionsMenus.set_copy_path(target_path)
	_copy_override_file()
	_open_play_opening_confirmation_dialog(target_path)

func are_examples_deleted() -> bool:
	var dir := DirAccess.open("res://")
	return not dir.dir_exists(get_plugin_examples_path())

func is_partially_installed() -> bool:
	var copy_path : String = MaaacksOptionsMenus.get_copy_path()
	if copy_path.is_empty():
		# Installation not started
		return false
	if not are_examples_deleted():
		return true
	return false

func open_input_icons_dialog() -> void:
	var input_icons_scene : PackedScene = load(get_plugin_path() + "installer/kenney_input_prompts_installer.tscn")
	var input_icons_instance = input_icons_scene.instantiate()
	input_icons_instance.copy_dir_path = get_copy_path()
	add_child(input_icons_instance)

func open_copy_and_edit_dialog() -> void:
	var copy_and_edit_scene : PackedScene = load(get_plugin_path() + "installer/copy_and_edit_files.tscn")
	var copy_and_edit_instance : CopyAndEdit = copy_and_edit_scene.instantiate()
	copy_and_edit_instance.completed.connect(_on_completed_copy_to_directory)
	copy_and_edit_instance.canceled.connect(_delayed_open_setup_complete_dialog.bind(get_copy_path()))
	add_child(copy_and_edit_instance)

func _open_confirmation_dialog() -> void:
	var confirmation_scene : PackedScene = load(get_plugin_path() + "installer/copy_confirmation_dialog.tscn")
	var confirmation_instance : ConfirmationDialog = confirmation_scene.instantiate()
	confirmation_instance.confirmed.connect(open_copy_and_edit_dialog)
	confirmation_instance.canceled.connect(_delayed_open_setup_complete_dialog.bind(get_copy_path()))
	confirmation_instance.visibility_changed.connect(_on_visibility_changed_to_hidden.bind(confirmation_instance))
	add_child(confirmation_instance)

func _open_continue_setup_dialog() -> void:
	var confirmation_scene : PackedScene = load(get_plugin_path() + "installer/continue_setup_confirmation_dialog.tscn")
	var confirmation_instance : ConfirmationDialog = confirmation_scene.instantiate()
	confirmation_instance.confirmed.connect(open_setup_wizard)
	confirmation_instance.visibility_changed.connect(_on_visibility_changed_to_hidden.bind(confirmation_instance))
	add_child(confirmation_instance)

func open_setup_wizard(_target_path: String = "") -> void:
	var setup_wizard_scene : PackedScene = load(get_plugin_path() + "installer/setup_wizard.tscn")
	var setup_wizard_instance : Node = setup_wizard_scene.instantiate()
	add_child(setup_wizard_instance)

func _show_plugin_dialogues() -> void:
	var setting_key := MaaacksOptionsMenus.get_settings_path() + "disable_install_wizard"
	if not ProjectSettings.get_setting(setting_key, false):
		_open_confirmation_dialog()
		ProjectSettings.set_setting(setting_key, true)
		ProjectSettings.save()
		return
	if is_partially_installed():
		_open_continue_setup_dialog()
		return

func _resave_if_recently_opened() -> void:
	if Engine.get_physics_frames() < MAX_PHYSICS_FRAMES_FROM_START:
		var timer: Timer = Timer.new()
		var callable := func():
			if Engine.get_frames_per_second() >= 10:
				timer.stop()
				EditorInterface.save_scene()
				timer.queue_free()
		timer.timeout.connect(callable)
		add_child(timer)
		timer.start(OPEN_EDITOR_DELAY)

func _add_tool_options() -> void:
	add_tool_menu_item("Run " + MaaacksOptionsMenus.get_plugin_name() + " Setup...", open_setup_wizard)

func _remove_tool_options() -> void:
	remove_tool_menu_item("Run " + MaaacksOptionsMenus.get_plugin_name() + " Setup...")

func _add_to_auto_update_list() -> void:
	PluginUpdater.add_plugin(get_plugin_path(), PLUGIN_REPO_URL)

func _remove_from_auto_update_list() -> void:
	PluginUpdater.remove_plugin(get_plugin_path())

func _enable_plugin():
	_add_to_auto_update_list()

func _disable_plugin():
	_remove_from_auto_update_list()

func _enter_tree() -> void:
	_add_tool_options()
	_add_translations()
	_show_plugin_dialogues()
	_resave_if_recently_opened()
	instance = self

func _exit_tree() -> void:
	_remove_tool_options()
	instance = null

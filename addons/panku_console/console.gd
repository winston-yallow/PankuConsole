## Panku Console. Provide a runtime GDScript REPL so your can run any script expressions in your game!
##
## This class will be an autoload ([code] Console [/code] by default) if you enable the plugin. The basic idea is that you can run [Expression] based on an environment(or base instance) by [method execute]. You can view [code]default_env.gd[/code] to see how to prepare your own environment.
## [br]
## [br] What's more, you can...
## [br]
## [br] ● Send in-game notifications by [method notify]
## [br] ● Output something to the console window by [method output]
## [br] ● Manage widgets plans by [method add_widget], [method save_current_widgets_as], etc.
## [br] ● Lot's of useful expressions defined in [code]default_env.gd[/code].
##
## @tutorial:            https://github.com/Ark2000/PankuConsole
class_name PankuConsole extends CanvasLayer

## Emitted when the visibility (hidden/visible) of console window changes.
signal repl_visible_about_to_change(is_visible:bool)
signal repl_visible_changed(is_visible:bool)

#Static helper classes
const Config = preload("res://addons/panku_console/components/config.gd")
const Utils = preload("res://addons/panku_console/components/utils.gd")

#Other classes, define classes here instead of using keyword `class_name` so that the global namespace will not be affected.
const ExporterRowUI = preload("res://addons/panku_console/components/exporter/row_ui.gd")
const JoystickButton = preload("res://addons/panku_console/components/exporter/joystick_button.gd")
const LynxWindow = preload("res://addons/panku_console/components/lynx_window2/lynx_window.gd")
const Exporter = preload("res://addons/panku_console/components/exporter/exporter.gd")

## The input action used to toggle console. By default it is KEY_QUOTELEFT.
var toggle_console_action:String

## If [code]true[/code], pause the game when the console window is active.
var pause_when_active:bool

var mini_repl_mode = false:
	set(v):
		mini_repl_mode = v
		if is_repl_window_opened:
			_mini_repl_window.visible = v
			_full_repl_window.visible = !v

var is_repl_window_opened := false:
	set(v):
		repl_visible_about_to_change.emit(v)
		await get_tree().process_frame
		is_repl_window_opened = v
		if mini_repl_mode:
			_mini_repl_window.visible = v
		else:
			_full_repl_window.visible = v
		if pause_when_active:
			get_tree().paused = v
			_full_repl_window.title_label.text = "> Panku REPL (Paused)"
		else:
			_full_repl_window.title_label.text = "> Panku REPL"
		repl_visible_changed.emit(v)

@export var _resident_logs:Node
@export var _base_instance:Node
@export var _windows:Node
@export var _mini_repl_window:Node
@export var _full_repl_window:Node
@export var _full_repl:Node
@export var _exp_key_mapper:Node
@export var godot_log_monitor:Node
@export var output_overlay:Node

const _monitor_widget_pck = preload("res://addons/panku_console/components/monitor/monitor_widget.tscn")
const _exporter_window = preload("res://addons/panku_console/components/exporter/exporter.tscn")

var _envs = {}
var _envs_info = {}
var _expression = Expression.new()

## Register an environment that run expressions.
## [br][code]env_name[/code]: the name of the environment
## [br][code]env[/code]: The base instance that runs the expressions. For exmaple your player node.
func register_env(env_name:String, env:Object):
	_envs[env_name] = env
	output("[color=green][Info][/color] [b]%s[/b] env loaded!"%env_name)
	if env is Node:
		env.tree_exiting.connect(
			func(): remove_env(env_name)
		)
	if env.get_script():
		var env_info = Utils.extract_info_from_script(env.get_script())
		for k in env_info:
			var keyword = "%s.%s" % [env_name, k]
			_envs_info[keyword] = env_info[k]

## Return the environment object or [code]null[/code] by its name.
func get_env(env_name:String) -> Node:
	return _envs.get(env_name)

## Remove the environment named [code]env_name[/code]
func remove_env(env_name:String):
	if _envs.has(env_name):
		_envs.erase(env_name)
		for k in _envs_info.keys():
			if k.begins_with(env_name + "."):
				_envs_info.erase(k)
	notify("[color=green][Info][/color] [b]%s[/b] env unloaded!"%env_name)

## Generate a notification
func notify(any) -> void:
	var text = str(any)
	_resident_logs.add_log(text)
	output(text)

func output(any) -> void:
	_full_repl.output(any)

#Execute an expression in a preset environment.
func execute(exp:String) -> Dictionary:
	return Utils.execute_exp(exp, _expression, _base_instance, _envs)

func add_widget2(exp:String, update_period:= 999999.0, position:Vector2 = Vector2(0, 0), size:Vector2 = Vector2(160, 60), title_text := ""):
	if title_text == "": title_text = exp
	var w = _monitor_widget_pck.instantiate()
	w.position = position
	w.size = size
	w.update_exp = exp
	w.update_period = update_period
	w.title_text = title_text
	_windows.add_child(w)

func add_export_widget(obj:Object):
	var obj_name = _envs.find_key(obj)
	if obj_name == null:
		return
	if !obj.get_script():
		return
	var w = _exporter_window.instantiate()
	_windows.add_child(w)
	var exporter:Exporter = w.content.get_child(0)
	w.position = Vector2(0, 0)
	w.title_label.text = "Exporter (%s)" % str(obj)
	exporter.setup(obj)
	return w

func get_available_export_objs() -> Array:
	var result = []
	for obj_name in _envs:
		var obj = _envs[obj_name]
		if !obj.get_script():
			continue
		var export_properties = Utils.get_export_properties_from_script(obj.get_script())
		if export_properties.is_empty():
			continue
		result.push_back(obj_name)
	return result

func show_intro():
	output("[center][b][color=#f5891d][ Panku Console ][/color][/b] [color=#f5f5f5][b]Version 1.2.32[/b][/color][/center]")
	output("[center][img=96]res://addons/panku_console/logo.svg[/img][/center]")
	output("[color=#f5f5f5][b]Check [color=#f5891d]repl_console_env.gd[/color] or simply type [color=#f5891d]help[/color] to see what you can do now![/b][/color] [color=#f5f5f5][b]For more information, please visit: [color=#f5891d][url=https://github.com/Ark2000/PankuConsole]project github page[/url][/color][/b][/color].")
	output("")

func _input(_e):
	if Input.is_action_just_pressed(toggle_console_action):
		is_repl_window_opened = !is_repl_window_opened

func _ready():
	assert(get_tree().current_scene != self, "Do not run this directly")

	show_intro()

	pause_when_active = ProjectSettings.get("panku/pause_when_active")
	toggle_console_action = ProjectSettings.get("panku/toggle_console_action")
	
#	print(Config.get_config())
	_full_repl_window.hide()
	_mini_repl_window.hide()
	
	_full_repl_window.close_window.connect(
		func():
			is_repl_window_opened = false
	)
	
	_full_repl.open_exp_key_mapper.connect(
		func():
			_exp_key_mapper.show()
	)

	#check the action key
	#the open console action can be change in the export options of panku.tscn
	assert(InputMap.has_action(toggle_console_action), "Please specify an action to open the console!")

	#add info of base instance
	var env_info = Utils.extract_info_from_script(_base_instance.get_script())
	for k in env_info: _envs_info[k] = env_info[k]
	
	#load configs
	var cfg = Config.get_config()

	if cfg.has("widgets_data"):
		var w_data = cfg["widgets_data"]
		for w in w_data:
			add_widget2(w["exp"], w["period"], w["position"], w["size"], w["title"])
		cfg["widgets_data"] = []
	
	await get_tree().process_frame
	
	if cfg.has("init_exp"):
		var init_exp = cfg["init_exp"]
		for e in init_exp:
			execute(e)
		cfg["init_exp"] = []

	await get_tree().process_frame

	if cfg.has("repl"):
		is_repl_window_opened = cfg.repl.visible
		_full_repl_window.position = cfg.repl.position
		_full_repl_window.size = cfg.repl.size
		
	if cfg.has("mini_repl"):
		mini_repl_mode = cfg.mini_repl

	Config.set_config(cfg)

#	register_env("panku", self)

func _notification(what):
	#quit event
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var cfg = Config.get_config()
		if !cfg.has("repl"):
			cfg["repl"] = {
				"visible":false,
				"position":Vector2(0, 0),
				"size":Vector2(200, 200)
			}
		cfg.repl.visible = is_repl_window_opened
		cfg.repl.position = _full_repl_window.position
		cfg.repl.size = _full_repl_window.size
		if !cfg.has("mini_repl"):
			cfg["mini_repl"] = false
		cfg.mini_repl = mini_repl_mode
		Config.set_config(cfg)

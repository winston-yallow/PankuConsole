extends ScrollContainer
const BUTTON_PREFIX = "export_button_"

@export var lynx_window:Node
@export var timer:Timer
@export var container:VBoxContainer
@export var group_button:PackedScene
@export var row_button:PackedScene
@export var row_read_only:PackedScene
@export var row_enum:PackedScene
@export var row_range_number:PackedScene
@export var row_vec2:PackedScene
@export var row_float:PackedScene
@export var row_int:PackedScene
@export var row_color:PackedScene
@export var row_string:PackedScene
@export var row_bool:PackedScene

var obj:Object
var ui_rows := {}

func _ready():
	var window:PankuConsole.LynxWindow = lynx_window
	window.close_window.connect(
		func():
			window.queue_free()
	)

#dependency injection.
func setup(_obj:Object):
	obj = _obj
	
	if obj == null:
		push_error("FAILED")
		return

	if !is_instance_valid(obj):
		push_error("FAILED")
		return

	var script = obj.get_script()
	if script == null:
		push_error("FAILED")
		return
		
	if !container: 
		push_error("FAILED")
		return

	#remove all existing rows
	for c in container.get_children():
		c.queue_free()
	ui_rows = {}

	#get all export properties from its script
	var data = script.get_script_property_list()
	var row = null
	var group:Array = []
	var last_group_button = null
	for d in data:
		if d.name.begins_with("_"):
			continue
			
		row = null

		#@export
		var is_button := false
		if d.usage == (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE):
			#button
			if d.name.begins_with(BUTTON_PREFIX) and d.type == TYPE_STRING:
				var func_name:String = d.name.trim_prefix(BUTTON_PREFIX)
				if func_name in obj:
					row = row_button.instantiate()
					row.obj = obj
					row.callback = func_name
					row.btn_text = obj.get(d.name)
					is_button = true
				else:
					push_error("CAN NOT FIND " + func_name)
			elif d.type == TYPE_INT and d.hint == PROPERTY_HINT_NONE:
				row = row_int.instantiate()
			elif d.type == TYPE_FLOAT and d.hint == PROPERTY_HINT_NONE:
				row = row_float.instantiate()
			#edit number with slider
			elif d.type in [TYPE_FLOAT, TYPE_INT] and d.hint == PROPERTY_HINT_RANGE:
				row = row_range_number.instantiate()
				row.setup(d.type, d.hint_string.split(",", false))
			elif d.type == TYPE_VECTOR2:
				row = row_vec2.instantiate()
			elif d.type == TYPE_BOOL:
				row = row_bool.instantiate()
			elif d.type == TYPE_STRING:
				row = row_string.instantiate()
			elif d.type == TYPE_COLOR:
				row = row_color.instantiate()
			elif d.type == TYPE_INT and d.hint == PROPERTY_HINT_ENUM:
				row = row_enum.instantiate()
				row.setup(d.hint_string.split(",", false))
			#unsupported
			else:
				row = row_read_only.instantiate()

			group.append(row)
			if !is_button:
				ui_rows[d.name] = row

		#@export_group, no support for `prefix`
		elif d.usage == PROPERTY_USAGE_GROUP:
			if last_group_button:
				last_group_button.control_group = group
				group = []
			row = group_button.instantiate()
			row.text = d.name
			last_group_button = row

		if row:
			container.add_child(row)

	if !group.is_empty() and last_group_button:
		last_group_button.control_group = group

	for dname in ui_rows:
		#sync data, ui -> data
		var r:PankuConsole.ExporterRowUI = ui_rows[dname]
		r.ui_val_changed.connect(
			func(val):
#				printt(dname, val)
				if !is_instance_valid(obj):
					return
				if dname in obj:
					obj.set(dname, val)
		)
		#set name label
		r.name_label.text = dname

	timer.wait_time = 0.1
	timer.one_shot = false
	#sync data periodically, data -> ui
	timer.timeout.connect(
		func():
			if !is_instance_valid(obj):
				return
			for dname in ui_rows:
				if dname in obj:
					var r:PankuConsole.ExporterRowUI = ui_rows[dname]
					if !r.is_active():
						r.update_ui(obj.get(dname))
	)
	timer.start()

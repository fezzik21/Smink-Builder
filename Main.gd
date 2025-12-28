extends Node
class_name Main

@onready var graph: GraphEdit = $"VSplitContainer/GraphEdit"
@onready var overlay: Control  = $"VSplitContainer/GraphEdit/Overlay"
@onready var totalSize: Label = $"TotalSizeLabel"
@onready var configHeader: LineEdit = $VSplitContainer/HBoxContainer/ConfigHeader

var StoryNodeScene := preload("res://StoryNode.tscn")

var edge_labels  : Dictionary = {}  # key -> text (for persistence)
var edge_widgets : Dictionary = {}  # key -> Label (for positioning)
var edge_counter : int = 0
var initial_load := false

var save_shortcut = Shortcut.new()

var fail_style : StyleBoxFlat = StyleBoxFlat.new()
var win_style : StyleBoxFlat = StyleBoxFlat.new()
var empty_style : StyleBoxFlat = StyleBoxFlat.new()
var normal_style : StyleBoxFlat = StyleBoxFlat.new()

var selected_node : Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fail_style.bg_color = Color(1.0, 0.0, 0.0)
	win_style.bg_color = Color(0.0, 1.0, 0.0)
	empty_style.bg_color = Color(0.0, 0.0, 1.0)
	normal_style.bg_color = Color(0.6, 0.6, 0.6)
	graph.show_grid = false
	graph.right_disconnects = true
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	set_process(true)
	
	var key_event = InputEventKey.new()
	key_event.keycode = KEY_S
	key_event.ctrl_pressed = true
	key_event.command_or_control_autoremap = true # Swaps Ctrl for Command on Mac.
	save_shortcut.events = [key_event]
	
	graph.add_theme_color_override("activity", Color(1.0, 0.6, 0.1, 1.0))
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (!initial_load):
		initial_load = true
		_load_file()
	_update_edge_label_positions()
	totalSize.text = str(_calc_length())

func _delete_node(id: String) -> void:
	print("deleting node " + id)
	for con in graph.get_connection_list():
		if con.to_node == id or con.from_node == id:
			graph.disconnect_node(con.from_node, con.from_port, con.to_node, con.to_port)
			var key := _edge_key(con.from_node, con.from_port, con.to_node, con.to_port)
			edge_widgets[key].queue_free()
			edge_widgets.erase(key)
			edge_labels.erase(key)
	graph.get_node(NodePath(id)).queue_free()	
	
func _graph_node_selected(node: Node) -> void:
	selected_node = node
	
func _graph_node_deselected(node: Node) -> void:
	if not graph.selected_connection.is_empty():
			print("trying to delete")
			graph.disconnect_node(
				graph.selected_connection.from_node,
				graph.selected_connection.from_port,
				graph.selected_connection.to_node,
				graph.selected_connection.to_port
			)			
			var key := _edge_key(graph.selected_connection.from_node, 
				graph.selected_connection.from_port, graph.selected_connection.to_node, 
				graph.selected_connection.to_port)
			var w: LineEdit = edge_widgets.get(key, null)
			w.queue_free()
			edge_widgets.erase(key)
			graph.selected_connection = Dictionary()
			graph.queue_redraw()
	
func _delete_selected_node() -> void:
	print("delete selected node")
	if(selected_node != null):
		_delete_node(selected_node.node_id)
	pass
	
func _delete_selected_edge() -> void:
	print("delete selected edge")
	if(graph.selected_connection != null):
		graph.disconnect_node(
				graph.selected_connection.from_node,
				graph.selected_connection.from_port,
				graph.selected_connection.to_node,
				graph.selected_connection.to_port
			)			
		var key := _edge_key(graph.selected_connection.from_node, 
			graph.selected_connection.from_port, graph.selected_connection.to_node, 
			graph.selected_connection.to_port)
		var w: LineEdit = edge_widgets.get(key, null)
		w.queue_free()
		edge_widgets.erase(key)
		graph.selected_connection.clear()
		graph.queue_redraw()
	
func _on_pressed() -> void:
	var n: StoryNode = StoryNodeScene.instantiate()
	n.name = "n_%s" % Time.get_ticks_msec()  # unique; GraphEdit uses names for connections
	n.node_id = n.name
	n.position_offset = graph.scroll_offset + Vector2(120, 120)
	graph.add_child(n)
	n.title_edit.text = "Node_" + str(n.get_index())
	n.title = "Node_" + str(n.get_index())
	

func _edge_key(from_id: String, from_port: int, to_id: String, to_port: int) -> String:
	return "%s:%d>%s:%d" % [from_id, from_port, to_id, to_port]

func _on_connection_request(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	# Optional: block self-loops or duplicates here
	#print("from_id: " + from_id + " from_port: " + str(from_port) + " to_id: " + to_id + " to_port: " + str(to_port) + "\n")
	graph.connect_node(from_id, from_port, to_id, to_port)
	var key := _edge_key(from_id, from_port, to_id, to_port)
	if not edge_labels.has(key):
		edge_labels[key] = "Choice_%d" % (edge_counter + 1)
		edge_counter += 1
	_ensure_edge_widget(key)  # make sure there is a Label node
	_update_edge_label_positions()

func _on_disconnection_request(from_id: String, from_port: int, to_id: String, to_port: int) -> void:
	graph.disconnect_node(from_id, from_port, to_id, to_port)
	
func _load_file() -> void:
	var f := FileAccess.open("user://story_export.txt", FileAccess.READ)
	var connections : Array = []
	if f == null:
		return
	f.get_line() # "CONFIG HEADER:"
	configHeader.text = f.get_line()
	while not f.eof_reached():
		var node_name = f.get_line()
		if !f.eof_reached():
			print("Read node " + node_name)
			var n: StoryNode = StoryNodeScene.instantiate()
			graph.add_child(n)
			n.name = "n_%s" % Time.get_ticks_msec()  # unique; GraphEdit uses names for connections
			n.node_id = n.name
			n.title_edit.text = node_name
			n.title = node_name
			var pos_x = f.get_line()
			var pos_y = f.get_line()
			print("Read pos " + str(pos_x) + " , " + str(pos_y))
			n.position_offset = Vector2(int(pos_x), int(pos_y))
			var txt = f.get_line()
			var all_txt = ""
			while(txt != "."):
				all_txt = all_txt + txt
				txt = f.get_line()
			n.body_field.text = all_txt
			var num_options = int(f.get_line())
			print("Read num options " + str(num_options))
			for i in num_options:
				var target_node = f.get_line()
				var connection_text = f.get_line()
				connections.append({ "start_node" : n.node_id, "target_node" : target_node, "connection_text" : connection_text})
			var dummy = f.get_line()
	for c in connections:
		var to_id := ""
		for node in graph.get_children():
			if node is StoryNode:
				if node.title == c["target_node"]:
					to_id = node.node_id
					
		var key := _edge_key(c["start_node"], 0, to_id, 0)
		edge_labels[key] = c["connection_text"]
		_on_connection_request(c["start_node"], 0, to_id, 0)
	
func _is_node_empty(node_id : String) -> bool:
	for c in graph.get_connection_list_from_node(node_id):
		if c.from_node == node_id:
			return false
	return true

func _calc_length() -> int:
	var h_len := 0
	var c: Array = graph.get_connection_list()
	for node in graph.get_children():
		if node is StoryNode:
			if node.title_edit.text.begins_with("FAIL"):
				node.add_theme_stylebox_override("titlebar", fail_style)
			elif node.title_edit.text.begins_with("WIN"):
				node.add_theme_stylebox_override("titlebar", win_style)
			elif _is_node_empty(node.node_id):
				node.add_theme_stylebox_override("titlebar", empty_style)
			else:
				node.add_theme_stylebox_override("titlebar", normal_style)
			var n: StoryNode = (node as StoryNode)
			h_len = h_len + 2
			h_len = h_len + node.body_field.text.length()
			h_len = h_len + 1
			for ci in c:
				if ci.from_node == n.name:
					h_len = h_len + 1						
					h_len = h_len + 1
					var key := _edge_key(ci.from_node, ci.from_port, ci.to_node, ci.to_port)	
					var le : LineEdit = edge_widgets[key]
					h_len = h_len + le.text.length()						
	return h_len
	
func _save_file() -> void:
	var f := FileAccess.open("user://story_export.txt", FileAccess.WRITE)
	var p : String = "user://storydata.h"
	if (!configHeader.text.is_empty()):
		if (configHeader.text.ends_with("//")):
			p = configHeader.text + "storydata.h"
		else:
			p = configHeader.text + "//storydata.h"
	var h := FileAccess.open(p, FileAccess.WRITE)
	var h_len := 0
	var c: Array = graph.get_connection_list()
	h.store_string("unsigned const char storydata_bin[] PROGMEM = {\n")
	if f:
		f.store_string("CONFIG HEADER:\n")
		f.store_string(configHeader.text + "\n")		
		for node in graph.get_children():
			if node is StoryNode:
				var n: StoryNode = (node as StoryNode)
				var t_len : int = 0
				t_len = node.body_field.text.length()
				h.store_string("0x%x,\n" % (t_len & 0xFF))
				h.store_string("0x%x,\n" % ((t_len & 0xFF00) >> 8))
				h_len = h_len + 1
				for i in t_len:
					h.store_string("0x%x,\n" % ord(node.body_field.text[i]))
					h_len = h_len + 1
				f.store_string(node.title + "\n")
				f.store_string(str(node.position.x) + "\n")
				f.store_string(str(node.position.y) + "\n")				
				f.store_string(node.body_field.text + "\n")
				var i := 0
				for ci in c:
					if ci.from_node == n.name:
						i = i + 1						
				h.store_string("0x%x,\n" % i)
				h_len = h_len + 1
				f.store_string(".\n")
				f.store_string(str(i) + "\n")
				for ci in c:
					if ci.from_node == n.name:
						var indx := graph.get_node(NodePath(ci.to_node)).get_index()
						h.store_string("0x%x,\n" % (indx - 2)) # magic number - hidden children
						h_len = h_len + 1
						f.store_string(graph.get_node(NodePath(ci.to_node)).title + "\n")
						var key := _edge_key(ci.from_node, ci.from_port, ci.to_node, ci.to_port)	
						var le : LineEdit = edge_widgets[key]
						t_len = le.text.length()
						h.store_string("0x%x,\n" % t_len)
						h_len = h_len + 1
						for t in t_len:
							h.store_string("0x%x,\n" % ord(le.text[t]))
							h_len = h_len + 1
						f.store_string(le.text + "\n")
				f.store_string("-----\n")
		f.close()
		h.store_string("};\n")
		h.store_string("unsigned int storydata_bin_len = " + str(h_len) + ";\n")		
	else:
		push_error("Could not open save file for write")

func _ensure_edge_widget(key: String) -> void:
	if edge_widgets.has(key): 
		return
	var le := LineEdit.new()
	le.text = edge_labels.get(key, "")
	le.placeholder_text = ""
	le.mouse_filter = Control.MOUSE_FILTER_STOP   # eat clicks so you can edit
	le.focus_mode = Control.FOCUS_ALL
	le.size = Vector2(200, 24)  # reasonable default; doesn’t scale with zoomvar lbl := Label.new()
	le.editable = true
	le.visible = true
	overlay.add_child(le)
	edge_widgets[key] = le
	
func _update_edge_label_positions() -> void:
	var zoom    := graph.zoom
	var scroll  := graph.scroll_offset
	var conns   := graph.get_connection_list()

	# Make sure widgets exist & texts are up to date
	for c in conns:
		var key := _edge_key(c.from_node, c.from_port, c.to_node, c.to_port)
		_ensure_edge_widget(key)
		var w: LineEdit = edge_widgets[key]
	
	# Position each widget roughly at the bezier midpoint
	for c in conns:		
		var from_node := graph.get_node(NodePath(c.from_node)) as GraphNode
		var to_node   := graph.get_node(NodePath(c.to_node))   as GraphNode
		if from_node == null or to_node == null: continue
		
		# Port anchor positions in GraphEdit space
		var p_out : Vector2 = from_node.position + from_node.get_output_port_position(c.from_port)
		var p_in : Vector2 = to_node.position + to_node.get_input_port_position(c.to_port)
		var mid   := (p_out + p_in) * 0.5
		
		# Convert GraphEdit-space to overlay's pixel space (account for pan+zoom)
		var screen := mid
		
		var key := _edge_key(c.from_node, c.from_port, c.to_node, c.to_port)
		#var w: Label = edge_widgets.get(key, null)
		var w: LineEdit = edge_widgets.get(key, null)
		if w:
			# small offset so text doesn’t sit exactly on the line
			w.position = screen + Vector2(8, -8)
			
func _input(event):
	if (event is InputEventKey and event.pressed):
		print("keycode: " + str(event.keycode))
	if save_shortcut.matches_event(event) and event.is_pressed() and not event.is_echo():
		print("Save shortcut pressed!")
		_save_file()
		get_viewport().set_input_as_handled()	

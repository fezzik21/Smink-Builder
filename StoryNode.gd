extends GraphNode
class_name StoryNode

@export var node_id: String = ""
@onready var body_field: TextEdit = $VBoxContainer/MarginContainer/TextEdit
@onready var title_edit: LineEdit = $VBoxContainer2/TitleEdit
@onready var hbox: VBoxContainer = $VBoxContainer2
@onready var textureRect: TextureRect = $TextureRect
@onready var lengthLabel: Label = $VBoxContainer/MarginContainer/Label

@export var LIMIT: int = 65535
var current_text = ''
var cursor_line = 0
var cursor_column = 0

func _ready():
	# Make the node look like a rounded rect (optional)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.20)
	sb.border_color = Color(0.35, 0.60, 1.0)
	#sb.border_width_all = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	add_theme_stylebox_override("panel", sb)

	# One input (left) and one output (right) port on row 0
	set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

	# Make the content fill the node nicely
	size = Vector2(260, 180)
	resizable = true  # let users resize; TextEdit will stretch
	
	title = "New Node"
	title_edit.visible = false
	title_edit.text_changed.connect(func(t): title = t)
	
	# Double-click anywhere in the node to focus the TextEdit
	gui_input.connect(_on_gui_input)

	# Enter/Esc behavior inside the TextEdit (optional)
	body_field.gui_input.connect(_on_body_gui_input)
	

func _process(_delta):
	# Hide if focus lost
	if title_edit.visible and not title_edit.has_focus():
		title_edit.visible = false
	hbox.position = position + Vector2(0.0, 43.0)
	textureRect.position = position + Vector2(228.0, 43.0)
	lengthLabel.text = str(body_field.text.length())
		
func _on_gui_input(e: InputEvent):
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.double_click:
		body_field.grab_focus()
		#if e is InputEventMouseButton and e.double_click and e.position.y < 24 and e.position.x > 236:
			# delete this node
			#var m : Main = (get_parent().get_parent().get_parent() as Main)
			#m._delete_node(name)
		if e is InputEventMouseButton and e.double_click and e.position.y < 24:
			# Show inline editor
			title_edit.visible = true
			title_edit.text = title
			title_edit.grab_focus()
			title_edit.select_all()
	
func _on_body_gui_input(e: InputEvent):
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_ESCAPE:
				# leave edit mode: move focus back to node titlebar so arrow keys pan graph again
				release_focus()
			KEY_ENTER, KEY_KP_ENTER:
				if e.alt_pressed or e.shift_pressed:
					return
				release_focus()
				
func _on_TextEdit_text_changed():
	var new_text : String = body_field.text
	if new_text.length() > LIMIT:
		body_field.text = current_text
		# when replacing the text, the curs or will get moved to the beginning of the
		# text, so move it back to where it was 
		
		body_field.set_caret_line(cursor_line)
		body_field.set_caret_column(cursor_column)
	
	current_text = body_field.text
	# save current position of cursor for when we have reached the limit
	cursor_line = body_field.get_caret_line()
	cursor_column = body_field.get_caret_column()

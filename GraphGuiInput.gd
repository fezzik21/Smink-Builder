extends GraphEdit


var selected_connection: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

		
func _gui_input(event: InputEvent) -> void:
	# Left click: pick the closest connection (if any)
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:		
		var conn: Dictionary = get_closest_connection_at_point(event.position, 6.0)
		if conn.is_empty():
			if !selected_connection.is_empty():
				set_connection_activity(
					selected_connection.from_node, selected_connection.from_port,
					selected_connection.to_node, selected_connection.to_port,
					0.0
				)
			selected_connection = Dictionary()
		else:
			if !selected_connection.is_empty():
				set_connection_activity(
					selected_connection.from_node, selected_connection.from_port,
					selected_connection.to_node, selected_connection.to_port,
					0.0
				)
			selected_connection = conn
			print("selected connection")			
			set_connection_activity(
				conn.from_node, conn.from_port,
				conn.to_node, conn.to_port,
				1.0
			)
	queue_redraw()

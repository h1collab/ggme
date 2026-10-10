extends Button

# Independent pointer capture allows aiming, firing and moving simultaneously.
# Mouse emulation supports only one touch, so combat buttons handle touch IDs.
var pointer_id := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visibility_changed.connect(func(): if not is_visible_in_tree(): release_pointer())

func release_pointer() -> void:
	if pointer_id == -1: return
	pointer_id = -1
	set_pressed_no_signal(false)
	button_up.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled: return
	if event is InputEventScreenTouch:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var inside := Rect2(Vector2.ZERO, size).has_point(point)
		if event.pressed and inside and pointer_id == -1:
			pointer_id = event.index
			set_pressed_no_signal(true)
			button_down.emit()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == pointer_id:
			release_pointer()
			if inside: pressed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		get_viewport().set_input_as_handled()

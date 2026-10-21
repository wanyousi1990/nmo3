@tool
extends AnimationPlayer
## 存檔前把 RESET／場景骨頭鎖回 idle，避免調 run 時站姿被寫進場景。

@export var idle_anim_name: StringName = &"idle" ## 站立片段名稱（TRES/ol_normal_idle.tres）
@export var idle_anim: Animation ## 站立姿勢來源；空則用 idle_anim_name


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_lock_reset_from_idle()
	_apply_idle_to_root()


func _notification(what: int) -> void:
	if what != NOTIFICATION_EDITOR_PRE_SAVE:
		return
	_lock_reset_from_idle()
	_apply_idle_to_root()


func _idle_source() -> Animation:
	if idle_anim != null:
		return idle_anim
	if has_animation(idle_anim_name):
		return get_animation(idle_anim_name)
	return null


func _lock_reset_from_idle() -> void:
	var src: Animation = _idle_source()
	if src == null or not has_animation(&"RESET"):
		return
	var dst: Animation = get_animation(&"RESET")
	if dst == null or dst == src:
		return
	_copy_animation(src, dst)


func _apply_idle_to_root() -> void:
	var src: Animation = _idle_source()
	if src == null:
		return
	var root: Node = get_node_or_null(root_node)
	if root == null:
		return
	for i in src.get_track_count():
		if src.track_get_type(i) != Animation.TYPE_VALUE:
			continue
		if not src.track_is_enabled(i):
			continue
		var bits: PackedStringArray = String(src.track_get_path(i)).split(":")
		if bits.size() < 2:
			continue
		var n: Node = root.get_node_or_null(NodePath(bits[0]))
		if n == null:
			continue
		n.set(bits[1], src.track_get_key_value(i, 0))


func _copy_animation(src: Animation, dst: Animation) -> void:
	while dst.get_track_count() > 0:
		dst.remove_track(0)
	dst.length = src.length
	dst.loop_mode = src.loop_mode
	dst.step = src.step
	for i in src.get_track_count():
		var track_type: int = src.track_get_type(i)
		var idx: int = dst.add_track(track_type)
		dst.track_set_path(idx, src.track_get_path(i))
		dst.track_set_interpolation_type(idx, src.track_get_interpolation_type(i))
		dst.track_set_enabled(idx, src.track_is_enabled(i))
		if track_type == Animation.TYPE_VALUE:
			dst.value_track_set_update_mode(idx, src.value_track_get_update_mode(i))
		for k in src.track_get_key_count(i):
			dst.track_insert_key(
				idx,
				src.track_get_key_time(i, k),
				src.track_get_key_value(i, k),
				src.track_get_key_transition(i, k)
			)

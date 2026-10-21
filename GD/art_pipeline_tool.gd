@tool
extends Node

## Inspector：選場景、選資料夾、點選 visual 根。匯出有的 PNG 才套到現有節點。
## NodePath 選單只看「這個工具 tscn 裡的節點」，所以按 0 會在左邊長出「視覺根候選」，不是把整隻女主掛進來。
const PIPELINE := "res://TOOLS/art_pipeline/pipeline.py"
const PICK_ROOT := "視覺根候選"

@export var python_exe: String = "py" ## 系統的 Python；不行就改成 python

@export_group("要改哪裡")
@export_file("*.tscn") var target_scene: String = "res://TSCN/character_body_2d.tscn" ## 女主或怪物場景
@export var visual_root: NodePath ## 按 0 之後，從「視覺根候選」裡點（不要點 ArtPipelineTool 自己）
@export var visual_root_path: String = "Visuals/Normal_Visual" ## 真正拿去組裝的路徑；選完會自動填

@export_group("圖從哪裡來／寫到哪")
@export_dir var png_folder: String = "res://TOOLS/art_pipeline/_preview/from_krita" ## Krita 匯出的 PNG
@export_dir var art_folder: String = "res://ART" ## 正式組裝複製到這裡（會再分子資料夾）

@export_group("按鈕")
@export_tool_button("0 載入目標場景（左邊會出現「視覺根候選」）") var _btn_load: Callable = _load_target_scene
@export_tool_button("0b 列出可選 visual 根") var _btn_list: Callable = _list_roots
@export_tool_button("1 掃描現有節點（只寫檔名對照）") var _btn_scan: Callable = _scan
@export_tool_button("2 預覽組裝（只寫 _preview）") var _btn_preview: Callable = _assemble_preview
@export_tool_button("3 正式組裝") var _btn_apply: Callable = _assemble_apply
@export_tool_button("4 selftest") var _btn_selftest: Callable = _selftest


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_sync_path_from_pick()
		_clear_picks()


func _load_target_scene() -> void:
	_clear_picks()
	var path := target_scene.strip_edges()
	if path == "":
		print("[art_pipeline] 先用資料夾圖示選 target_scene（女主 character_body_2d.tscn）")
		return
	var abs_path := ProjectSettings.globalize_path(path)
	var fa := FileAccess.open(abs_path, FileAccess.READ)
	if fa == null:
		print("[art_pipeline] 讀不到場景：", path)
		return
	var roots := _parse_visual_roots(fa.get_as_text())
	fa.close()
	if roots.is_empty():
		print("[art_pipeline] 這份場景沒找到 Visual／H_Pose／Visaul")
		return
	var folder := Node.new()
	folder.name = PICK_ROOT
	add_child(folder)
	folder.owner = self
	var used: Dictionary = {}
	for full in roots:
		var n := Node.new()
		var nm := String(full).replace("/", "／")
		if used.has(nm):
			continue
		used[nm] = true
		n.name = nm
		n.set_meta("pose_root", String(full))
		folder.add_child(n)
		n.owner = self
	print("[art_pipeline] 左邊 Scene 樹展開「", PICK_ROOT, "」，再把 visual_root 指到其中一個。候選 ", roots.size(), " 個：")
	for full in roots:
		print("  ", full)


func _clear_picks() -> void:
	var old := get_node_or_null(PICK_ROOT)
	if old:
		remove_child(old)
		old.free()


func _list_roots() -> void:
	_run(["list-roots", _res_to_rel(target_scene)])


func _scan() -> void:
	var root := _pose_root_in_scene()
	if root == "":
		print("[art_pipeline] 請按 0，再在 visual_root 選「視覺根候選」底下的節點")
		return
	var pid := _pose_id(root)
	var args: PackedStringArray = ["scan-tscn", _res_to_rel(target_scene), "--pose-root", root, "--pose-id", pid]
	var art := _art_dir_rel(pid)
	if art != "":
		args.append_array(["--art-dir", art])
	args.append_array(["--out", "TOOLS/art_pipeline/specs/%s.json" % pid])
	_run(args)


func _assemble_preview() -> void:
	_assemble(false)


func _assemble_apply() -> void:
	_assemble(true)


func _assemble(apply: bool) -> void:
	var root := _pose_root_in_scene()
	if root == "":
		print("[art_pipeline] 請按 0，再在 visual_root 選「視覺根候選」底下的節點")
		return
	var pid := _pose_id(root)
	var args: PackedStringArray = [
		"assemble",
		"--scene", _res_to_rel(target_scene),
		"--pose-root", root,
		"--pose-id", pid,
		"--png-dir", _res_to_rel(png_folder),
		"--art-dir", _art_dir_rel(pid),
	]
	if apply:
		args.append("--apply")
	_run(args)


func _selftest() -> void:
	_run(["selftest"])


func _sync_path_from_pick() -> void:
	var picked := _path_from_nodepath()
	if picked != "":
		visual_root_path = picked


func _path_from_nodepath() -> String:
	if visual_root.is_empty():
		return ""
	if not has_node(visual_root):
		return ""
	var n := get_node(visual_root)
	if n.has_meta("pose_root"):
		return String(n.get_meta("pose_root"))
	return ""


func _pose_root_in_scene() -> String:
	_sync_path_from_pick()
	return visual_root_path.strip_edges()


func _parse_visual_roots(tscn_text: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	var regex := RegEx.new()
	regex.compile("\\[node name=\"([^\"]+)\" type=\"([^\"]+)\"(?: parent=\"([^\"]+)\")?")
	for m in regex.search_all(tscn_text):
		var nname := m.get_string(1)
		var ntype := m.get_string(2)
		var parent := m.get_string(3)
		if ntype != "Node2D":
			continue
		var full := nname
		if parent != "" and parent != ".":
			full = parent + "/" + nname
		var low := nname.to_lower()
		if "visual" in low or "visaul" in low or low.begins_with("h_pose"):
			paths.append(full)
	return paths


func _pose_id(root: String) -> String:
	var leaf := root.get_file() if root != "" else _res_to_rel(target_scene).get_file().get_basename()
	return leaf.to_lower()


func _art_dir_rel(pose_id: String) -> String:
	var folder := _res_to_rel(art_folder).replace("\\", "/")
	if folder == "" or folder == "ART":
		return "ART/%s" % pose_id
	return folder


func _res_to_rel(res_path: String) -> String:
	if res_path.begins_with("res://"):
		return res_path.substr(6)
	return res_path


func _run(pipeline_args: PackedStringArray) -> void:
	var script: String = ProjectSettings.globalize_path(PIPELINE)
	var argv: PackedStringArray = [script]
	argv.append_array(pipeline_args)
	print("[art_pipeline] ", python_exe, " ", " ".join(argv))
	var output: Array = []
	var code: int = OS.execute(python_exe, argv, output, true, true)
	for line in output:
		print(line)
	print("[art_pipeline] exit=", code)

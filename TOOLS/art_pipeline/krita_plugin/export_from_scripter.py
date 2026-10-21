# Krita Scripter：依規格匯出圖層 PNG（名稱開頭 _ 的層會跳過）
from krita import Krita, InfoObject
import json
from pathlib import Path

SPEC_PATH = r"D:\FILES\GOODGAME\nmo3\TOOLS\art_pipeline\specs\h_pose_01.json"
PNG_DIR = r"D:\FILES\GOODGAME\nmo3\TOOLS\art_pipeline\_preview\from_krita"

spec = json.loads(Path(SPEC_PATH).read_text(encoding="utf-8"))
out = Path(PNG_DIR)
out.mkdir(parents=True, exist_ok=True)
doc = Krita.instance().activeDocument()
if doc is None:
    raise RuntimeError("請先在 Krita 打開該姿勢的 kra")

wanted = {p.get("krita_layer") for p in spec.get("parts", []) if p.get("krita_layer")}
pose_id = spec.get("pose_id", "pose")
root = doc.rootNode()
orig_visible = {}


def collect(n):
    orig_visible[n.uniqueId()] = n.visible()
    for c in n.childNodes():
        collect(c)


def hide_all(n):
    n.setVisible(False)
    for c in n.childNodes():
        hide_all(c)


def find_by_name(n, target):
    if n.name() == target:
        return n
    for c in n.childNodes():
        hit = find_by_name(c, target)
        if hit:
            return hit
    return None


def restore(n):
    uid = n.uniqueId()
    if uid in orig_visible:
        n.setVisible(orig_visible[uid])
    for c in n.childNodes():
        restore(c)


collect(root)
exported = 0
info = InfoObject()
for layer_name in wanted:
    if not layer_name or str(layer_name).startswith("_"):
        continue
    node = find_by_name(root, layer_name)
    if node is None:
        print("找不到圖層:", layer_name)
        continue
    hide_all(root)
    node.setVisible(True)
    p = node.parentNode()
    while p is not None:
        p.setVisible(True)
        p = p.parentNode()
    doc.refreshProjection()
    dest = out / f"{pose_id}_{layer_name}.png"
    doc.exportImage(str(dest), info)
    exported += 1
    print("exported", dest)

restore(root)
doc.refreshProjection()
print("done", exported)

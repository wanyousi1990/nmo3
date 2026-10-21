#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""NMO3 美術管線：匯出有哪張 PNG，就套到現有對應 Sprite。沒匯出的節點不動。"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PREVIEW_DIR = Path(__file__).resolve().parent / "_preview"
SPECS_DIR = Path(__file__).resolve().parent / "specs"

# 只跳過嵌在姿勢裡的伙伴／特效，不要用 monster 這種字以免掃不到怪物 Visaul
NESTED_SKIP = (
    "FM_H_Pose",
    "SM_H_Pose",
    "M02_H",
    "M03_H",
    "SM_TITS",
    "Escape_",
    "Sfx",
    "H_FX",
)

PARTS = (
    "Torso",
    "Pelvis",
    "Hip_L",
    "Hip_R",
    "Thigh_L",
    "Thigh_R",
    "Calf_L",
    "Calf_R",
    "Arm_L",
    "Arm_R",
    "Forearm_L",
    "Forearm_R",
    "Breast_L",
    "Breast_R",
    "Head",
    "HairFront",
    "HairBack",
    "Pussy",
    "Eye",
    "Mouth",
    "Dick",
    "Hand",
)
STATES = ("Naked", "Clothed", "Bra", "ShirtOpen", "Lewd", "Iku", "Overlay")
STATE_TOKEN = {
    "NAKED": "Naked",
    "CLOTHED": "Clothed",
    "CLOTH": "Clothed",
    "SHIRTOPEN": "ShirtOpen",
    "BRAOPEN": "Bra",
    "BRA": "Bra",
    "LEWD": "Lewd",
    "IKU": "Iku",
    "OVERLAY": "Overlay",
}


def rel(p: Path) -> str:
    return p.resolve().relative_to(ROOT).as_posix()


def strip_sprite_prefix(name: str) -> str:
    raw = name
    for prefix in ("Sprite2D_", "Sprite_", "Sprite2D", "Sprite"):
        if raw.startswith(prefix):
            raw = raw[len(prefix) :]
            break
    return raw.strip("_")


def guess_krita_layer(node_name: str, parent_name: str) -> str:
    raw = strip_sprite_prefix(node_name).replace("-", "_")
    if not raw:
        raw = parent_name

    if raw in ("Bra_L", "Bra_R"):
        return f"Breast_{raw[-1]}_Bra"
    if raw.startswith("ShirtOpen_"):
        return f"Breast_{raw[-1]}_ShirtOpen"
    if raw.startswith("BraOpen_"):
        return f"Breast_{raw[-1]}_Bra"

    upper = raw.upper()
    for key, pretty in STATE_TOKEN.items():
        if upper.endswith("_" + key) or upper == key:
            body = raw[: -len(key)].rstrip("_") if upper.endswith(key) else parent_name
            if not body:
                body = parent_name
            if body.upper().startswith("UPPERARM"):
                body = parent_name or body
            if body.upper().startswith("FOREARM"):
                body = parent_name or "Forearm"
            return f"{body}_{pretty}" if body else pretty

    if upper.endswith("2") and not upper.endswith("SHIRTOPEN"):
        body = raw[:-1].rstrip("_")
        if body.upper().startswith("UPPERARM"):
            body = parent_name or body
        if body.upper().startswith("FOREARM"):
            body = parent_name or body
        if not body:
            body = parent_name
        return f"{body}_Clothed" if body else "Clothed"

    if parent_name == "Hair" or raw in ("Hair", "HairFront"):
        return "HairFront"
    if raw == "HairBack":
        return "HairBack"
    if raw.upper().startswith("UPPERARM"):
        return f"{parent_name}_Naked" if parent_name else "Arm_Naked"
    if raw.upper().startswith("FOREARM"):
        return f"{parent_name}_Naked" if parent_name else "Forearm_Naked"
    if parent_name in PARTS:
        if not raw or raw.upper() == parent_name.upper():
            return f"{parent_name}_Naked"
        return f"{parent_name}_{raw}"
    if raw in PARTS:
        return f"{raw}_Naked"
    return raw or node_name


def part_keys(part: dict) -> set[str]:
    keys: set[str] = set()
    layer = part.get("krita_layer") or ""
    node = part.get("node") or ""
    leaf = Path(node).name
    parent_name = Path(node).parent.name if "/" in node else ""
    keys.add(layer)
    keys.add(leaf)
    keys.add(strip_sprite_prefix(leaf))
    guessed = guess_krita_layer(leaf, parent_name)
    keys.add(guessed)
    for s in STATES:
        if layer.endswith("_" + s):
            keys.add(layer[: -(len(s) + 1)])
            break
    return {k for k in keys if k}


def normalize_png_stem(stem: str, pose_id: str) -> str:
    s = stem
    if s.lower().endswith(".png"):
        s = s[: -4]
    pid = (pose_id or "").strip()
    if pid and s.lower().startswith(pid.lower() + "_"):
        s = s[len(pid) + 1 :]
    return s


def match_png_to_part(stem: str, parts: list[dict], pose_id: str) -> dict | None:
    want = normalize_png_stem(stem, pose_id)
    if not want or want.startswith("_"):
        return None
    exact = [p for p in parts if (p.get("krita_layer") or "") == want]
    if len(exact) == 1:
        return exact[0]
    ci = [p for p in parts if (p.get("krita_layer") or "").lower() == want.lower()]
    if len(ci) == 1:
        return ci[0]
    hits = []
    for p in parts:
        keys = {k.lower() for k in part_keys(p)}
        if want.lower() in keys:
            hits.append(p)
    if len(hits) == 1:
        return hits[0]
    if len(hits) > 1:
        no_state = not any(want.lower().endswith("_" + s.lower()) for s in STATES)
        if no_state:
            naked = [p for p in hits if (p.get("krita_layer") or "").endswith("_Naked")]
            if len(naked) == 1:
                return naked[0]
        print("PNG 對到多個節點，略過:", want, "→", [h.get("node") for h in hits])
        return None
    return None


def parse_tscn_sprites(tscn_text: str, pose_root: str) -> list[dict]:
    ext: dict[str, str] = {}
    for m in re.finditer(
        r'\[ext_resource[^\]]*type="Texture2D"[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"',
        tscn_text,
    ):
        ext[m.group(2)] = m.group(1)
    for m in re.finditer(
        r'\[ext_resource[^\]]*id="([^"]+)"[^\]]*type="Texture2D"[^\]]*path="([^"]+)"',
        tscn_text,
    ):
        ext[m.group(1)] = m.group(2)

    nodes: list[dict] = []
    current = None
    pose_prefix = pose_root.strip("/")
    for line in tscn_text.splitlines():
        nm = re.match(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?', line)
        if nm:
            name, ntype, parent = nm.group(1), nm.group(2), nm.group(3) or ""
            if parent == ".":
                full = name
            elif parent:
                full = f"{parent}/{name}"
            else:
                full = name
            current = {
                "name": name,
                "type": ntype,
                "parent": parent,
                "full": full,
                "texture_id": "",
            }
            nodes.append(current)
            continue
        if current and line.startswith("texture = ExtResource("):
            mid = re.search(r'ExtResource\("([^"]+)"\)', line)
            if mid:
                current["texture_id"] = mid.group(1)

    parts = []
    for n in nodes:
        if n["type"] != "Sprite2D":
            continue
        if n["name"] in ("Sprite2D", "Sprite"):
            continue
        full = n["full"]
        if pose_prefix:
            if full != pose_prefix and not full.startswith(pose_prefix + "/"):
                continue
            local = full[len(pose_prefix) :].lstrip("/") if full != pose_prefix else n["name"]
        else:
            local = full
        if any(bit.lower() in local.lower() for bit in NESTED_SKIP):
            continue
        parent_name = Path(n["parent"]).name if n["parent"] else ""
        parts.append(
            {
                "node": local,
                "krita_layer": guess_krita_layer(n["name"], parent_name),
                "fill": False,
                "current_texture": ext.get(n["texture_id"], ""),
            }
        )
    return parts


def list_visual_roots(tscn_text: str) -> list[str]:
    paths: list[str] = []
    for line in tscn_text.splitlines():
        nm = re.match(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?', line)
        if not nm:
            continue
        name, ntype, parent = nm.group(1), nm.group(2), nm.group(3) or ""
        if ntype != "Node2D":
            continue
        if parent == ".":
            full = name
        elif parent:
            full = f"{parent}/{name}"
        else:
            full = name
        low = name.lower()
        if any(
            tok in low
            for tok in (
                "visual",
                "visaul",
                "h_pose",
                "normal_visual",
                "dash_visual",
            )
        ):
            paths.append(full)
    return paths


def cmd_scan(args: argparse.Namespace) -> int:
    scene = (ROOT / args.scene).resolve() if not Path(args.scene).is_absolute() else Path(args.scene)
    if not scene.exists():
        print("找不到場景:", scene)
        return 1
    text = scene.read_text(encoding="utf-8")
    pose_root = args.pose_root or ""
    if not pose_root:
        roots = list_visual_roots(text)
        print("沒指定 visual 根。請選一個，例如:")
        for r in roots:
            print("  ", r)
        if not roots:
            print("  （整份場景的根，怪物 Visaul 也可直接當根）")
        return 1
    parts = parse_tscn_sprites(text, pose_root)
    pose_id = args.pose_id or Path(pose_root).name.lower() or scene.stem
    art_dir = args.art_dir or f"ART/{pose_id}"
    out = Path(args.out) if args.out else SPECS_DIR / f"{pose_id}.json"
    if not out.is_absolute():
        out = ROOT / out
    out.parent.mkdir(parents=True, exist_ok=True)
    spec = {
        "pose_id": pose_id,
        "scene": rel(scene),
        "pose_root": pose_root,
        "art_dir": art_dir.replace("\\", "/"),
        "preview_scene": f"TOOLS/art_pipeline/_preview/{pose_id}.tscn",
        "parts": parts,
    }
    out.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("已寫規格:", rel(out), "現有 Sprite 數=", len(parts))
    print("Krita／PNG 檔名對 krita_layer。沒畫的層不用匯出，組裝時那些節點維持原圖。")
    return 0


def cmd_list_roots(args: argparse.Namespace) -> int:
    scene = (ROOT / args.scene).resolve() if not Path(args.scene).is_absolute() else Path(args.scene)
    if not scene.exists():
        print("找不到場景:", scene)
        return 1
    roots = list_visual_roots(scene.read_text(encoding="utf-8"))
    print("可選 visual 根:")
    if not roots:
        print("  （沒找到 *Visual*／H_Pose；怪物可選 Visaul）")
        return 0
    for r in roots:
        print(" ", r)
    return 0


def list_pngs(png_dir: Path) -> list[Path]:
    out: list[Path] = []
    for p in sorted(png_dir.rglob("*.png")):
        if p.name.startswith(".") or p.name.endswith(".import"):
            continue
        if p.name.startswith("_"):
            continue
        out.append(p)
    return out


def next_artp_id(existing: set[str], n: int) -> str:
    i = n
    while True:
        eid = f"artp_{i}"
        if eid not in existing:
            return eid
        i += 1


def rewrite_textures(tscn_text: str, pose_root: str, node_to_res: dict[str, str]) -> str:
    """每個要換圖的節點用自己的 ExtResource，避免共用舊貼圖時一次改到兩個 Sprite。"""
    existing_ids: set[str] = set(re.findall(r'\bid="([^"]+)"', tscn_text))
    pose_prefix = pose_root.strip("/")
    lines = tscn_text.splitlines(keepends=True)
    current_full = ""
    current_name = ""
    node_header_idx: dict[str, int] = {}
    node_tex_line: dict[str, int] = {}

    for i, line in enumerate(lines):
        nm = re.match(r'\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?', line)
        if nm:
            current_name, parent = nm.group(1), nm.group(3) or ""
            if parent == ".":
                current_full = current_name
            elif parent:
                current_full = f"{parent}/{current_name}"
            else:
                current_full = current_name
            local = current_full
            if pose_prefix:
                if current_full == pose_prefix:
                    local = current_name
                elif current_full.startswith(pose_prefix + "/"):
                    local = current_full[len(pose_prefix) + 1 :]
                else:
                    local = ""
            if local:
                node_header_idx[local] = i
            continue
        if not current_full:
            continue
        local = current_full
        if pose_prefix:
            if current_full == pose_prefix:
                local = current_name
            elif current_full.startswith(pose_prefix + "/"):
                local = current_full[len(pose_prefix) + 1 :]
            else:
                continue
        if re.search(r"texture = ExtResource\(", line) and local:
            node_tex_line[local] = i

    new_ext_lines: list[str] = []
    seq = 1
    for node, new_res in node_to_res.items():
        eid = next_artp_id(existing_ids, seq)
        existing_ids.add(eid)
        seq += 1
        new_ext_lines.append(f'[ext_resource type="Texture2D" path="{new_res}" id="{eid}"]\n')
        tex_line = f'texture = ExtResource("{eid}")\n'
        if node in node_tex_line:
            old = lines[node_tex_line[node]]
            nl = "\n" if old.endswith("\n") else ""
            indent = re.match(r"^(\s*)", old).group(1)
            lines[node_tex_line[node]] = f"{indent}{tex_line.rstrip()}{nl}"
        elif node in node_header_idx:
            insert_at = node_header_idx[node] + 1
            lines.insert(insert_at, tex_line)
            # 後面 index 位移
            for k, idx in list(node_header_idx.items()):
                if idx >= insert_at:
                    node_header_idx[k] = idx + 1
            for k, idx in list(node_tex_line.items()):
                if idx >= insert_at:
                    node_tex_line[k] = idx + 1
            node_tex_line[node] = insert_at
        else:
            print("場景裡找不到節點，沒寫貼圖:", node)

    if new_ext_lines:
        last_ext = 0
        for i, line in enumerate(lines):
            if line.startswith("[ext_resource"):
                last_ext = i
        insert_at = last_ext + 1
        for j, ext_line in enumerate(new_ext_lines):
            lines.insert(insert_at + j, ext_line)
        m = re.search(r"load_steps=(\d+)", lines[0])
        if m:
            lines[0] = lines[0].replace(
                m.group(0), f"load_steps={int(m.group(1)) + len(new_ext_lines)}", 1
            )

    return "".join(lines)


def load_or_build_spec(args: argparse.Namespace) -> tuple[dict | None, Path | None]:
    spec_arg = getattr(args, "spec", None) or ""
    scene_arg = getattr(args, "scene", None) or ""
    pose_root = getattr(args, "pose_root", None) or ""
    if spec_arg:
        spec_path = Path(spec_arg)
        if not spec_path.is_absolute():
            spec_path = ROOT / spec_path
        if not spec_path.exists():
            print("找不到規格:", spec_path)
            return None, None
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        if pose_root:
            spec["pose_root"] = pose_root
        if scene_arg:
            spec["scene"] = scene_arg.replace("\\", "/")
        if getattr(args, "art_dir", None):
            spec["art_dir"] = args.art_dir.replace("\\", "/")
        if getattr(args, "pose_id", None):
            spec["pose_id"] = args.pose_id
        return spec, spec_path
    if not scene_arg:
        print("請提供規格 JSON，或 --scene 加上 --pose-root")
        return None, None
    scene = ROOT / scene_arg if not Path(scene_arg).is_absolute() else Path(scene_arg)
    if not scene.exists():
        print("找不到場景:", scene)
        return None, None
    text = scene.read_text(encoding="utf-8")
    if not pose_root:
        print("沒指定 --pose-root。可選:")
        for r in list_visual_roots(text):
            print("  ", r)
        return None, None
    parts = parse_tscn_sprites(text, pose_root)
    pose_id = getattr(args, "pose_id", None) or Path(pose_root).name.lower() or scene.stem
    art_dir = getattr(args, "art_dir", None) or f"ART/{pose_id}"
    spec = {
        "pose_id": pose_id,
        "scene": rel(scene),
        "pose_root": pose_root,
        "art_dir": art_dir.replace("\\", "/"),
        "preview_scene": f"TOOLS/art_pipeline/_preview/{pose_id}.tscn",
        "parts": parts,
    }
    return spec, None


def cmd_assemble(args: argparse.Namespace) -> int:
    spec, _spec_path = load_or_build_spec(args)
    if spec is None:
        return 1
    png_dir = Path(args.png_dir)
    if not png_dir.is_absolute():
        png_dir = ROOT / png_dir
    if not png_dir.exists():
        print("找不到 PNG 資料夾:", png_dir)
        return 1

    pose_id = spec.get("pose_id", "pose")
    pose_root = spec.get("pose_root", "")
    scene_rel = spec.get("scene", "")
    art_dir = spec.get("art_dir", f"ART/{pose_id}")
    apply = bool(args.apply)
    parts = spec.get("parts", [])

    dest_dir = ROOT / art_dir if apply else PREVIEW_DIR / pose_id
    dest_dir.mkdir(parents=True, exist_ok=True)

    node_to_res: dict[str, str] = {}
    unmatched_png: list[str] = []
    applied_layers: list[str] = []
    for src in list_pngs(png_dir):
        stem = src.stem
        if stem.lower().endswith(".png"):
            stem = Path(stem).stem
        part = match_png_to_part(stem, parts, pose_id)
        if part is None:
            unmatched_png.append(src.name)
            continue
        node = part.get("node") or ""
        layer = part.get("krita_layer") or stem
        dest = dest_dir / f"{pose_id}_{layer}.png"
        shutil.copy2(src, dest)
        node_to_res[node] = "res://" + rel(dest)
        applied_layers.append(f"{src.name} → {node}")

    print("這次有匯出、已套到節點:", len(node_to_res), "寫入", rel(dest_dir))
    for line in applied_layers:
        print("  ", line)
    skipped_nodes = [p.get("node") for p in parts if p.get("node") not in node_to_res]
    if skipped_nodes:
        print("沒匯出的節點維持原圖（不用刪）:", len(skipped_nodes))
        for n in skipped_nodes:
            print("  ", n)
    if unmatched_png:
        print("資料夾裡對不到現有節點的 PNG:")
        for n in unmatched_png:
            print("  ", n)

    if not node_to_res:
        print("沒有任何 PNG 對到節點，場景沒改。")
        return 0

    scene_src = ROOT / scene_rel
    if not scene_src.exists():
        print("找不到場景，只複製了 PNG:", scene_src)
        return 0

    new_text = rewrite_textures(scene_src.read_text(encoding="utf-8"), pose_root, node_to_res)
    if apply:
        scene_src.write_text(new_text, encoding="utf-8")
        print("已寫入正式場景:", scene_rel)
    else:
        preview_rel = spec.get("preview_scene") or f"TOOLS/art_pipeline/_preview/{pose_id}.tscn"
        preview = ROOT / preview_rel
        preview.parent.mkdir(parents=True, exist_ok=True)
        preview.write_text(new_text, encoding="utf-8")
        print("預覽場景:", preview_rel, "（未改正式檔，確認後再正式組裝）")
    return 0


def write_scripter(spec_rel: str, png_rel: str, out: Path) -> None:
    spec_abs = str((ROOT / spec_rel).resolve())
    png_abs = str((ROOT / png_rel).resolve())
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        f'''# Krita Scripter：依規格匯出圖層 PNG（名稱開頭 _ 的層會跳過）
from krita import Krita, InfoObject
import json
from pathlib import Path

SPEC_PATH = r"{spec_abs}"
PNG_DIR = r"{png_abs}"

spec = json.loads(Path(SPEC_PATH).read_text(encoding="utf-8"))
out = Path(PNG_DIR)
out.mkdir(parents=True, exist_ok=True)
doc = Krita.instance().activeDocument()
if doc is None:
    raise RuntimeError("請先在 Krita 打開該姿勢的 kra")

wanted = {{p.get("krita_layer") for p in spec.get("parts", []) if p.get("krita_layer")}}
pose_id = spec.get("pose_id", "pose")
root = doc.rootNode()
orig_visible = {{}}


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
# 有畫的圖層才匯出；規格裡有、Krita 沒有的層會跳過
for layer_name in wanted:
    if not layer_name or str(layer_name).startswith("_"):
        continue
    node = find_by_name(root, layer_name)
    if node is None:
        print("Krita 沒有這層，跳過:", layer_name)
        continue
    hide_all(root)
    node.setVisible(True)
    p = node.parentNode()
    while p is not None:
        p.setVisible(True)
        p = p.parentNode()
    doc.refreshProjection()
    dest = out / f"{{pose_id}}_{{layer_name}}.png"
    doc.exportImage(str(dest), info)
    exported += 1
    print("exported", dest)

restore(root)
doc.refreshProjection()
print("done", exported)
''',
        encoding="utf-8",
    )
    print("已寫 Scripter 腳本:", rel(out))


def cmd_export_krita_script(args: argparse.Namespace) -> int:
    spec = args.spec or "TOOLS/art_pipeline/specs/h_pose_01.json"
    png = args.png_dir or "TOOLS/art_pipeline/_preview/from_krita"
    out = Path(args.out) if args.out else Path(__file__).resolve().parent / "krita_plugin" / "export_from_scripter.py"
    if not out.is_absolute():
        out = ROOT / out
    write_scripter(spec, png, out)
    return 0


def cmd_selftest(args: argparse.Namespace) -> int:
    pngs = Path(__file__).resolve().parent / "_selftest_pngs"
    pngs.mkdir(parents=True, exist_ok=True)
    scene = ROOT / "TSCN" / "h_pose_01.tscn"
    if not scene.exists():
        print("selftest 需要 TSCN/h_pose_01.tscn")
        return 1
    spec_out = SPECS_DIR / "_selftest.json"
    rc = cmd_scan(
        argparse.Namespace(
            scene=str(scene.relative_to(ROOT)),
            pose_root="",
            pose_id="h_pose_01",
            art_dir="ART/H_POSE1",
            out=str(spec_out),
        )
    )
    # 獨立 h_pose_01 沒有 Visual 根名稱時，用空根會失敗；改掃整份
    if rc != 0:
        text = scene.read_text(encoding="utf-8")
        parts = parse_tscn_sprites(text, "")
        spec = {
            "pose_id": "h_pose_01",
            "scene": rel(scene),
            "pose_root": "",
            "art_dir": "ART/H_POSE1",
            "preview_scene": "TOOLS/art_pipeline/_preview/h_pose_01.tscn",
            "parts": parts,
        }
        spec_out.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("selftest 改掃整份 h_pose_01，零件數=", len(parts))
    spec = json.loads(spec_out.read_text(encoding="utf-8"))
    png_bytes = (
        b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
        b"\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00"
        b"\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
    )
    # 只放兩張，確認沒匯出的節點不會害組裝失敗
    for part in spec.get("parts", [])[:2]:
        layer = part["krita_layer"]
        (pngs / f"{layer}.png").write_bytes(png_bytes)
    rc = cmd_assemble(
        argparse.Namespace(
            spec=str(spec_out),
            png_dir=str(pngs),
            apply=False,
            scene="",
            pose_root="",
            art_dir="",
            pose_id="",
        )
    )
    print("selftest", "OK" if rc == 0 else "FAIL")
    return rc


def main() -> int:
    p = argparse.ArgumentParser(description="NMO3 美術管線")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("scan-tscn", help="掃描現有 Sprite，寫出檔名對照（不刪節點）")
    s.add_argument("scene")
    s.add_argument("--pose-root", default="", help="Normal_Visual／H_Pose_01／怪物 Visaul")
    s.add_argument("--pose-id", default="")
    s.add_argument("--art-dir", default="")
    s.add_argument("--out", default="")
    s.set_defaults(func=cmd_scan)

    lr = sub.add_parser("list-roots", help="列出場景裡可選的 visual 根")
    lr.add_argument("scene")
    lr.set_defaults(func=cmd_list_roots)

    a = sub.add_parser("assemble", help="資料夾裡有的 PNG 才套到對應節點")
    a.add_argument("spec", nargs="?", default="")
    a.add_argument("png_dir", nargs="?", default="")
    a.add_argument("--spec", dest="spec_opt", default="")
    a.add_argument("--png-dir", dest="png_dir_opt", default="")
    a.add_argument("--scene", default="")
    a.add_argument("--pose-root", default="")
    a.add_argument("--pose-id", default="")
    a.add_argument("--art-dir", default="")
    a.add_argument("--apply", action="store_true", help="寫入正式 scene / ART")
    a.set_defaults(func=_cmd_assemble_wrap)

    k = sub.add_parser("export-krita-script", help="產生 Krita Scripter 匯出腳本")
    k.add_argument("--spec", default="TOOLS/art_pipeline/specs/h_pose_01.json")
    k.add_argument("--png-dir", default="TOOLS/art_pipeline/_preview/from_krita")
    k.add_argument("--out", default="")
    k.set_defaults(func=cmd_export_krita_script)

    t = sub.add_parser("selftest")
    t.set_defaults(func=cmd_selftest)

    args = p.parse_args()
    return args.func(args)


def _cmd_assemble_wrap(args: argparse.Namespace) -> int:
    spec = args.spec_opt or args.spec
    png_dir = args.png_dir_opt or args.png_dir
    args.spec = spec
    args.png_dir = png_dir
    if not args.png_dir:
        print("請指定 PNG 資料夾")
        return 1
    return cmd_assemble(args)


if __name__ == "__main__":
    sys.exit(main())

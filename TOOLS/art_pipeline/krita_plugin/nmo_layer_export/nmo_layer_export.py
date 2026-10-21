# Krita 外掛：讀 art_pipeline 規格，把對得上的圖層匯成 PNG
from krita import Extension, Krita, InfoObject
import json
from pathlib import Path


class NmoLayerExportExtension(Extension):
    def __init__(self, parent):
        super().__init__(parent)
        self._spec = ""
        self._png_dir = ""

    def setup(self):
        pass

    def createActions(self, window):
        action = window.createAction("nmo_export_layers", "NMO：依規格匯出圖層", "tools/scripts")
        action.triggered.connect(self.export_layers)

    def export_layers(self):
        spec_path = Path(self._spec) if self._spec else None
        if spec_path is None or not spec_path.exists():
            print("請先在 Scripter 設 SPEC，或用 export_from_scripter.py")
            return
        spec = json.loads(spec_path.read_text(encoding="utf-8"))
        print("規格零件數", len(spec.get("parts", [])))
        print("請改用 Tools/art_pipeline/krita_plugin/export_from_scripter.py 匯出（路徑已寫死較不容易點錯）")

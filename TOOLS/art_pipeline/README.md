# art_pipeline

第三款重畫用。組裝只把**資料夾裡有的 PNG**套到現有 Sprite；沒匯出的節點不動。預設寫到 `TOOLS/art_pipeline/_preview/`。

女主：`Normal_Visual`、`Dash_Visual`、`Visuals/OL_H_Visual/H_Pose_*`。怪物：場景裡的 `Visaul`。

開啟 `TSCN/art_pipeline_tool.tscn`，Inspector 用選檔／選資料夾／點選節點，不要打路徑。

```
py TOOLS/art_pipeline/pipeline.py selftest
py TOOLS/art_pipeline/pipeline.py list-roots TSCN/character_body_2d.tscn
py TOOLS/art_pipeline/pipeline.py assemble --scene TSCN/character_body_2d.tscn --pose-root Visuals/Normal_Visual --png-dir TOOLS/art_pipeline/_preview/from_krita
```

# 项目规则（AGENTS.md）

## 1. 省 token（最高优先级）
- 回复**尽量短**：说清"改了什么 + 怎么验证"即可，默认 1 张截图、不重复贴图。
- 一次命令批量改/查；不整段打印文件、不输出大段 Godot 报错、不跑整局游戏（用 `--quit-after` 或预览工程）。
- 细节参数查 `docs/视觉改造记录.md`，不要塞回本文件。
- 大改前一句话确认；小改直接做。

## 2. 任务完成必须弹窗 + 声音
```
pwsh -NoProfile -File tools/notify.ps1 -Text "一句话说明完成了什么"
```

## 3. 视觉方向（已定）
- 玩具沙盘低模 + Q 版（大头大眼腮红短腿）；全部程序化模型，不用旧 GLB。
- 单位/建筑 ×1.5，`UnitModelKit` + `CardVisualCatalog`；子弹 `ProjectileKit`（16 种）。
- 着色 `toon_unit.gdshader`；状态用 instance uniform。

## 4. 范围与验证
- 只改视觉层：数值/碰撞/卡牌逻辑/存档不动；旧资源保留仅不引用。
- 预览工具在 `tools/preview/`（独立工程）。
- **光影/材质必须用 Compatibility 渲染器验证**（编辑器/手机实际一致）：
  ```
  $env:CR_DEV_SCENE='res://scenes/battle.tscn'; $env:CR_DEV_SHOT='res://tools/battle_shot_compat.png'
  godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
  ```
  Vulkan 仅用于对比：`--rendering-method mobile --rendering-driver vulkan`。

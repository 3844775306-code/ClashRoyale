<div align="center">

<img src="icon.svg" width="140" alt="Clash Royale toy diorama icon">

# 皇室战争 · Toy Diorama

程序化低模 Q 版皇室战争同人项目 · Godot 4.7.2

[网页版](https://3844775306-code.github.io/ClashRoyale/) · [Releases（Windows / Android）](https://github.com/3844775306-code/ClashRoyale/releases)

</div>

## 项目特色

- **玩具沙盘低模 + Q 版**：全部模型程序化生成，不使用外部 GLB。
- **完整对战**：卡组、圣水、公主塔/国王塔、法术、召唤、AI。
- **局域网联机**：
  - 1V1 / 2V2 / 1V2；
  - 红蓝席位房间，空席 AI 托管；
  - 房主权威服务器，ENet UDP（端口 `24500`）；
  - 入场同步、倒计时、双端结算、表情、回放。
- **回放**：单机与联机对局均可在设置中开启录制。
- **新手训练营**：奖杯为 0 的新玩家自动进入；其他玩家可从主菜单底部「新手教程」进入。理论含目标类型教学，实战按肉盾→亡灵反制骑士→法术清场→摧毁公主塔推进；敌方 AI 会随机放牌，完成后播放结算面板并奖励 1 个宝箱。
- **初始卡牌**：新手的固定六张为弓箭手、万箭齐发、骑士、亡灵、巨人、火球，默认出战卡组也是这六张；其他卡牌仍由皇室征程/宝箱解锁。
- **表情图标**：表情使用程序化彩色徽章绘制，不依赖系统 emoji 字体；Web 端可正常显示。
- **部落搜索**：进入搜索页自动显示已有部落，搜索框/按钮只做筛选。
- **AI 卡池**：常规 AI 只使用新手六卡 + 当前竞技场已解锁卡牌。
- **宝箱反馈**：升级后的 3D 宝箱（拱形盖/木板/铆钉/锁扣/把手）会在结算返回主菜单时飞入宝箱按钮，按钮显示未开数量；皇室征程宝箱也使用同款 3D 模型。
- **多端**：Windows EXE、Android APK、Web（无多线程，适配 GitHub Pages；Web 端 emoji 自动替换为中文标签，避免方框乱码）。

## 下载

| 平台 | 文件 |
|---|---|
| Windows | `ClashRoyale-Net11.exe`（Releases） |
| Android | `ClashRoyale-Net.apk`（Releases） |
| Web | [GitHub Pages](https://3844775306-code.github.io/ClashRoyale/) / `ClashRoyale-Web.zip` |

## 操作

- 点击卡牌后再点战场，或直接拖拽卡牌到战场。
- 联机：创建房间后把本机 IP 和 4 位房间码发给朋友；朋友加入房间后点击空/AI 席位进驻。
- 房主可给红蓝双方增加席位（最多每方 2 席）；所有真人入驻后才能开始。

## 本地构建

需要 Godot **4.7.2 stable** 与对应导出模板。

```powershell
# 网页
godot --headless --path . --export-release "Web" "build/web/index.html"

# Windows
godot --headless --path . --export-release "Windows Desktop" "ClashRoyale-Net11.exe"
```

Android 导出后再用 `apksigner` 签名；签名文件不随仓库提供。

## 卡牌数据

- 运行时读取 `data/units_level11_utf8.csv` 或 `data/units_level11.csv`，按修改时间选择较新的表。
- 卡组/详情/升级与战斗共用 `BattleManager.load_card_configs()`。
- 详细说明见 [`docs/卡牌数据表说明.md`](docs/卡牌数据表说明.md)。

## 说明

- 本项目为非商业同人项目，与 Supercell 无关联；Clash Royale 相关名称与设定归 Supercell 所有。
- 公开仓库不包含 Android 签名文件、AI 训练产物、本地测试日志与构建缓存。

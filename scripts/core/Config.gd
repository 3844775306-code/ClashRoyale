extends Node
const BUILD_TAG := "2026-11-23 23:40"
const VERSION := "1.3.4"
const UPDATE_COUNT := 34
const WEB_URL := "https://3844775306-code.github.io/ClashRoyale/"
const RELEASE_URL := "https://github.com/3844775306-code/ClashRoyale/releases/tag/v1.2.0"
const WIN_URL := "https://github.com/3844775306-code/ClashRoyale/releases/download/v1.2.0/ClashRoyale-Net11-WebRTC-Windows.zip"
const APK_URL := "https://github.com/3844775306-code/ClashRoyale/releases/download/v1.2.0/ClashRoyale-Net.apk"

# 网格尺寸 (米)
const GRID_SIZE: float = 1.0

# 战场网格数量
const GRID_COLS: int = 18
const GRID_ROWS: int = 32

# 战场尺寸（运行时按模式切换；标准 18x32，冲线 40x80 足球场）
const ARENA_BASE_WIDTH: float = GRID_COLS * GRID_SIZE  # 18 米
const ARENA_BASE_HEIGHT: float = GRID_ROWS * GRID_SIZE  # 32 米
const ARENA_TOUCHDOWN_WIDTH: float = 30.0                # 30 格宽
const ARENA_TOUCHDOWN_HEIGHT: float = 60.0               # 60 米长
static var ARENA_WIDTH: float = ARENA_BASE_WIDTH
static var ARENA_HEIGHT: float = ARENA_BASE_HEIGHT
static var ARENA_ORIGIN: Vector3 = Vector3(-ARENA_BASE_WIDTH / 2.0, 0.0, -ARENA_BASE_HEIGHT / 2.0)


static func set_arena_size(w: float, h: float) -> void:
	ARENA_WIDTH = maxf(8.0, w)
	ARENA_HEIGHT = maxf(8.0, h)
	ARENA_ORIGIN = Vector3(-ARENA_WIDTH / 2.0, 0.0, -ARENA_HEIGHT / 2.0)


static func set_arena_height(h: float) -> void:
	set_arena_size(ARENA_WIDTH, h)

# 游戏时间限制（毫秒）
const GAME_TIME_LIMIT: int = 180000

# 等级成长：11 级为基准（卡表数值即 11 级），每升 1 级 ×1.10
# 即 value(level) = base * 1.10^(level - 11)：1 级 0.386×、11 级 1.000×、16 级 1.611×
const LEVEL_BASE: int = 11
const LEVEL_GROWTH_LOW: float = 1.05
const LEVEL_GROWTH_HIGH: float = 1.10
const LEVEL_MIN: int = 1
const LEVEL_MAX: int = 16

# 测试模式：战斗中所有卡牌/塔统一按 11 级结算（存档等级与升级界面不受影响）
const TEST_MODE: bool = false
const TEST_LEVEL: int = 11

func level_mult(level: int) -> float:
	# 1-9级每级 +5%，10-16级每级 +10%；以 11 级为基准保持现有数值
	var lv: int = clampi(level, LEVEL_MIN, LEVEL_MAX)
	var curve: float = 1.0
	for i in range(1, lv):
		curve *= LEVEL_GROWTH_LOW if i < 9 else LEVEL_GROWTH_HIGH
	var base: float = 1.0
	for i in range(1, LEVEL_BASE):
		base *= LEVEL_GROWTH_LOW if i < 9 else LEVEL_GROWTH_HIGH
	return curve / base

func battle_level(level: int) -> int:
	if TEST_MODE:
		return TEST_LEVEL
	return clampi(level, LEVEL_MIN, LEVEL_MAX)

# 音效开关：用于排查手机端音频相关闪退（false = 完全静音，BGM 也停）
const SFX_ENABLED: bool = true
# 同一音效的最小播放间隔（毫秒），避免战斗中同帧刷爆声部
const SFX_MIN_INTERVAL_MS: int = 35

# 队伍
enum Team {
	PLAYER = 0,
	ENEMY = 1
}

# 单位类型
enum UnitType {
	BUILDING = 1,
	GROUND = 2,
	AIR = 3
}

# 攻击目标类型
enum TargetType {
	ALL = 3,
	GROUND_ONLY = 2,
	BUILDING_ONLY = 1
}

# 游戏状态
enum GameStatus {
	MENU,
	PLAYING,
	GAME_OVER
}
const SPELL_IDS = [10, 11, 20, 31, 40, 48]   # 万箭齐发,火球,电击法术,大雪球,哥布林飞桶,雷电法术

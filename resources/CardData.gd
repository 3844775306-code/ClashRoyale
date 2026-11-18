class_name CardData
extends Resource


# ... (cost, num, type, max_health, damage, attack_speed, attack_range, damage_range, target_type, move_speed, move_type, horizon, size, shield, extra_spell, spawn_unit, attack_type, multiple_targets, multiple_process)

# 养成新增：1级基础值和每级成长
@export var base_health: float = 0.0
@export var health_growth: float = 1.0
@export var base_damage: float = 0.0
@export var damage_growth: float = 1.0

@export var card_name: String = ""
@export var card_id: int = 0
@export var cost: int = 0
@export var num: int = 1               # 部署数量
@export var type: int = Config.UnitType.GROUND
@export var max_health: float = 0.0
@export var damage: float = 0.0
@export var attack_speed: int = 1000   # 毫秒
@export var attack_range: float = 0.0  # 米
@export var damage_range: float = 0.0  # 范围伤害半径
@export var attack_type: int = 1       # 1=普通, 2=电击, 3=冰冻, 4=灼烧, 5=充能...
@export var target_type: int = Config.TargetType.ALL
@export var move_speed: int = 0        # 原速度值（会除以系数）
@export var move_type: int = 1         # 1=普通, 2=冲锋, 3=跳跃...
@export var horizon: float = 0.0       # 视野范围
@export var spawn_unit: Array = []     # [unit_id, count, interval_ms]
@export var size: float = 0.5          # 碰撞体积半径
@export var shield: float = 0.0        # 护盾值 (>0时一次)，-1表示攻击即死
@export var extra_spell: Array = []    # 附加法术参数
@export var multiple_targets: Array = [] # [count, type]
@export var multiple_process: Array = [] # 分裂/多段参数

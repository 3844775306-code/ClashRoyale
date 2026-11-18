# 大数据版（28张卡）.py - Clash Royale 简化版游戏
# 完整优化版

import pygame
import sys
import random
import math
from enum import Enum
from typing import List, Optional, Tuple, Dict, Any
from math import floor

# ==================== 初始化 ====================
pygame.init()
pygame.mixer.init()

# ==================== 游戏常量 ====================
GRID_SIZE = 20
ARENA_X, ARENA_Y = 20, 20
ARENA_WIDTH, ARENA_HEIGHT = 18 * GRID_SIZE, 31 * GRID_SIZE
SCREEN_WIDTH = 2 * ARENA_X + ARENA_WIDTH
SCREEN_HEIGHT = 2 * ARENA_Y + ARENA_HEIGHT + GRID_SIZE * 4
FPS = 60
GAME_TIME_LIMIT = 300000  # 5分钟（毫秒）

# ==================== 颜色定义 ====================
COLORS = {
    "WHITE": (255, 255, 255),
    "BLACK": (0, 0, 0),
    "RED": (255, 0, 0),
    "BLUE": (0, 150, 255),
    "GREEN": (0, 255, 0),
    "YELLOW": (255, 255, 0),
    "GRAY": (128, 128, 128),
    "DARK_GRAY": (64, 64, 64),
    "LIGHT_BLUE": (173, 216, 230),
    "ORANGE": (255, 165, 0),
    "PURPLE": (128, 0, 128),
    "BROWN": (139, 69, 19),
    "DARK_GREEN": (34, 139, 34),
    "GOLD": (255, 215, 0),
    "ELIXIR_NORMAL": (0, 100, 200),
    "ELIXIR_HIGH": (200, 50, 50)
}


# ==================== 游戏状态枚举 ====================
class GameStatus(Enum):
    MENU = "menu"
    PLAYING = "playing"
    GAME_OVER = "game_over"


# ==================== 数据配置类 ====================
class CardConfig:
    """卡牌配置数据类"""

    def __init__(self, name: str, card_id: int, image, cost: int, num: int, type_: int,
                 max_health: int, damage: int, attack_speed: int, attack_range: int,
                 damage_range: int, attack_type: int, target_type: int,
                 move_speed: int, move_type: int, horizon: int, spawn_unit: int,
                 size: int, shield: int, extra_spell, multiple_targets, multiple_process):
        self.name = name
        self.id = card_id
        self.image = image
        self.cost = cost
        self.num = num
        self.type = type_
        self.max_health = max_health
        self.damage = damage
        self.attack_speed = attack_speed
        self.attack_range = attack_range
        self.damage_range = damage_range
        self.attack_type = attack_type
        self.target_type = target_type
        self.move_speed = move_speed
        self.move_type = move_type
        self.horizon = horizon
        self.spawn_unit = spawn_unit
        self.size = floor(size)
        self.shield = shield
        self.extra_spell = extra_spell
        self.multiple_targets = multiple_targets
        self.multiple_process = multiple_process


# ==================== 辅助函数 ====================
def distance(obj1: Any, obj2: Any) -> float:
    """计算两个单位间的有效距离（考虑碰撞体积）"""
    if obj2 and obj1:
        base_dist = ((obj1.x - obj2.x) ** 2 + (obj1.y - obj2.y) ** 2) ** 0.5
        return base_dist - (getattr(obj1, 'size', 0) + getattr(obj2, 'size', 0))
    else:
        return 1000


def pos_unit(config: CardConfig, xx: float, yy: float, team: int, num: int,
             game_instance: Any) -> None:
    """生成单位或施放法术"""
    if config.max_health > 0:
        if num > 1:
            for i in range(num):
                game_instance.units.append(Unit(
                    config,
                    xx + math.cos(i / num * 2 * math.pi) * 20,
                    yy + math.sin(i / num * 2 * math.pi) * 20,
                    team,
                    game_instance
                ))
        else:
            game_instance.units.append(Unit(config, xx, yy, team, game_instance))
    else:
        if config.damage == 0:
            # 生成军队型法术
            pos_unit(game_instance.configs[config.spawn_unit[0]], xx, yy, team,
                     config.spawn_unit[1], game_instance)
        else:
            game_instance.active_spells.append(Spell(
                xx, yy, team, config.damage, config.damage_range,
                0, config.attack_type, config.target_type
            ))


# ==================== 游戏对象类 ====================
class Unit:
    """游戏中的战斗单位"""

    def __init__(self, config: CardConfig, x: float, y: float, team: int, game_instance: Any):
        self.target = None
        self.animation_frame = 0
        self.last_attack_time = pygame.time.get_ticks()
        self.last_move_time = pygame.time.get_ticks()
        self.last_spawn_time = pygame.time.get_ticks() - 15000
        self.last_lose_health_time = pygame.time.get_ticks()
        self.shock_time = 0
        self.froze_time = -3000

        self.game = game_instance
        self.index = game_instance.index
        game_instance.index += 1
        self.id = config.id
        self.config = config
        self.x = x
        self.y = y
        self.speed = config.move_speed * 0.02
        self.accelerate = 1
        self.accumulate = 1
        self.slow = 1
        self.team = team
        self.checked = []
        self.attacked = []
        self.size = config.size / 3
        self.max_health = config.shield if config.shield > 0 else config.max_health
        self.health = self.max_health
        self.state = 0
        self.shield = 0
        self.move_direction = None
        self.color = COLORS["RED"] if self.team == 1 else COLORS["BLUE"]

        if self.config.extra_spell != 0:
            if self.config.extra_spell[4] < 0:
                self.game.active_spells.append(Spell(
                    self.x, self.y, self.team, self.config.extra_spell[0],
                    self.config.extra_spell[1], 1, self.config.extra_spell[2],
                    self.config.extra_spell[3]
                ))

    def update(self) -> None:
        """更新单位状态"""
        self.check_attacked()
        self.check_collision()

        self._handle_health()
        if self.health <= 0:
            self._handle_death()
            return

        self._handle_status_effects()
        self._find_and_engage_target()

    def _handle_health(self) -> None:
        """处理生命值相关逻辑"""
        # 建筑逐渐扣血
        if self.config.type == 1 and self.id > 3 and pygame.time.get_ticks() - self.last_lose_health_time > 500:
            self.health -= self.max_health / 60
            self.last_lose_health_time = pygame.time.get_ticks()

        # 护盾机制
        if self.health <= 0 < self.config.shield and self.shield == 0:
            self.health = self.config.max_health
            self.max_health = self.config.max_health
            self.shield = 1

        # 更新全局血量数组（用于塔血量显示）
        if self.index < 6:
            self.game.healths[self.index] = self.health

    def _handle_death(self) -> None:
        """处理单位死亡"""
        if self.config.extra_spell != 0 and self.config.extra_spell[4] > 0:
            self.game.active_spells.append(Spell(
                self.x, self.y, self.team, self.config.extra_spell[0],
                self.config.extra_spell[1], 1, self.config.extra_spell[2],
                self.config.extra_spell[3]
            ))

        # 塔被摧毁
        if self.id <= 2:
            if self.team == 1:
                self.game.game_state.player_crowns += 1
            else:
                self.game.game_state.enemy_crowns += 1
        elif self.id == 3:
            if self.team == 1:
                self.game.game_state.player_crowns = 3
            else:
                self.game.game_state.enemy_crowns = 3
            self.game.game_state.winner = "Player" if self.game.game_state.player_crowns > self.game.game_state.enemy_crowns else "Enemy"
            self.game.game_state.game_over = True

        self.game.units.remove(self)

    def _handle_status_effects(self) -> None:
        """处理状态效果（电击、冰冻等）"""
        current_time = pygame.time.get_ticks()

        if self.state == 2:  # 电击
            self.shock_time = current_time
            self.target = None
            self.accelerate = 1
            self.accumulate = 1
            if self.config.attack_type == 5:
                self.last_attack_time = current_time
            self.state = 0

        if self.state == 3:  # 冰冻
            self.froze_time = current_time
            self.state = 0

        self.slow = 2.5 if current_time - self.froze_time <= 3000 else 1

        # 生成单位
        if (self.config.spawn_unit != 0 and
                current_time - self.last_spawn_time >= self.config.spawn_unit[2]):
            pos_unit(self.game.configs[self.config.spawn_unit[0]],
                     self.x, self.y, self.team, self.config.spawn_unit[1], self.game)
            self.last_spawn_time = current_time

    def _find_and_engage_target(self) -> None:
        """寻找并攻击目标"""
        if self.config.id == 3 and self.health == self.config.max_health:
            return
        current_time = pygame.time.get_ticks()

        if current_time - self.shock_time < 500:
            return

        self._update_target()

        if self.target:
            target_dist = distance(self, self.target)
            if target_dist > self.config.attack_range:
                if current_time - self.last_move_time >= 20 * self.slow:
                    self._move_to_target()
                    self.last_move_time = current_time
            else:
                if self.config.damage > 0 and current_time - self.last_attack_time >= self.config.attack_speed * self.slow:
                    self.attack()
                    self.last_attack_time = current_time
        else:
            if current_time - self.last_move_time >= 20 * self.slow:
                self.move_forward()
                self.last_move_time = current_time

    def _update_target(self) -> None:
        """更新当前目标"""
        if self.target:
            target_dist = distance(self, self.target)
            if target_dist > self.config.horizon or self.target.health <= 0:
                self.target = None

        if not self.target:
            self.attacked = []
            self.find_target(self)

    def find_target(self, pos) -> None:
        """寻找最近的合适目标"""
        self.accumulate = 1
        potential_targets = []

        for obj in self.game.units:
            if obj in self.attacked:
                continue

            if obj.team == self.team:
                continue

            dist = distance(pos, obj)
            if dist > self.config.horizon:
                continue



            # 根据攻击类型筛选目标
            if self.config.target_type == 2:  # 陆军
                if obj.config.type != 3:  # 不是空军
                    potential_targets.append((obj, dist))
            elif self.config.target_type == 1:  # 只攻击建筑
                if obj.config.type == 1:  # 是建筑
                    potential_targets.append((obj, dist))
            else:  # 攻击所有
                potential_targets.append((obj, dist))

        if potential_targets:
            potential_targets.sort(key=lambda x: x[1])
            self.target = potential_targets[0][0]
            self.attacked.append(self.target)
        else:
            if self.config.multiple_targets != 0:
                if self.config.multiple_targets[1] == 1:
                    pass
                else:
                    self.target = None
            else:
                self.target = None

    def _move_to_target(self) -> None:
        """向目标移动"""
        # 桥梁路径判断
        if self.team == 0:  # 玩家方
            if self.y >= ARENA_Y + ARENA_HEIGHT * 0.5 and self.config.type < 3 and self.config.move_type < 3:
                if self.target.y >= ARENA_Y + ARENA_HEIGHT * 0.5:
                    self.move_towards(self.target.x, self.target.y)
                else:
                    bridge_x = ARENA_X + ARENA_WIDTH * 0.2 if self.x <= ARENA_X + ARENA_WIDTH * 0.5 else ARENA_X + ARENA_WIDTH * 0.8
                    self.move_towards(bridge_x, ARENA_Y + ARENA_HEIGHT * 0.5)
            else:
                self.move_towards(self.target.x, self.target.y)
        else:  # 敌方
            if self.y <= ARENA_Y + ARENA_HEIGHT * 0.5 and self.config.type < 3 and self.config.move_type < 3:
                if self.target.y <= ARENA_Y + ARENA_HEIGHT * 0.5:
                    self.move_towards(self.target.x, self.target.y)
                else:
                    bridge_x = ARENA_X + ARENA_WIDTH * 0.2 if self.x <= ARENA_X + ARENA_WIDTH * 0.5 else ARENA_X + ARENA_WIDTH * 0.8
                    self.move_towards(bridge_x, ARENA_Y + ARENA_HEIGHT * 0.5)
            else:
                self.move_towards(self.target.x, self.target.y)

    def move_towards(self, x: float, y: float) -> None:
        """向指定坐标移动"""
        dx = x - self.x
        dy = y - self.y
        self.move_direction = math.degrees(math.atan2(-dy, dx))
        dist = math.sqrt(dx * dx + dy * dy)

        if dist > 0:
            dx = dx / dist * self.speed * floor(self.accelerate)
            dy = dy / dist * self.speed * floor(self.accelerate)
            self.x += dx
            self.y += dy

            if self.config.move_type == 2:  # 冲锋单位
                self.accelerate += 0.005
                if self.accelerate >= 2:
                    self.accelerate = 2

    def move_forward(self) -> None:
        """向敌方阵地前进"""
        if self.config.attack_type == 4:  # 灼烧伤害
            self.accumulate = 1

        if self.team == 0:  # 玩家方
            if self.y >= ARENA_Y + ARENA_HEIGHT * 0.5 and self.config.type < 3 and self.config.move_type < 3:
                bridge_x = ARENA_X + ARENA_WIDTH * 0.2 if self.x <= ARENA_X + ARENA_WIDTH * 0.5 else ARENA_X + ARENA_WIDTH * 0.8
                self.move_towards(bridge_x, ARENA_Y + ARENA_HEIGHT * 0.5)
            else:
                # 攻击敌方皇家塔
                if self.game.healths[3] > 0 and self.x <= ARENA_X + ARENA_WIDTH * 0.5:
                    self.move_towards(ARENA_X + ARENA_WIDTH * 0.2, ARENA_Y + ARENA_HEIGHT * 6.5 / 31)
                elif self.game.healths[4] > 0 and self.x >= ARENA_X + ARENA_WIDTH * 0.5:
                    self.move_towards(ARENA_X + ARENA_WIDTH * 0.8, ARENA_Y + ARENA_HEIGHT * 6.5 / 31)
                else:
                    self.move_towards(ARENA_X + ARENA_WIDTH * 0.5, ARENA_Y + ARENA_HEIGHT * 3 / 31)
        else:  # 敌方
            if self.y <= ARENA_Y + ARENA_HEIGHT * 0.5 and self.config.type < 3 and self.config.move_type < 3:
                bridge_x = ARENA_X + ARENA_WIDTH * 0.2 if self.x <= ARENA_X + ARENA_WIDTH * 0.5 else ARENA_X + ARENA_WIDTH * 0.8
                self.move_towards(bridge_x, ARENA_Y + ARENA_HEIGHT * 0.5)
            else:
                if self.game.healths[0] > 0 and self.x <= ARENA_X + ARENA_WIDTH * 0.5:
                    self.move_towards(ARENA_X + ARENA_WIDTH * 0.2, ARENA_Y + ARENA_HEIGHT * 24.5 / 31)
                elif self.game.healths[1] > 0 and self.x >= ARENA_X + ARENA_WIDTH * 0.5:
                    self.move_towards(ARENA_X + ARENA_WIDTH * 0.8, ARENA_Y + ARENA_HEIGHT * 24.5 / 31)
                else:
                    self.move_towards(ARENA_X + ARENA_WIDTH * 0.5, ARENA_Y + ARENA_HEIGHT * 29 / 31)

        # 边界检测
        self.x = max(ARENA_X + self.size, min(self.x, ARENA_X + ARENA_WIDTH - self.size))
        self.y = max(ARENA_Y + self.size, min(self.y, ARENA_Y + ARENA_HEIGHT - self.size))

    def check_collision(self) -> None:
        """检测并处理碰撞"""
        for obj in self.game.units:
            if obj == self:
                continue

            # 地面单位和空中单位分开处理
            if obj.config.type == self.config.type or (self.config.type - 3) * (obj.config.type - 3) > 0:
                if distance(self, obj) < 0:
                    #self.target = None
                    if self.config.size + self.index * 0.001 < obj.config.size + obj.index * 0.001:
                        if self.config.type != 1:  # 自己不是建筑
                            dx = obj.x - self.x
                            dy = obj.y - self.y
                            dist = math.sqrt(dx * dx + dy * dy) + 0.1
                            push_dist = self.size + obj.size
                            self.x = obj.x + push_dist * (self.x - obj.x) / dist
                            self.y = obj.y + push_dist * (self.y - obj.y) / dist

    def attack(self) -> None:

        """攻击目标"""
        self.move_direction = math.degrees(
            math.atan2(self.y - self.target.y, -self.x + self.target.x))

        if self.config.multiple_process:
            # 是否有多段攻击
            for i in range(self.config.multiple_process[1]):
                # 多发子弹
                self.game.bullets.append(Bullet(
                    self, self.target, 5 + self.config.damage_range / 2,
                                       self.config.attack_speed / 10, i - (-1 + self.config.multiple_process[1]) / 2
                ))
        else:
            self.game.bullets.append(Bullet(
                self, self.target, 5 + self.config.damage_range / 2,
                                   self.config.attack_speed / 10, None
            ))

          # 冲锋重置

        if self.config.extra_spell != 0:
            # 是否战斗时附带法术伤害
            if self.config.extra_spell[4] == 0:
                self.game.active_spells.append(Spell(
                    self.x, self.y, self.team, self.config.extra_spell[0],
                    self.config.extra_spell[1], 1, self.config.extra_spell[2],
                    self.config.extra_spell[3]
                ))

        if self.config.shield == -1:
            # 是否为攻击一次就死亡型
            self.health = 0

        if self.config.attack_type == 4:  # 灼烧伤害
            self.accumulate *= 1.2
            if self.accumulate >= 15:
                self.accumulate = 15

        if self.config.multiple_targets:
            # 是否一次可攻击多个目标
            for i in range(self.config.multiple_targets[0] - 1):
                if self.config.multiple_targets[1] == 1:
                    # 基本类型，所有目标都从自己出发来寻找
                    self.find_target(self)
                    self.game.bullets.append(Bullet(
                        self, self.target, 5 + self.config.damage_range / 2,
                                           self.config.attack_speed / 10, None
                    ))
                if self.config.multiple_targets[1] == 2:
                    # 攻击链类型，从目标寻找下一个目标
                    self.find_target(self.target)

                    if self.target:
                        self.game.bullets.append(Bullet(
                            self, self.target, 5 + self.config.damage_range / 2,
                                               self.config.attack_speed / 10, None
                        ))

            self.attacked = []  # 清零已攻击目标

    def check_attacked(self) -> None:
        """检查是否被法术攻击"""
        for spell in self.game.active_spells:
            if distance(spell, self) <= 0 and spell not in self.checked:
                if self.team != spell.team:  # 伤害来源于敌方
                    if spell.target_type == 3 or spell.target_type >= self.config.type:
                        damage = spell.damage
                        if spell.attack_type == 8:
                            # 为治疗法术，敌方单位免伤
                            damage = 0

                        if self.id <= 3 and spell.whether_from_unit != 1:  # 皇家塔减伤
                            damage /= 4
                        self.health -= damage

                        if spell.attack_type > 1:  # 特殊伤害类型
                            self.state = spell.attack_type
                        self.checked.append(spell)
                else:
                    if spell.attack_type == 8:
                        damage = spell.damage
                        if self.id <= 3 and spell.whether_from_unit != 1:  # 皇家塔减伤
                            damage /= 4
                        self.health += damage
                        # 为治疗法术，己方单位回血
                        self.checked.append(spell)

    def draw_shade(self, screen: pygame.Surface) -> None:
        """绘制阴影"""
        shadow_y = self.y + self.size * 0.4 if self.config.type < 3 else self.y + self.size * 0.4 + 10
        pygame.draw.circle(screen, (0, 0, 0, 50), (int(self.x), int(shadow_y)), self.size * 0.8)

    def draw(self, screen: pygame.Surface) -> None:
        """绘制单位"""
        if self.health <= 0:
            return

        # 皇家塔特殊绘制
        if self.id <= 3:
            self._draw_tower(screen)

        # 绘制单位主体
        current_time = pygame.time.get_ticks()
        if current_time - self.shock_time < 500:
            pygame.draw.circle(screen, COLORS["WHITE"], (int(self.x), int(self.y)), self.size)
        else:
            pygame.draw.circle(screen, self.color, (int(self.x), int(self.y)), self.size)
            pygame.draw.circle(screen, COLORS["WHITE"], (int(self.x), int(self.y)), self.size - 1, 1)

        # 状态效果
        if self.slow != 1:
            pygame.draw.circle(screen, COLORS["PURPLE"], (int(self.x), int(self.y)), self.size, floor(self.size * 0.4))
        if self.accelerate == 2:
            pygame.draw.circle(screen, COLORS["WHITE"], (int(self.x), int(self.y)), self.size - 1, 3)
        if self.config.attack_type == 5:
            charge_ratio = min(1, (current_time - self.last_attack_time) / self.config.attack_speed)
            pygame.draw.circle(screen, COLORS["WHITE"], (int(self.x), int(self.y)), self.size,
                               floor(self.size * charge_ratio))

        # 方向指示器
        if self.move_direction is not None:
            font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", floor(self.size * 1))
            text = font.render(self.config.name, True, COLORS["WHITE"])
            rotated = pygame.transform.rotate(text, self.move_direction - 90)
            screen.blit(rotated, rotated.get_rect(center=(self.x, self.y)))

        # 生命条
        if self.health < self.max_health:
            self._draw_health_bar(screen)

        # 等级星星
        if self.animation_frame % 60 < 10:
            self._draw_star(screen)

    def _draw_tower(self, screen: pygame.Surface) -> None:
        """绘制塔的底座和装饰"""
        pygame.draw.rect(screen, COLORS["DARK_GRAY"], (int(self.x - 25), int(self.y - 5), 50, 10))

        if self.id == 3:  # 国王塔
            pygame.draw.polygon(screen, self.color, [
                (int(self.x - 10), int(self.y - 12)),
                (int(self.x + 10), int(self.y - 12)),
                (int(self.x), int(self.y - 18))
            ])
            pygame.draw.circle(screen, COLORS["GOLD"], (int(self.x), int(self.y - 15)), 3)
        else:  # 公主塔
            pygame.draw.polygon(screen, self.color, [
                (int(self.x - 8), int(self.y - 12)),
                (int(self.x + 8), int(self.y - 12)),
                (int(self.x), int(self.y - 17))
            ])
            pygame.draw.circle(screen, COLORS["WHITE"], (int(self.x), int(self.y - 14)), 2)

    def _draw_health_bar(self, screen: pygame.Surface) -> None:
        """绘制生命条"""
        bar_width = self.max_health / 30
        bar_height = 5
        health_ratio = self.health / self.max_health

        pygame.draw.rect(screen, COLORS["BLACK"],
                         (int(self.x - bar_width / 2), int(self.y - self.size / 3 - 10), bar_width, bar_height))

        health_color = COLORS["BLUE"] if self.team == 0 else COLORS["RED"]
        pygame.draw.rect(screen, health_color,
                         (int(self.x - bar_width / 2), int(self.y - self.size / 3 - 10),
                          int(bar_width * health_ratio), bar_height))

    def _draw_star(self, screen: pygame.Surface) -> None:
        """绘制等级星星"""
        star_size = 4
        pygame.draw.polygon(screen, COLORS["GOLD"], [
            (int(self.x - star_size), int(self.y - star_size)),
            (int(self.x + star_size), int(self.y - star_size)),
            (int(self.x), int(self.y - star_size - 3))
        ])


class Spell:
    """法术效果"""

    def __init__(self, x: float, y: float, team: int, damage: int,
                 damage_range: int, whether_from_unit: int,
                 attack_type: int, target_type: int):
        self.x = x
        self.y = y
        self.team = team
        self.damage = damage
        self.damage_range = damage_range
        self.size = damage_range
        self.radius = damage_range
        self.whether_from_unit = whether_from_unit
        self.attack_type = attack_type
        self.target_type = target_type
        self.animation_frame = 0
        self.active = True
        self.max_duration = 20
        self.last_update = pygame.time.get_ticks()

        if damage == 1057:  # 为雷电法术，单独处理
            self.damage = 0
            self.targets = []

    def update(self, game_state: Any) -> None:
        """更新法术状态"""
        current_time = pygame.time.get_ticks()
        if current_time - self.last_update >= 20:
            self.animation_frame += 1
            self.last_update = current_time

        if self.animation_frame >= self.max_duration:
            self.active = False
            game_state.game.active_spells.remove(self)

            return

    def draw(self, screen: pygame.Surface) -> None:
        """绘制法术效果"""
        if not self.active:
            return

        progress = self.animation_frame / self.max_duration

        if progress < 0.3:  # 爆炸阶段
            radius = self.damage_range * (progress / 0.3)
            alpha = int(255 * (1 - progress / 0.3))
            color = (*COLORS["ORANGE"][:3], alpha)

            temp_surface = pygame.Surface((self.radius * 2, self.radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(temp_surface, color, (self.radius, self.radius), int(radius))
            screen.blit(temp_surface, (int(self.x - self.radius), int(self.y - self.radius)))

            # 火花效果
            for _ in range(5):
                spark_x = self.x + random.uniform(-radius, radius)
                spark_y = self.y + random.uniform(-radius, radius)
                pygame.draw.circle(screen, COLORS["YELLOW"], (int(spark_x), int(spark_y)), 2)


class Bullet:
    """子弹/投射物"""

    def __init__(self, unit: Unit, target: Unit, radius: float,
                 travel_time: float, index: Optional[float] = None):
        self.x = unit.x
        self.y = unit.y
        self.config = unit.config
        self.unit = unit
        self.team = unit.team
        self.index = index if index is not None else 0
        self.target = target
        self.attacked = []
        self.time = travel_time + 1
        self.size = radius
        self.blit = unit.id in [56, 52]  # 只有猎人和神箭游侠的子弹才分裂
        self.blited = False
        self.speed = 0.5
        self.last_move_time = pygame.time.get_ticks()



    def update(self, game_instance: Any) -> None:
        """更新子弹位置"""
        if not (self.unit and self.target):
            game_instance.bullets.remove(self)
            return
        if self.blit:  # 子弹分裂
            self.angle = math.atan2(self.unit.y - self.target.y,
                                    self.target.x - self.unit.x) + self.index * math.radians(
                self.config.multiple_process[0])
            self.speed = self.config.multiple_process[2] * 0.15
            self.move_distance = self.config.multiple_process[3]
            self.blit = False
            self.blited = True

        if self.blited:
            # 分裂后子弹运动
            current_time = pygame.time.get_ticks()
            if current_time - self.last_move_time >= 20:
                self.move_distance -= 0.1
                if self.move_distance <= 0:
                    game_instance.bullets.remove(self)
                    return
                self.last_move_time = current_time
                self.x += math.cos(self.angle) * self.speed
                self.y += -math.sin(self.angle) * self.speed

                for unit in game_instance.units:
                    # 碰撞单位造成伤害
                    if unit not in self.attacked:  # 避免重复伤害
                        if distance(self, unit) < 0:
                            if unit.team != self.team:
                                unit.health -= self.config.damage
                                if self.config.multiple_process[4] == 3:
                                    # 如果为这种类型的子弹，不具备穿透效果，碰到目标即消失
                                    game_instance.bullets.remove(self)
                                    return
                                else:
                                    self.attacked.append(unit)
        else:
            if self.target.health <= 0:
                game_instance.bullets.remove(self)
                return

            dx = self.target.x - self.x
            dy = self.target.y - self.y

            if distance(self, self.target) > self.speed * 10:
                current_time = pygame.time.get_ticks()
                if current_time - self.last_move_time >= 20:
                    self.last_move_time = current_time
                    self.x += (dx / distance(self, self.target)) * self.speed * 20
                    self.y += (dy / distance(self, self.target)) * self.speed * 20
            else:
                self._hit_target(game_instance)

    def _hit_target(self, game_instance: Any) -> None:
        """击中目标"""
        self.attacked.append(self.target)
        self.unit.accelerate = 1

        if self.config.damage_range > 0:  # 范围伤害
            game_instance.active_spells.append(Spell(
                self.x, self.y, self.team, self.config.damage * floor(self.unit.accelerate),
                self.config.damage_range, 1, self.config.attack_type,
                self.config.target_type
            ))
        else:  # 单体伤害
            damage = self.config.damage * floor(self.unit.accelerate) * floor(self.unit.accumulate)
            self.target.health -= damage

            if self.config.attack_type > 1:
                self.target.state = self.config.attack_type

        if self.unit.id == 43:  # 如果为烟花炮手的子弹，开始分裂
            self.blit = True
        else:
            game_instance.bullets.remove(self)

    def draw(self, screen: pygame.Surface) -> None:
        """绘制子弹"""
        color = COLORS["BLUE"] if self.team == 0 else COLORS["RED"]
        pygame.draw.circle(screen, color, (int(self.x), int(self.y)), self.size)

# ==================== AI 战术系统【最终精准修复版】===================
class AISystem:
    def __init__(self, game_instance):
        self.game = game_instance
        self.ai_select = None
        # 缩小思考间隔，解决进攻断档、补位慢
        self.ai_think_cd = 550
        self.ai_last_think = 0

        self.ai_card_desk = []
        self.ai_cards = []

        self.ai_strategy = "balance"
        self.enemy_side_pressure = {"left":0, "right":0}
        self.our_tower_alive = {"left":True, "right":True}

        self.enemy_heavy_exist = False
        self.enemy_swarm_exist = False
        self.enemy_air_exist = False
        self.threat_level = 0

        self.ai_logs = []
        self.max_log_count = 7

        # 标签黑名单定义
        self.spell_name_list = ["雪球", "电击法术", "火球", "箭雨", "毒药"]
        self.siege_unit_list = ["气球"]
        self.building_type_list = [1]
        self.swarm_unit_key = ["骷髅", "哥布林", "亡灵"]

        self.initialize_ai_deck()

    def add_log(self, text):
        self.ai_logs.append(text)
        if len(self.ai_logs) > self.max_log_count:
            self.ai_logs.pop(0)

    def draw_ai_thought(self, screen):
        # 战斗日志固定黄色
        font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 22)
        y = 10
        txt = font.render("🤖 AI实时战术思考", True, (255, 230, 0))
        screen.blit(txt, (10, y))
        y += 22
        for msg in self.ai_logs:
            render = font.render(msg, True, (255, 230, 0))
            screen.blit(render, (10, y))
            y += 20

    def is_spell_card(self, cfg):
        return any(name in cfg.name for name in self.spell_name_list)

    def is_siege_only_building(self, cfg):
        return any(name in cfg.name for name in self.siege_unit_list)

    def is_swarm_unit(self, cfg):
        return any(key in cfg.name for key in self.swarm_unit_key)

    def is_control_mage_unit(self, cfg):
        # 只判定纯单位法师，排除所有法术
        if self.is_spell_card(cfg):
            return False
        return any(key in cfg.name for key in ["闪电法师","寒冰法师","火法师","女巫"])

    def initialize_ai_deck(self):
        available_cards = [i for i in range(4, len(self.game.configs))]
        self.ai_card_desk = random.sample(available_cards, 8)
        self.ai_cards = self.ai_card_desk[:4]
        self.auto_recognize_strategy()

    def auto_recognize_strategy(self):
        cards_cfg = [self.game.configs[cid] for cid in self.ai_card_desk]
        avg_cost = sum(c.cost for c in cards_cfg) / 8
        has_highcost = any(c.cost >= 6 for c in cards_cfg)
        has_building = any(c.type in self.building_type_list for c in cards_cfg)

        if has_highcost:
            self.ai_strategy = "沉底平推一波流"
        elif has_building:
            self.ai_strategy = "拉扯防守反击"
        else:
            self.ai_strategy = "均衡进攻"
        self.add_log(f"战术锁定：{self.ai_strategy}")

    def cycle_ai_card(self, card_id):
        self.ai_card_desk.append(card_id)
        self.ai_card_desk.remove(card_id)
        self.ai_cards = self.ai_card_desk[:4]

    def refresh_battle_status(self):
        self.enemy_heavy_exist = False
        self.enemy_swarm_exist = False
        self.enemy_air_exist = False
        self.enemy_side_pressure = {"left":0, "right":0}

        all_enemy = [u for u in self.game.units if u.team == 0]
        for e in all_enemy:
            if e.config.cost >= 5 or e.config.max_health >= 2500:
                self.enemy_heavy_exist = True
            if e.config.num >= 3:
                self.enemy_swarm_exist = True
            if e.config.type == 3:
                self.enemy_air_exist = True
            sec = self.get_arena_section(e.x)
            if sec == "left": self.enemy_side_pressure["left"] += 1
            elif sec == "right": self.enemy_side_pressure["right"] += 1

        front_enemy = [u for u in self.game.units if u.team == 0 and u.y > ARENA_Y + ARENA_HEIGHT * 0.52]
        threat = 0
        if len(front_enemy)>=3: threat +=2
        if self.enemy_heavy_exist: threat +=1
        if self.enemy_air_exist: threat +=1
        self.threat_level = min(threat,4)

        self.ai_logs.clear()
        self.add_log(f"威胁等级：{self.threat_level}/4")
        side = "左路" if self.enemy_side_pressure["left"] >= self.enemy_side_pressure["right"] else "右路"
        self.add_log(f"敌方压力集中：{side}")

    def get_arena_section(self, x):
        w = ARENA_WIDTH
        if x < ARENA_X + w*0.35: return "left"
        elif x > ARENA_X + w*0.65: return "right"
        return "mid"

    def get_best_place_pos(self, cfg):
        # 区域常量重新划定
        OUR_TOP = ARENA_Y
        OUR_BOT = ARENA_Y + ARENA_HEIGHT * 0.5
        BRIDGE_Y = ARENA_Y + ARENA_HEIGHT * 0.5
        KING_BACK_Y = ARENA_Y + GRID_SIZE * 1.2    # 国王塔【后方】沉底位
        LEFT_TOWER_BACK = (ARENA_X + ARENA_WIDTH*0.18, ARENA_Y + ARENA_HEIGHT*0.25)
        RIGHT_TOWER_BACK = (ARENA_X + ARENA_WIDTH*0.82, ARENA_Y + ARENA_HEIGHT*0.25)
        MID_DEF_Y = ARENA_Y + ARENA_HEIGHT * 0.35

        strong_side = "left" if self.enemy_side_pressure["left"] >= self.enemy_side_pressure["right"] else "right"
        strong_pos = LEFT_TOWER_BACK if strong_side == "left" else RIGHT_TOWER_BACK

        # 5.建筑仅防守放置，进攻禁用
        if cfg.type in self.building_type_list:
            if self.threat_level >= 2:
                self.add_log("防守触发：部署防御建筑")
                return strong_pos
            else:
                # 均势/进攻局，建筑不下放
                return None

        # 法术单独处理，精准砸集群
        if self.is_spell_card(cfg):
            enemy_list = [u for u in self.game.units if u.team == 0]
            if enemy_list:
                avg_x = sum(u.x for u in enemy_list) / len(enemy_list)
                avg_y = sum(u.y for u in enemy_list) / len(enemy_list)
                self.add_log("法术精准释放，解场控场")
                return (avg_x, avg_y)

        # 气球仅打建筑，不参与重甲防守
        if self.is_siege_only_building(cfg):
            self.add_log("气球部署，专攻敌方建筑")
            return strong_pos

        # 人海群体仅防守反打
        if self.is_swarm_unit(cfg):
            if self.threat_level >= 2:
                self.add_log("防守人海反制敌军")
                return strong_pos
            else:
                return None

        is_melee = cfg.attack_range <= 18
        is_ranged = cfg.attack_range >= 55
        is_heavy = cfg.cost >= 5 or cfg.max_health >= 2000
        is_control_unit = self.is_control_mage_unit(cfg)
        is_air = cfg.type == 3

        # 4.拉扯：远程/控制固定左右塔后，不站中央
        if self.threat_level >= 2:
            if is_ranged or is_control_unit:
                self.add_log("拉扯站位：远程/法师落位塔后")
                return strong_pos
            if is_melee:
                self.add_log("防守近战中路卡位")
                return (ARENA_X+ARENA_WIDTH/2, MID_DEF_Y)

        # 6.沉底大肉盾：强制国王塔后
        if is_heavy and self.threat_level <= 1:
            self.add_log("沉底推进：国王塔后部署肉盾")
            return (ARENA_X+ARENA_WIDTH/2, KING_BACK_Y)

        # 3.进攻抱团逻辑：桥头同侧集中，杜绝分散
        if is_melee and self.threat_level <= 1:
            bridge_x = LEFT_TOWER_BACK[0] if strong_side=="left" else RIGHT_TOWER_BACK[0]
            self.add_log("桥头集中出兵，前排推进")
            return (bridge_x, BRIDGE_Y)

        # 控制法师、射手 紧跟肉盾后方抱团
        if is_control_unit or is_ranged:
            bridge_x = LEFT_TOWER_BACK[0] if strong_side=="left" else RIGHT_TOWER_BACK[0]
            self.add_log("后排紧跟肉盾，紧凑输出")
            return (bridge_x, BRIDGE_Y - 60)

        # 空军侧翼配合抱团
        if is_air:
            bridge_x = LEFT_TOWER_BACK[0] if strong_side=="left" else RIGHT_TOWER_BACK[0]
            return (bridge_x + 40, BRIDGE_Y - 30)

        return strong_pos

    def get_usable_cards(self):
        elixir = self.game.game_state.enemy_elixir
        return [self.game.configs[cid] for cid in self.ai_cards if self.game.configs[cid].cost <= elixir]

    def pick_defense_counter(self, usable):
        if self.enemy_air_exist:
            anti = [c for c in usable if not self.is_siege_only_building(c) and (c.target_type==3 or c.attack_range>=80)]
            if anti:
                self.add_log("选出防空单位应对空军")
                return min(anti, key=lambda x:x.cost)
        if self.enemy_heavy_exist:
            anti = [c for c in usable if not self.is_siege_only_building(c) and c.damage>=350]
            if anti:
                self.add_log("高伤单位克制敌方重甲")
                return min(anti, key=lambda x:x.cost)
        if self.enemy_swarm_exist:
            anti = [c for c in usable if c.damage_range>15 or self.is_spell_card(c)]
            if anti:
                self.add_log("范围伤害/法术清人海")
                return min(anti, key=lambda x:x.cost)
        return None

    def pick_attack_card(self, usable):
        # 强制出兵顺序：肉盾→控制/射手→空军
        front_meat = [c for c in usable if not self.is_spell_card(c) and c.attack_range<=20 and c.cost>=4]
        back_ranged = [c for c in usable if self.is_control_mage_unit(c) or (c.attack_range>=55 and not self.is_spell_card(c))]
        air_unit = [c for c in usable if c.type ==3 and not self.is_siege_only_building(c)]

        # 无前排肉盾，绝不裸下后排
        our_forward_count = sum(1 for u in self.game.units if u.team==1 and u.y > ARENA_Y+ARENA_HEIGHT*0.45 and u.config.attack_range<=20)
        if len(front_meat) > 0 and our_forward_count <= 1:
            return front_meat[0]
        if len(back_ranged) > 0 and our_forward_count >= 1:
            return back_ranged[0]
        if len(air_unit) > 0 and our_forward_count >= 1:
            return air_unit[0]

        return random.choice(usable) if usable else None

    def select_optimal_card(self):
        self.refresh_battle_status()
        usable = self.get_usable_cards()
        if not usable: return None

        # 高威胁优先防守
        if self.threat_level>=2:
            def_c = self.pick_defense_counter(usable)
            if def_c:
                return def_c
        # 均势/进攻抱团推进
        atk_c = self.pick_attack_card(usable)
        if atk_c:
            return atk_c

        return None

    def ai_action(self):
        now = pygame.time.get_ticks()
        if now - self.ai_last_think < self.ai_think_cd:
            return
        self.ai_last_think = now

        if self.ai_select is None:
            self.ai_select = self.select_optimal_card()

        if self.ai_select:
            # 建筑/人海无部署位置则跳过
            pos = self.get_best_place_pos(self.ai_select)
            if pos is None:
                self.ai_select = None
                return

            cost = self.ai_select.cost
            cur_elixir = self.game.game_state.enemy_elixir
            if cur_elixir >= cost:
                x,y = pos
                pos_unit(self.ai_select, x, y, 1, self.ai_select.num, self.game)
                self.game.game_state.enemy_elixir -= cost
                self.add_log(f"出战：{self.ai_select.name} | 费用{cost}")
                self.cycle_ai_card(self.ai_select.id)
                self.ai_select = None
# ==================== 卡牌UI类 ====================
class Card:
    """卡牌UI类"""

    def __init__(self, index: int, config_id: int, game_instance: Any):
        self.index = index
        self.game = game_instance
        self.config = game_instance.configs[config_id]
        self.font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 20)
        self.name_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 18)

    def is_ready(self, current_elixir: float) -> bool:
        """判断卡牌是否冷却完成（圣水足够）"""
        return self.config.cost <= current_elixir

    def draw(self, screen: pygame.Surface, x: int, y: int, width: int, height: int) -> None:
        """绘制卡牌"""
        # 选中高亮边框
        if self.game.game_state.selected_card == self:
            pygame.draw.rect(screen, COLORS["WHITE"], (x - 3, y - 3, width + 6, height + 6), 4)
            pygame.draw.rect(screen, COLORS["YELLOW"], (x - 2, y - 2, width + 4, height + 4), 2)

        # 冷却遮罩
        if not self.is_ready(self.game.game_state.player_elixir):
            overlay = pygame.Surface((width, height), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 180))
            screen.blit(overlay, (x, y))

            cooldown_ratio = self.game.game_state.player_elixir / self.config.cost
            cooldown_height = int(height * (1 - cooldown_ratio))
            pygame.draw.rect(screen, COLORS["GRAY"], (x, y, width, cooldown_height))

        # 卡牌背景
        pygame.draw.rect(screen, COLORS["BLUE"], (x, y, width, height), 2)

        # 圣水消耗显示
        elixir_color = COLORS["ELIXIR_NORMAL"] if self.config.cost <= 5 else COLORS["ELIXIR_HIGH"]
        pygame.draw.circle(screen, elixir_color, (x + 15, y + 15), 12)
        cost_text = self.font.render(str(self.config.cost), True, COLORS["WHITE"])
        screen.blit(cost_text, cost_text.get_rect(center=(x + 15, y + 15)))

        # 卡牌名称
        name_text = self.name_font.render(self.config.name, True, COLORS["WHITE"])
        screen.blit(name_text, name_text.get_rect(center=(x + width // 2, y + height // 2)))


# ==================== 游戏状态类 ====================
class ClashGameState:
    """管理游戏运行状态"""

    def __init__(self, game_instance: Any):
        self.game = game_instance
        self.ai_system = AISystem(game_instance)
        self.particles = []

        # 初始化塔
        pos_unit(game_instance.configs[1], ARENA_X + ARENA_WIDTH * 3.5 / 18,
                 ARENA_Y + ARENA_HEIGHT * 24.5 / 31, 0, 1, game_instance)
        pos_unit(game_instance.configs[2], ARENA_X + ARENA_WIDTH * 14.5 / 18,
                 ARENA_Y + ARENA_HEIGHT * 24.5 / 31, 0, 1, game_instance)
        pos_unit(game_instance.configs[3], ARENA_X + ARENA_WIDTH * 9 / 18,
                 ARENA_Y + ARENA_HEIGHT * 28 / 31, 0, 1, game_instance)
        pos_unit(game_instance.configs[1], ARENA_X + ARENA_WIDTH * 3.5 / 18,
                 ARENA_Y + ARENA_HEIGHT * 6.5 / 31, 1, 1, game_instance)
        pos_unit(game_instance.configs[2], ARENA_X + ARENA_WIDTH * 14.5 / 18,
                 ARENA_Y + ARENA_HEIGHT * 6.5 / 31, 1, 1, game_instance)
        pos_unit(game_instance.configs[3], ARENA_X + ARENA_WIDTH * 9 / 18,
                 ARENA_Y + ARENA_HEIGHT * 3 / 31, 1, 1, game_instance)

        # 圣水系统
        self.player_elixir = 5
        self.enemy_elixir = 5
        self.elixir_regen_rate = 1

        # 选中的卡牌
        self.selected_card = None

        # 游戏状态
        self.game_over = False
        self.winner = None
        self.game_time = 0
        self.last_update = 0
        self.overtime = False

        # 统计
        self.player_crowns = 0
        self.enemy_crowns = 0

        # 设置单位索引
        for i, unit in enumerate(game_instance.units):
            unit.index = i
        game_instance.index = len(game_instance.units)

    def update(self) -> None:
        """更新游戏状态"""
        current_time = pygame.time.get_ticks()-self.game.start_time
        if current_time - self.last_update >= 20:
            self.last_update = current_time
            self.game_time += 1
            self.update_elixir()

        # 检查时间限制
        if current_time >= 300000 and not self.game_over:
            self.overtime = True
            if self.player_crowns != self.enemy_crowns:
                self.game_over = True
                self.winner = "Player" if self.player_crowns > self.enemy_crowns else "Enemy"

        # 更新游戏对象
        for unit in self.game.units[:]:
            unit.update()

        for bullet in self.game.bullets[:]:
            bullet.update(self.game)

        for spell in self.game.active_spells[:]:
            spell.update(self)

        # 更新粒子效果
        for particle in self.particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            if particle['life'] <= 0:
                self.particles.remove(particle)

        # AI行动
        self.ai_system.ai_action()

    def update_elixir(self) -> None:
        """更新圣水恢复"""
        current_time = pygame.time.get_ticks()-self.game.start_time

        # 随时间增加恢复速度
        if current_time >= 240000:
            self.elixir_regen_rate = 3
        elif current_time >= 180000:
            self.elixir_regen_rate = 2
        elif current_time >= 120000:
            self.elixir_regen_rate = 1.5

        # 更新圣水值
        for elixir_attr in ['player_elixir', 'enemy_elixir']:
            current = getattr(self, elixir_attr)
            if current < 10:
                setattr(self, elixir_attr, min(10, current + self.elixir_regen_rate * 0.01))

    def add_spawn_effect(self, x: float, y: float) -> None:
        """添加单位生成特效"""
        for _ in range(10):
            self.particles.append({
                'x': x,
                'y': y,
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-2, 2),
                'life': 30,
                'max_life': 30,
                'color': COLORS["WHITE"]
            })


# ==================== 主游戏类 ====================
class ClashRoyaleGame:
    """主游戏类"""

    def __init__(self):
        # 游戏数据容器
        self.units = []
        self.bullets = []
        self.active_spells = []
        self.healths = [1, 1, 1, 1, 1, 1]

        # 游戏配置
        self.configs = self._init_configs()
        self.card_desk = []
        self.cards = []
        self.index = 0

        # 游戏状态
        self.current_state = GameStatus.MENU
        self.game_state = None

        # UI元素
        self.card_width = 3 * GRID_SIZE
        self.card_height = 4 * GRID_SIZE
        self.pos_rect = pygame.Rect(ARENA_X, ARENA_Y + ARENA_HEIGHT * 16 / 31,
                                    ARENA_WIDTH, ARENA_HEIGHT * 15 / 31)
        self.pos_rect1 = self.pos_rect.copy()
        self.pos_rect2 = self.pos_rect.copy()

        # 草地纹理
        self.grass = []
        for i in range(18 * 31):
            self.grass.append((34, 130 + (i % 2) * 20, 34))

        # 初始化屏幕
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("皇室战争 - Clash Royale Enhanced")
        self.clock = pygame.time.Clock()

    def _init_configs(self) -> List[CardConfig]:
        """初始化卡牌配置"""
        configs = [None]
        config_list = [
            # 格式: (名称, id, 图像, 消耗, 数量, 类型, 最大生命, 伤害, 攻击速度, 攻击范围, 伤害范围, 攻击类型, 目标类型, 移动速度, 移动类型, 视野, 生成助攻, 尺寸，护盾，附加法术伤害，多个伤害，多段伤害)
            ("公主塔", 1, None, 0, 1, 1, 3052, 109, 800, 140, 0, 1, 3, 0, 1, 140, 0, GRID_SIZE * 4.5, 0, 0, 0, 0),
            ("王子塔", 2, None, 0, 1, 1, 2616, 320, 2200, 140, 0, 1, 3, 0, 1, 140, 0, GRID_SIZE * 4.5, 0, 0, 0, 0),
            ("国王塔", 3, None, 0, 1, 1, 4824, 109, 1000, 130, 0, 1, 3, 0, 1, 120, 0, GRID_SIZE * 6, 0, 0, 0, 0),
            ("骑士", 4, None, 3, 1, 2, 1766, 168, 1200, 8, 0, 1, 2, 50, 1, 50, 0, 30, 0, 0, 0, 0),
            ("骷髅军团", 5, None, 3, 15, 2, 81, 81, 1100, 5, 0, 1, 2, 70, 1, 50, 0, 18, 0, 0, 0, 0),
            ("闪电法师", 6, None, 4, 1, 2, 714, 115, 1800, 90, 0, 2, 3, 50, 1, 100, 0, 40, 0, [190, 40, 2, 3, -1],
             [2, 1], 0),
            ("法师", 7, None, 5, 1, 2, 755, 281, 1400, 100, 24, 1, 3, 40, 1, 110, 0, 40, 0, 0, 0, 0),
            ("亡灵", 8, None, 3, 3, 3, 230, 107, 1100, 40, 0, 1, 3, 70, 1, 60, 0, 24, 0, 0, 0, 0),
            ("巨人", 9, None, 5, 1, 2, 4090, 253, 1500, 8, 0, 1, 1, 20, 0, 120, 0, 60, 0, 0, 0, 0),
            ("箭雨", 10, None, 3, 1, 0, 0, 366, 500, 70, 70, 1, 3, 0, 1, 0, 0, 210, 0, 0, 0, 0),
            ("火球", 11, None, 4, 1, 0, 0, 688, 2500, 50, 50, 1, 3, 0, 0, 0, 0, 150, 0, 0, 0, 0),
            ("瓦丽基女神", 12, None, 4, 1, 2, 1907, 266, 1500, 8, 20, 1, 2, 40, 1, 60, 0, 40, 0, 0, 0, 0),
            ("迷你皮卡", 13, None, 4, 1, 2, 755, 471, 1600, 5, 0, 1, 2, 70, 1, 70, 0, 40, 0, 0, 0, 0),
            ("飞龙宝宝", 14, None, 4, 1, 3, 1152, 161, 1500, 60, 14, 1, 3, 50, 1, 70, 0, 45, 0, 0, 0, 0),
            ("皮卡超人", 15, None, 7, 1, 2, 3760, 816, 1800, 8, 0, 1, 2, 20, 1, 100, 0, 55, 0, 0, 0, 0),
            ("王子", 16, None, 5, 1, 2, 1920, 391, 1400, 12, 0, 1, 2, 40, 2, 60, 0, 40, 0, 0, 0, 0),
            ("野猪骑士", 17, None, 4, 1, 2, 1697, 317, 1600, 5, 0, 1, 1, 70, 3, 120, 0, 50, 0, 0, 0, 0),
            ("寒冰法师", 18, None, 3, 1, 2, 688, 89, 1700, 100, 12, 3, 3, 40, 1, 100, 0, 30, 0, [84, 35, 3, 3, -1], 0,
             0),
            ("女巫", 19, None, 5, 1, 2, 839, 135, 1100, 100, 12, 1, 3, 40, 1, 110, [5, 4, 7000], 50, 0, 0, 0, 0),
            ("电击法术", 20, None, 2, 1, 0, 0, 192, 200, 50, 50, 2, 3, 0, 0, 0, 0, 150, 0, 0, 0, 0),
            ("特斯拉电磁塔", 21, None, 4, 1, 1, 1152, 220, 1100, 100, 0, 1, 3, 0, 1, 100, 0, 50, 0, 0, 0, 0),
            ("蝙蝠", 22, None, 2, 5, 3, 81, 81, 1300, 8, 0, 1, 3, 70, 1, 70, 0, 15, 0, 0, 0, 0),
            ("黑暗王子", 23, None, 4, 1, 2, 1200, 266, 1300, 8, 20, 1, 2, 40, 2, 70, 0, 45, 240, 0, 0, 0),
            ("骷髅墓碑", 24, None, 3, 1, 1, 529, 0, 0, 0, 0, 1, 3, 0, 1, 50, [5, 1, 4000], 45, 0, 0, 0, 0),
            ("气球兵", 25, None, 5, 1, 3, 1679, 640, 2000, 0, 0, 1, 1, 30, 1, 120, 0, 60, 0, [220, 24, 1, 3, 2000], 0,
             0),
            ("炸弹塔", 26, None, 4, 1, 1, 1356, 222, 1800, 110, 16, 1, 2, 0, 1, 90, 0, 50, 0, [222, 24, 1, 3, 2000], 0,
             0),
            ("地狱飞龙", 27, None, 4, 1, 3, 1295, 35, 400, 60, 0, 4, 3, 40, 1, 80, 0, 45, 0, 0, 0, 0),
            ("电磁炮", 28, None, 6, 1, 2, 1451, 1331, 4000, 90, 28, 5, 2, 20, 1, 100, 0, 50, 0, 0, 0, 0),
            ("野蛮人精锐", 29, None, 6, 2, 2, 1341, 384, 1400, 12, 0, 1, 2, 50, 1, 70, 0, 45, 0, 0, 0, 0),
            ("戈伦冰人", 30, None, 2, 1, 2, 1315, 84, 2500, 5, 0, 1, 1, 20, 1, 50, 0, 50, 0, [84, 20, 3, 3, 100], 0, 0),
            ("雪球", 31, None, 2, 1, 0, 0, 179, 2000, 50, 50, 3, 3, 0, 1, 0, 0, GRID_SIZE * 7.5, 0, 0, 0, 0),
            ("哥布林吹箭手", 32, None, 3, 1, 2, 261, 151, 800, 120, 0, 1, 3, 70, 1, 130, 0, 40, 0, 0, 0, 0),
            ("地狱之塔", 33, None, 4, 1, 1, 1748, 43, 400, 110, 0, 4, 3, 0, 1, 110, 0, 60, 0, 0, 0, 0),
            ("皇家巨人", 34, None, 6, 1, 2, 3164, 307, 1700, 90, 0, 1, 1, 20, 1, 100, 0, 80, 0, 0, 0, 0),
            ("冰冻精灵", 35, None, 1, 1, 2, 230, 110, 1300, 40, 24, 3, 3, 70, 1, 50, 0, 40, -1, 0, 0, 0),
            ("雷电飞龙", 36, None, 5, 1, 3, 943, 192, 2100, 60, 0, 2, 3, 40, 1, 60, 0, 50, 0, 0, [3, 2], 0),
            ("暗夜女巫", 37, None, 4, 1, 2, 906, 314, 1300, 15, 0, 1, 2, 40, 1, 50, [22, 2, 5000], 50, 0, 0, 0, 0),
            ("皇家野猪", 38, None, 5, 4, 2, 837, 74, 1200, 5, 0, 1, 1, 70, 3, 120, 0, 50, 0, 0, 0, 0),
            ("哥布林", 39, None, 2, 4, 2, 202, 120, 1100, 5, 0, 1, 2, 70, 1, 40, 0, 30, 0, 0, 0, 0),
            ("哥布林飞桶", 40, None, 3, 1, 0, 0, 0, 2000, 30, 30, 1, 2, 0, 0, 0, [39, 3, 0], 40, 0, 0, 0, 0),
            ("骷髅巨人", 41, None, 6, 1, 2, 3617, 276, 1300, 5, 0, 1, 2, 40, 1, 50, 0, 70, 0, [535, 30, 1, 3, 3000], 0,
             0),
            ("攻城炸弹人", 42, None, 2, 2, 2, 330, 1, 500, 5, 40, 1, 1, 70, 1, 120, 0, 35, -1, [350, 40, 1, 3, 0], 0,
             0),
            ("烟花炮手", 43, None, 3, 1, 2, 304, 64, 3000, 110, 30, 1, 3, 50, 1, 130, 0, 35, 0, 0, 0,
             [15, 5, 40, 2, 1]),
            ("弓箭手", 44, None, 3, 2, 2, 304, 112, 900, 110, 0, 1, 3, 40, 1, 130, 0, 35, 0, 0, 0, 0),
            ("雷电精灵", 45, None, 1, 1, 2, 230, 99, 1300, 50, 0, 2, 3, 70, 1, 50, 0, 40, -1, 0, [9, 2], 0),
            ("治疗精灵", 46, None, 1, 1, 2, 230, 110, 1300, 50, 0, 1, 3, 70, 1, 70, 0, 40, -1, [400, 50, 8, 3, 100], 0,
             0),
            ("战斗天使", 47, None, 4, 1, 2, 1717, 148, 1500, 15, 0, 1, 2, 40, 1, 60, 0, 45, 0, [120, 50, 8, 3, 0], 0,
             0),
            ("雷电法术", 48, None, 6, 1, 0, 0, 1057, 500, 70, 70, 2, 3, 0, 0, 0, 0, 70, 0, 0, [3, 3], 0),
            ("野蛮人小屋", 49, None, 6, 1, 1, 1164, 0, 0, 0, 0, 1, 3, 0, 1, 0, [57, 3, 15000], 60, 0, 0, 0, 0),
            ("烈焰精灵", 50, None, 1, 1, 2, 230, 207, 1300, 50, 40, 1, 3, 70, 1, 70, 0, 30, -1, 0, 0, 0),
            ("烈焰熔炉", 51, None, 4, 1, 2, 727, 179, 1700, 110, 0, 1, 3, 40, 1, 130, [50, 1, 7000], 45, 0, 0, 0, 0),
            ("神箭游侠", 52, None, 4, 1, 2, 529, 143, 1100, 120, 10, 1, 3, 40, 1, 150, 0, 45, 0, 0, 0,
             [0, 1, 45, 4, 2]),
            ("皇家速递", 53, None, 3, 1, 2, 787, 133, 1300, 15, 0, 1, 2, 40, 1, 60, 0, 40, 240, [437, 60, 1, 3, -2000],
             0, 0),
            ("飞行器", 54, None, 4, 1, 3, 614, 171, 1100, 110, 0, 1, 3, 50, 1, 130, 0, 50, 0, 0, 0, 0),
            ("x连弩", 55, None, 6, 1, 1, 1600, 43, 300, 220, 0, 1, 2, 0, 1, 220, 0, 60, 0, 0, 0, 0),
            ("猎人", 56, None, 4, 1, 2, 885, 84, 2200, 70, 15, 1, 3, 40, 1, 100, 0, 50, 0, 0, 0, [12, 10, 40, 2, 3]),
            ("野蛮人", 57, None, 5, 5, 2, 737, 147, 1300, 5, 0, 1, 2, 40, 1, 50, 0, 40, 0, 0, 0, 0)
        ]

        for args in config_list:
            configs.append(CardConfig(*args))
        return configs

    def initialize_deck(self):
        """初始化玩家卡组"""
        self.card_desk = random.sample(range(4, len(self.configs)), 8)
        self.cards = [Card(i, self.card_desk[i], self) for i in range(4)]

    def cycle_card(self, card_id: int):
        """玩家卡牌循环"""
        self.card_desk.append(card_id)
        # 找到要移除的卡牌
        card_to_remove = None
        for card in self.cards:
            if card.config.id == card_id:
                card_to_remove = card
                break

        if card_to_remove:
            self.cards.remove(card_to_remove)

        if self.card_desk:
            new_card_id = self.card_desk[4]
            self.card_desk.remove(card_id)
            new_card = Card(card_to_remove.index, new_card_id, self)
            self.cards.append(new_card)

    def run(self):
        """运行游戏主循环"""
        # 初始化卡组
        self.initialize_deck()

        running = True
        while running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
                elif event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                    running = False
                elif event.type == pygame.MOUSEBUTTONDOWN:
                    self.handle_mouse_click(event.pos)

            # 根据状态绘制不同界面
            if self.current_state == GameStatus.MENU:
                self.draw_menu()
            elif self.current_state == GameStatus.PLAYING:
                self.update_game()
                self.draw_game()
            elif self.current_state == GameStatus.GAME_OVER:
                self.draw_game_over()

            pygame.display.flip()
            self.clock.tick(FPS)

        pygame.quit()
        sys.exit()

    def start_game(self):
        """开始新游戏"""
        self.start_time = pygame.time.get_ticks()
        self.current_state = GameStatus.PLAYING
        self.game_state = ClashGameState(self)
        # 重新初始化卡组
        self.initialize_deck()

    def update_game(self):
        """更新游戏状态"""
        if self.game_state:
            self.game_state.update()
            if self.game_state.game_over:
                self.current_state = GameStatus.GAME_OVER

    def handle_mouse_click(self, pos):
        """处理鼠标点击事件"""
        if self.current_state == GameStatus.MENU:
            self._handle_menu_click(pos)
        elif self.current_state == GameStatus.PLAYING:
            self._handle_game_click(pos)
        elif self.current_state == GameStatus.GAME_OVER:
            self._handle_game_over_click(pos)

    def _handle_menu_click(self, pos):
        """处理菜单点击"""
        button_rect = pygame.Rect(SCREEN_WIDTH // 2 - 100, SCREEN_HEIGHT // 2 - 50, 200, 100)
        if button_rect.collidepoint(pos):
            self.start_game()

    def _handle_game_click(self, pos):
        """处理游戏中的点击"""
        if not self.game_state:
            return

        x, y = pos

        # 点击卡牌
        if y > ARENA_HEIGHT:
            for card in self.cards:
                card_x = ARENA_X + card.index * 5 * GRID_SIZE
                card_rect = pygame.Rect(card_x, 2 * ARENA_Y + ARENA_HEIGHT, self.card_width, self.card_height)
                if card_rect.collidepoint(x, y):
                    self.game_state.selected_card = card

        # 点击战场放置单位
        if (ARENA_X <= x <= ARENA_X + ARENA_WIDTH and ARENA_Y <= y <= ARENA_Y + ARENA_HEIGHT and
                self.game_state.selected_card and self.game_state.selected_card.is_ready(
                    self.game_state.player_elixir)):

            # 检查是否在玩家区域
            if (y > ARENA_Y + ARENA_HEIGHT * 16 / 31 or self.game_state.selected_card.config.type == 0 or
                    self.pos_rect1.collidepoint(x, y) or self.pos_rect2.collidepoint(x, y)):
                x = floor((x - ARENA_X) / GRID_SIZE) * GRID_SIZE + ARENA_X + GRID_SIZE * 0.5
                y = floor((y - ARENA_Y) / GRID_SIZE) * GRID_SIZE + ARENA_Y + GRID_SIZE * 0.5

                card = self.game_state.selected_card
                pos_unit(card.config, x, y, 0, card.config.num, self)
                self.game_state.player_elixir -= card.config.cost

                # 卡牌循环
                self.cycle_card(card.config.id)

                # 添加特效
                self.game_state.add_spawn_effect(x, y)

                # 取消选中
                self.game_state.selected_card = None

    def _handle_game_over_click(self, pos):
        """处理游戏结束界面点击"""
        button_rect = pygame.Rect(SCREEN_WIDTH // 2 - 100, SCREEN_HEIGHT // 2 + 50, 200, 50)
        if button_rect.collidepoint(pos):
            self.current_state = GameStatus.MENU
            # 重置游戏状态
            self.units = []
            self.bullets = []
            self.active_spells = []
            self.healths = [1, 1, 1, 1, 1, 1]
            self.index = 0
            self.start_time = pygame.time.get_ticks()

    def draw_menu(self):
        """绘制菜单界面"""
        self.screen.fill(COLORS["BLACK"])

        # 背景效果
        for _ in range(50):
            x = random.randint(0, SCREEN_WIDTH)
            y = random.randint(0, SCREEN_HEIGHT)
            pygame.draw.circle(self.screen, (50, 50, 50), (x, y), 8)

        # 标题
        title_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 72)
        title = title_font.render("皇室战争", True, COLORS["WHITE"])
        title_rect = title.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 3))

        # 发光效果
        glow_surface = pygame.Surface((title_rect.width + 20, title_rect.height + 20), pygame.SRCALPHA)
        glow_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 72)
        glow_text = glow_font.render("皇室战争", True, (255, 255, 0, 100))
        glow_surface.blit(glow_text, (10, 10))
        self.screen.blit(glow_surface, (title_rect.x - 10, title_rect.y - 10))
        self.screen.blit(title, title_rect)

        # 副标题
        subtitle_font = pygame.font.Font(None, 36)
        subtitle = subtitle_font.render("Clash Royale Enhanced", True, COLORS["WHITE"])
        self.screen.blit(subtitle, subtitle.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 3 + 60)))

        # 开始游戏按钮
        button_rect = pygame.Rect(SCREEN_WIDTH // 2 - 100, SCREEN_HEIGHT // 2 - 50, 200, 100)
        pygame.draw.rect(self.screen, (100, 100, 255), button_rect.inflate(10, 10), 3)
        pygame.draw.rect(self.screen, COLORS["BLUE"], button_rect)

        button_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 36)
        button_text = button_font.render("开始游戏", True, COLORS["WHITE"])
        self.screen.blit(button_text, button_text.get_rect(center=button_rect.center))

        # 说明文字
        instruction_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 24)
        instructions = [
            "点击卡牌选中，然后点击战场放置单位",
            "消灭敌方国王塔获得胜利！",
            "按ESC键退出游戏"
        ]

        for i, instruction in enumerate(instructions):
            text = instruction_font.render(instruction, True, COLORS["WHITE"])
            self.screen.blit(text, text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT * 2 // 3 + i * 30)))

    def draw_game(self):
        """绘制游戏界面"""
        self.screen.fill(COLORS["BROWN"])

        # 绘制战场
        self.draw_arena()

        # 绘制单位阴影
        for unit in self.units:
            unit.draw_shade(self.screen)

        # 绘制陆军及建筑
        for unit in self.units:
            if unit.config.type < 3:
                unit.draw(self.screen)

        # 绘制空军
        for unit in self.units:
            if unit.config.type == 3:
                unit.draw(self.screen)

        # 绘制子弹
        for bullet in self.bullets:
            bullet.draw(self.screen)

        # 绘制法术
        for spell in self.active_spells:
            spell.draw(self.screen)

        # 绘制粒子效果
        if self.game_state:
            for particle in self.game_state.particles:
                alpha = int(255 * particle['life'] / particle['max_life'])
                color = (*particle['color'][:3], alpha)
                temp_surface = pygame.Surface((6, 6), pygame.SRCALPHA)
                pygame.draw.circle(temp_surface, color, (3, 3), 3)
                self.screen.blit(temp_surface, (int(particle['x'] - 3), int(particle['y'] - 3)))

        # 绘制UI
        self.draw_ui()

        # 加时赛提示
        if self.game_state and self.game_state.overtime:
            font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 24)
            overtime_text = font.render("加时赛！", True, COLORS["ORANGE"])
            self.screen.blit(overtime_text, overtime_text.get_rect(center=(SCREEN_WIDTH // 2, 30)))
        self.game_state.ai_system.draw_ai_thought(self.screen)
    def draw_arena(self):
        """绘制战场"""

        # 战场背景
        pygame.draw.rect(self.screen, COLORS["DARK_GREEN"], (ARENA_X, ARENA_Y, ARENA_WIDTH, ARENA_HEIGHT))

        # 草地纹理
        for j in range(31):
            for i in range(18):
                pygame.draw.rect(self.screen, self.grass[31 * i + j],
                                 (ARENA_X + i * GRID_SIZE, ARENA_Y + j * GRID_SIZE, GRID_SIZE, GRID_SIZE), 2)

        # 河流
        river_rect = pygame.Rect(ARENA_X, ARENA_Y + ARENA_HEIGHT // 2 - GRID_SIZE * 0.5, ARENA_WIDTH, GRID_SIZE)
        pygame.draw.rect(self.screen, (135, 206, 235), river_rect)

        # 水波纹
        if self.game_state:
            for i in range(0, ARENA_WIDTH, GRID_SIZE):
                wave_y = ARENA_Y + ARENA_HEIGHT // 2 + math.sin(i * 0.1 + self.game_state.game_time * 0.1) * 5
                pygame.draw.line(self.screen, (100, 180, 255),
                                 (ARENA_X + i, wave_y - 5),
                                 (ARENA_X + i, wave_y + 5), 2)

        # 桥梁
        bridge_width = 2 * GRID_SIZE
        bridge_height = 2 * GRID_SIZE
        bridge_y = ARENA_Y + ARENA_HEIGHT // 2 - 1 * GRID_SIZE

        for bridge_x in [ARENA_X + ARENA_WIDTH * 3.5 / 18, ARENA_X + ARENA_WIDTH * 14.5 / 18]:
            pygame.draw.rect(self.screen, COLORS["BROWN"],
                             (bridge_x - bridge_width // 2, bridge_y, bridge_width, bridge_height))

            # 桥梁纹理
            for i in range(bridge_width // 10):
                pygame.draw.line(self.screen, (100, 50, 0),
                                 (bridge_x - bridge_width // 2 + i * 10, bridge_y),
                                 (bridge_x - bridge_width // 2 + i * 10, bridge_y + bridge_height), 2)

    def draw_ui(self):
        """绘制用户界面"""
        if not self.game_state:
            return

        # 玩家圣水条
        elixir_width = 18 * GRID_SIZE
        elixir_height = 1 * GRID_SIZE
        elixir_x = ARENA_X
        elixir_y = 2 * ARENA_Y + ARENA_HEIGHT

        # 背景
        pygame.draw.rect(self.screen, COLORS["DARK_GRAY"],
                         (elixir_x - 2, elixir_y - 2, elixir_width + 4, elixir_height + 4))
        pygame.draw.rect(self.screen, COLORS["BLACK"], (elixir_x, elixir_y, elixir_width, elixir_height))

        # 圣水填充
        elixir_ratio = self.game_state.player_elixir / 10
        pygame.draw.rect(self.screen, COLORS["BLUE"],
                         (elixir_x, elixir_y, int(elixir_width * elixir_ratio), elixir_height))

        # 圣水格子
        for i in range(10):
            pygame.draw.rect(self.screen, COLORS["WHITE"],
                             (elixir_x + i * elixir_width / 10, elixir_y, elixir_width / 10, elixir_height), 2)

        # 时间显示
        font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", GRID_SIZE)
        time_text = font.render(f"时间: {floor((pygame.time.get_ticks()-self.start_time)/ 1000)}", True, COLORS["WHITE"])
        self.screen.blit(time_text, (ARENA_X + 14 * GRID_SIZE, ARENA_Y + 1 * GRID_SIZE))

        # 圣水积累速度
        rate_text = font.render(f"圣水: {self.game_state.elixir_regen_rate}倍", True, COLORS["WHITE"])
        self.screen.blit(rate_text, (ARENA_X + 14 * GRID_SIZE, ARENA_Y + 3 * GRID_SIZE))

        # 圣水标签
        font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 28)
        player_text = font.render(f"圣水: {int(self.game_state.player_elixir)}/10", True, COLORS["WHITE"])
        self.screen.blit(player_text, (elixir_x, elixir_y - 35))

        # 皇冠计数
        crown_font = pygame.font.Font("C:/Windows/Fonts/seguiemj.ttf", 18)
        player_crown_text = crown_font.render(f"👑 {self.game_state.player_crowns}", True, COLORS["GOLD"])
        self.screen.blit(player_crown_text, (ARENA_X + 16 * GRID_SIZE, ARENA_Y + 19 * GRID_SIZE))

        enemy_crown_text = crown_font.render(f"👑 {self.game_state.enemy_crowns}", True, COLORS["GOLD"])
        self.screen.blit(enemy_crown_text, (ARENA_X + 16 * GRID_SIZE, ARENA_Y + 16 * GRID_SIZE))

        # 皇家塔血量

        for i in range(6 - self.game_state.enemy_crowns - self.game_state.player_crowns):
            if self.units[i].health >= 0:
                font = pygame.font.Font("C:/Windows/Fonts/seguiemj.ttf", 20)
                health_text = font.render(f"👑 {floor(self.units[i].health)}", True, COLORS["WHITE"])
                self.screen.blit(health_text, (self.units[i].x - 45, self.units[i].y - 30))

        # 选中提示
        if self.game_state.selected_card and self.game_state.selected_card.is_ready(self.game_state.player_elixir):
            self._draw_selection_indicators()

        # 卡牌区域
        card_area_y = 3 * ARENA_Y + ARENA_HEIGHT
        pygame.draw.rect(self.screen, (40, 40, 40), (ARENA_X, card_area_y, ARENA_WIDTH, self.card_height))
        pygame.draw.rect(self.screen, COLORS["WHITE"], (ARENA_X, card_area_y, ARENA_WIDTH, self.card_height), 3)

        # 绘制卡牌
        for card in self.cards:
            x = ARENA_X + card.index * 5 * GRID_SIZE
            y = card_area_y
            card.draw(self.screen, x, y, self.card_width, self.card_height)

    def _draw_selection_indicators(self):
        """绘制选中提示"""
        if not self.game_state:
            return

        # 可放置区域
        pygame.draw.rect(self.screen, COLORS["GREEN"],
                         (ARENA_X, ARENA_Y + ARENA_HEIGHT * 18 / 35, ARENA_WIDTH, ARENA_HEIGHT * 17 / 35), 3)

        if self.game_state.selected_card.config.type == 0:  # 法术
            pygame.draw.rect(self.screen, COLORS["GREEN"], (ARENA_X, ARENA_Y, ARENA_WIDTH, ARENA_HEIGHT), 3)
        elif self.healths[3] <= 0 or self.healths[4] <= 0:  # 塔被摧毁
            if self.healths[3] <= 0:
                self.pos_rect1 = pygame.Rect(ARENA_X, ARENA_Y + ARENA_HEIGHT * 10 / 31, ARENA_WIDTH * 0.5,
                                             ARENA_HEIGHT * 5 / 31)
                pygame.draw.rect(self.screen, COLORS["GREEN"], self.pos_rect1, 3)
            if self.healths[4] <= 0:
                self.pos_rect2 = pygame.Rect(ARENA_X + ARENA_WIDTH * 0.5, ARENA_Y + ARENA_HEIGHT * 10 / 31,
                                             ARENA_WIDTH * 0.5, ARENA_HEIGHT * 5 / 31)
                pygame.draw.rect(self.screen, COLORS["GREEN"], self.pos_rect2, 3)

        # 攻击范围预览
        if self.game_state.selected_card.config.attack_range >= 0:
            range_radius = self.game_state.selected_card.config.attack_range
            mouse_x, mouse_y = pygame.mouse.get_pos()

            # 网格对齐
            mouse_x = floor((mouse_x - ARENA_X) / GRID_SIZE) * GRID_SIZE + ARENA_X + GRID_SIZE * 0.5
            mouse_y = floor((mouse_y - ARENA_Y) / GRID_SIZE) * GRID_SIZE + ARENA_Y + GRID_SIZE * 0.5

            if ARENA_X <= mouse_x <= ARENA_X + ARENA_WIDTH and ARENA_Y <= mouse_y <= ARENA_Y + ARENA_HEIGHT:
                # 选中格子高亮
                pygame.draw.rect(self.screen, (255, 255, 255, 192),
                                 (mouse_x - GRID_SIZE * 0.5, mouse_y - GRID_SIZE * 0.5, GRID_SIZE, GRID_SIZE))

                # 范围预览
                range_surface = pygame.Surface((range_radius * 2, range_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(range_surface, (255, 255, 255, 128), (range_radius, range_radius), range_radius, 2)
                self.screen.blit(range_surface, (mouse_x - range_radius, mouse_y - range_radius))

    def draw_game_over(self):
        """绘制游戏结束界面"""
        if not self.game_state:
            return

        self.screen.fill(COLORS["BLACK"])

        # 背景效果
        for _ in range(100):
            x = random.randint(0, SCREEN_WIDTH)
            y = random.randint(0, SCREEN_HEIGHT)
            color = (random.randint(100, 255), random.randint(100, 255), random.randint(100, 255))
            pygame.draw.circle(self.screen, color, (x, y), 4)

        # 游戏结束标题
        game_over_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 72)
        game_over_text = game_over_font.render("游戏结束", True, COLORS["WHITE"])
        game_over_rect = game_over_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 3))
        self.screen.blit(game_over_text, game_over_rect)

        # 获胜者
        winner = "Player" if self.game_state.player_crowns > self.game_state.enemy_crowns else "Enemy"
        winner_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 48)

        if winner == "Player":
            winner_color = COLORS["GREEN"]
            winner_message = "你获胜了！"
        else:
            winner_color = COLORS["RED"]
            winner_message = "你失败了！"

        winner_text = winner_font.render(winner_message, True, winner_color)
        self.screen.blit(winner_text, winner_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 - 30)))

        # 皇冠统计
        crowns_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 36)
        crowns_text = crowns_font.render(f"皇冠: {self.game_state.player_crowns} - {self.game_state.enemy_crowns}",
                                         True, COLORS["GOLD"])
        self.screen.blit(crowns_text, crowns_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 20)))

        # 重新开始按钮
        button_rect = pygame.Rect(SCREEN_WIDTH // 2 - 100, SCREEN_HEIGHT // 2 + 50, 200, 50)
        pygame.draw.rect(self.screen, COLORS["BLUE"], button_rect)
        pygame.draw.rect(self.screen, COLORS["WHITE"], button_rect, 3)

        button_font = pygame.font.Font("C:/Windows/Fonts/simhei.ttf", 24)
        button_text = button_font.render("返回菜单", True, COLORS["WHITE"])
        self.screen.blit(button_text, button_text.get_rect(center=button_rect.center))


# ==================== 主程序入口 ====================
if __name__ == "__main__":
    game = ClashRoyaleGame()
    game.run()
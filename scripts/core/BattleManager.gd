# scripts/core/BattleManager.gd
class_name BattleManager
extends Node3D
const UnitModelKit := preload("res://scripts/visuals/UnitModelKit.gd")
const CardVisualCatalog := preload("res://scripts/visuals/CardVisualCatalog.gd")
const ProceduralAudio := preload("res://scripts/core/ProceduralAudio.gd")
#var ai_system: AISystem
# 容器
@onready var units = $Units
@onready var bullets = $Bullets
@onready var spells = $Spells

# 游戏状态
var last_played_card_id: int = -1
var stats_elixir_spent: Array = [0.0, 0.0]      # [player, enemy]
var stats_elixir_overflow: Array = [0.0, 0.0]   # 满圣水后浪费的圣水
var stats_tower_damage: Array = [{}, {}]        # team -> {card_id: damage}
var _pending_chest_index: int = -1
var _auto_chest_started: bool = false
var player_elixir: float = 7.0
var replay_recorder: Node = null
var match_replay_recorder: Node = null
var replay_mode: bool = false
var replay_skip_towers: bool = false
var network_host_mode: bool = false
var network_guest_mode: bool = false
var network_guest_mirrored: bool = true
var remote_hand: Array = []
var remote_deck: Array = []
var remote_levels: Dictionary = {}
var remote_players: Dictionary = {}
var network_team_sizes: Dictionary = {}
var player_max_elixir: float = 10.0
var remote_max_elixirs: Dictionary = {}
var _ai_timers: Dictionary = {}
var network_countdown: float = 0.0
var network_wait_ready: bool = false
var entry_intro_active: bool = false
var tutorial_battle: bool = false
var tutorial_played: Array = []
var _tutorial_ai_timer: float = 5.0
var _network_count_label: Label = null
var _countdown_overlay: Control = null
var replay_meta: Dictionary = {}
var replay_player_deck: Array = []
var replay_towers: Array = []
var replay_arena: int = 0
var suppress_game_over_ui: bool = false
var enemy_elixir: float = 5.0
var elixir_rate: float = 1.0

# ---- 对战模式（BattleModes 驱动）----
const BATTLE_MODES := preload("res://scripts/core/BattleModes.gd")
var battle_mode: Dictionary = {}
var mode_name: String = "标准对战"
var mode_id: String = "standard"
var sudden_death_enabled: bool = false
var mode_elixir_rate: float = 1.0
var fixed_level_override: int = -1
var mode_player_deck: Array = []
var party_mode: bool = false
var mode_vision_mult: float = 1.0
# 主题特种兵
var commando_mode: bool = false
var commando_card_id: int = -1
var commando_card_name: String = ""
var commando_timer: float = 0.0
var commando_side: int = -1
# 冲线 Touchdown
var win_condition: String = ""
var touchdown_score: Array = [0, 0]
var touchdown_goal: int = 3
var touchdown_resetting: bool = false
var touchdown_round: int = 1
var touchdown_scorer: Unit = null
var _deny_selected_spell: bool = false
# 决斗 Duel
var duel_round: int = 1
var duel_wins: Array = [0, 0]
var duel_transition: bool = false
var duel_finished: bool = false
var duel_match_winner: int = -1
var challenge_result: Dictionary = {}
var mode_enemy_deck: Array = []
var game_time: float = 0.0
var player_crowns: int = 0
var enemy_crowns: int = 0
var winner: int = -1
var game_over: bool = false
var king_sequence: bool = false
var timeout_sequence: bool = false
var overtime: bool = false
var timeout_checked: bool = false
var tower_bleed_active: bool = false
var tower_bleed_acc: float = 0.0
var overtime_end_ms: float = 0.0
var match_draw: bool = false
const SPELL_IDS = [10, 11, 20, 31, 40, 48, 70, 77, 78, 80, 85, 91, 104, 107, 112, 113, 115, 116, 122, 123]   # 万箭齐发,火球,电击法术,大雪球,哥布林飞桶,雷电法术
# 塔血量追踪 [左公主, 右公主, 国王] * 2队
var healths: Array = [0,0,0,0,0,0]

# 卡牌数据
var configs: Array = []

# 玩家卡组与手牌
var card_desk: Array = []            # 存储 card_id
var player_hand: Array = []          # 存储 CardUI 节点
#var selected_card: CardUI = null
var ai_cardlevel:Array = []
# UI 引用
@onready var hud: HUD = $UI

# 计时器
var start_time: float = 0.0
# 拖拽系统
var drag_card: CardUI = null
var drag_preview: Node3D = null
var drag_preview_mat: StandardMaterial3D = null
var drag_valid: bool = false
var roll_preview: MeshInstance3D = null
var _roll_mat: StandardMaterial3D = null
var _roll_edge_mat: StandardMaterial3D = null
var _roll_edges: Array = []
var _roll_arrow: MeshInstance3D = null
# 在文件开头添加变量
var _selected_card: CardUI = null
var is_dragging: bool = false
var deny_left: MeshInstance3D = null
var deny_mid: MeshInstance3D = null
var deny_right: MeshInstance3D = null
var deny_bridge_l: MeshInstance3D = null
var deny_bridge_r: MeshInstance3D = null
var _invalid_tint: StandardMaterial3D = null

var selection_range_ring: MeshInstance3D = null
const EXTEND_ZONE_WIDTH = 9.0
const EXTEND_ZONE_LENGTH = 4.0

# 将原有 selected_card 改为 setget
var selected_card = null:
	get: return _selected_card
	set(value):
		if _selected_card == value: return
		clear_selection_preview()
		_selected_card = value
		if _selected_card != null and not is_dragging:
			create_selection_preview(_selected_card)
func get_king_tower(team: int) -> Unit:
	for unit in units.get_children():
		if unit is Unit and unit.config.card_id == 3 and unit.team == team:
			return unit
	return null
func _create_deny_masks():
	_clean_deny_masks()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	deny_left = _make_deny_plane(mat)
	deny_mid = _make_deny_plane(mat)
	deny_right = _make_deny_plane(mat)
	deny_bridge_l = _make_deny_plane(mat)
	deny_bridge_r = _make_deny_plane(mat)
	_update_deny_masks()

func _clean_deny_masks():
	for m in [deny_left, deny_mid, deny_right, deny_bridge_l, deny_bridge_r]:
		if m:
			m.queue_free()
	deny_left = null
	deny_mid = null
	deny_right = null
	deny_bridge_l = null
	deny_bridge_r = null

func _make_deny_plane(mat: StandardMaterial3D) -> MeshInstance3D:
	var plane = MeshInstance3D.new()
	plane.mesh = PlaneMesh.new()
	plane.material_override = mat
	add_child(plane)
	return plane

func _update_deny_masks():
	if win_condition == "touchdown":
		for m in [deny_left, deny_mid, deny_right, deny_bridge_l, deny_bridge_r]:
			if m:
				m.visible = false
		if deny_mid == null:
			return
		var origin_z: float = Config.ARENA_ORIGIN.z
		var h: float = Config.ARENA_HEIGHT
		if _deny_selected_spell:
			# 法术可放己方 2/3：遮住敌方最后 1/3
			var spell_line: float = origin_z + h / 3.0
			deny_mid.visible = true
			_apply_deny_plane(deny_mid, 0.0, Config.ARENA_WIDTH,
				spell_line - origin_z, origin_z + (spell_line - origin_z) * 0.5)
			return
		var own_line: float = origin_z + h * 2.0 / 3.0
		deny_mid.visible = true
		_apply_deny_plane(deny_mid, 0.0, Config.ARENA_WIDTH,
			own_line - origin_z, (origin_z + own_line) * 0.5)
		return
	if deny_bridge_l:
		_apply_deny_plane(deny_bridge_l, -5.5, 3.0, 3.0, 0.0)
	if deny_bridge_r:
		_apply_deny_plane(deny_bridge_r, 5.5, 3.0, 3.0, 0.0)
	if not deny_left or not deny_mid or not deny_right:
		return
	@warning_ignore("unused_variable")
	var half_width = EXTEND_ZONE_WIDTH / 2.0
	var left_tower_x = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0
	var right_tower_x = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0
	var left_alive = healths[3] > 0
	var right_alive = healths[4] > 0

	# 可部署缺口 + 遮罩边界
	var left_cover_right = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 9.0 / 18.0
	var right_cover_left = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 9.0 / 18.0

	var arena_left = Config.ARENA_ORIGIN.x
	var arena_right = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH
	var enemy_z_center = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 1.0 / 4.0
	var enemy_height = Config.ARENA_HEIGHT / 2.0

	# 左侧遮罩
	var left_center_x = (arena_left + left_cover_right) / 2.0
	var left_width = left_cover_right - arena_left
	if left_alive:
		# 与中间遮罩无缝衔接（z: -4 ~ -1），避免重叠出现亮红线
		_apply_deny_plane(deny_left, left_center_x, left_width, Config.ARENA_HEIGHT*3.0 / 32.0, Config.ARENA_ORIGIN.z+Config.ARENA_HEIGHT*13.5 / 32.0)

	# 中间遮罩
	var mid_center_x = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 9.0 / 18.0
	var mid_width = Config.ARENA_WIDTH
	_apply_deny_plane(deny_mid, mid_center_x, mid_width, Config.ARENA_HEIGHT*11.0 / 32.0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 6.5 / 32.0)

	# 右侧遮罩
	var right_center_x = (right_cover_left + arena_right) / 2.0
	var right_width = arena_right - right_cover_left
	if right_alive:
		_apply_deny_plane(deny_right, right_center_x, right_width, Config.ARENA_HEIGHT*3.0 / 32.0, Config.ARENA_ORIGIN.z+Config.ARENA_HEIGHT*13.5 / 32.0)

func _apply_deny_plane(plane: MeshInstance3D, center_x: float, width: float, height: float, center_z: float):
	
	plane.position = Vector3(center_x, 0.03, center_z)
	var pmesh = plane.mesh as PlaneMesh
	if pmesh:
		pmesh.size = Vector2(max(width, 0.01), height)
func create_selection_preview(card_ui: CardUI):
	var cfg = card_ui.config
	_deny_selected_spell = SPELL_IDS.has(cfg.card_id) or cfg.card_id == 110
	# ----- 不可放置区域红色遮罩 -----
	# 冲线模式部队/法术使用不同的半区限制，都需要创建遮罩；
	# 其他模式法术仍不显示不可放置遮罩。
	if win_condition == "touchdown" or (not SPELL_IDS.has(cfg.card_id) and cfg.card_id != 109):
		_create_deny_masks()
	else:
		_clean_deny_masks()
	# ----- 攻击范围圆环（初始隐藏，鼠标移动时显示）-----
	if cfg.attack_range > 0.1:
		selection_range_ring = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = cfg.attack_range - 0.05
		torus.outer_radius = cfg.attack_range + 0.05
		selection_range_ring.mesh = torus
		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = Color(1, 1, 1, 0.5)
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		selection_range_ring.material_override = ring_mat
		selection_range_ring.visible = false
		add_child(selection_range_ring)

func clear_selection_preview():
	_deny_selected_spell = false
	_update_deny_masks()
	
	if selection_range_ring:
		selection_range_ring.queue_free()
		selection_range_ring = null
	_clean_deny_masks()
func update_selection_preview(screen_pos: Vector2):
	if not selection_range_ring: return
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 100
	var result = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if result and result.collider.name == "GroundPlane":
		var p = result.position
		p.x = floor((p.x - Config.ARENA_ORIGIN.x) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.x + Config.GRID_SIZE * 0.5
		p.z = floor((p.z - Config.ARENA_ORIGIN.z) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.z + Config.GRID_SIZE * 0.5
		p.y = 0.02
		selection_range_ring.global_position = p
		selection_range_ring.visible = true
	else:
		selection_range_ring.visible = false
func start_drag(card_ui: CardUI):
	cancel_drag()  # 清除之前残留
	drag_card = card_ui
	#is_dragging = true
	selected_card = card_ui   # 立即显示费用高亮框

	drag_preview = Node3D.new()
	var cfg = card_ui.config

	# 用真实单位模型做半透明放置预览
	var spec: Dictionary = CardVisualCatalog.spec_for(cfg.card_name, Config.Team.PLAYER, cfg.attack_range)
	var count: int = cfg.num if cfg.num > 0 else 1
	for i in range(count):
		var vis: Node3D = UnitModelKit.create_unit(spec)
		var off := Vector3.ZERO
		if count > 1:
			if cfg.card_id == 74:
				off = Vector3((float(i) - (float(count) - 1.0) * 0.5) * 1.8, 0.0, 0.0)
			else:
				var ang: float = (float(i) / float(count)) * TAU
				if cfg.type == Config.UnitType.AIR:
					off = Vector3(cos(ang), 3.0, sin(ang)) * 0.6
				else:
					off = Vector3(cos(ang), cfg.size, sin(ang)) * 0.6
		vis.position = off
		_set_preview_alpha(vis, 0.65)
		drag_preview.add_child(vis)

	add_child(drag_preview)
	drag_preview.name = "DragPreview"
	if cfg.card_id == 91 or cfg.card_id == 110:
		roll_preview = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.9 if cfg.card_id == 91 else 2.6, 0.02, 10.1 if cfg.card_id == 91 else 4.5)
		roll_preview.mesh = bm
		_roll_mat = StandardMaterial3D.new()
		_roll_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_roll_mat.albedo_color = Color(0.30, 1.0, 0.50, 0.42)
		_roll_mat.emission_enabled = true
		_roll_mat.emission = Color(0.20, 0.90, 0.38)
		_roll_mat.emission_energy_multiplier = 0.8
		_roll_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_roll_mat.no_depth_test = true
		roll_preview.material_override = _roll_mat
		_roll_edge_mat = StandardMaterial3D.new()
		_roll_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_roll_edge_mat.albedo_color = Color(0.55, 1.0, 0.60, 0.95)
		_roll_edge_mat.no_depth_test = true
		for k in range(4):
			var edge := MeshInstance3D.new()
			var eb := BoxMesh.new()
			edge.mesh = eb
			edge.material_override = _roll_edge_mat
			roll_preview.add_child(edge)
			_roll_edges.append(edge)
		_roll_arrow = MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.45
		cone.height = 1.0
		_roll_arrow.mesh = cone
		_roll_arrow.material_override = _roll_edge_mat
		roll_preview.add_child(_roll_arrow)
		roll_preview.visible = false
		add_child(roll_preview)

func _set_preview_tint(node: Node, invalid: bool) -> void:
	if _invalid_tint == null:
		_invalid_tint = StandardMaterial3D.new()
		_invalid_tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_invalid_tint.albedo_color = Color(1.0, 0.18, 0.14, 0.55)
		_invalid_tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = _invalid_tint if invalid else null
	for c in node.get_children():
		_set_preview_tint(c, invalid)

func _set_preview_alpha(node: Node, a: float) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).transparency = a
	for c in node.get_children():
		_set_preview_alpha(c, a)
func is_valid_placement(config: CardData, pos: Vector3, team: int) -> bool:
	if win_condition == "touchdown":
		if _is_spell_like(config.card_id):
			return _touchdown_spell_zone_ok(team, pos)
		return _touchdown_unit_zone_ok(team, pos)
	if SPELL_IDS.has(config.card_id):
		return true
	if config.card_id == 109:
		return true
	var mid_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
	# 桥面：只有对应一侧的敌方皇家塔被摧毁后才可放置
	if absf(pos.z) <= 1.5 and absf(absf(pos.x) - 5.5) <= 1.5:
		var left_destroyed: bool = healths[3] <= 0 if team == Config.Team.PLAYER else healths[0] <= 0
		var right_destroyed: bool = healths[4] <= 0 if team == Config.Team.PLAYER else healths[1] <= 0
		if pos.x < 0 and not left_destroyed:
			return false
		if pos.x > 0 and not right_destroyed:
			return false
		return true
	# 最后一排：只有国王塔正后方 6 格可用
	var back_line: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT - 1.0
	var front_line: float = Config.ARENA_ORIGIN.z + 1.0
	if (pos.z >= back_line or pos.z <= front_line) and absf(pos.x) > 3.0:
		return false
	if team == Config.Team.PLAYER:
		if pos.z >= mid_z:
			return true
		if healths[3] <= 0 and _in_extended_zone(pos, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5/18):
			return true
		if healths[4] <= 0 and _in_extended_zone(pos, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5/18):
			return true
	else:
		if pos.z <= mid_z:
			return true
		if healths[0] <= 0 and _in_extended_zone_enemy(pos, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5/18):
			return true
		if healths[1] <= 0 and _in_extended_zone_enemy(pos, Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5/18):
			return true
	return false

func _is_spell_like(card_id: int) -> bool:
	return SPELL_IDS.has(card_id) or card_id == 110


func _touchdown_unit_zone_ok(team: int, pos: Vector3) -> bool:
	var z0: float = Config.ARENA_ORIGIN.z
	var h: float = Config.ARENA_HEIGHT
	if team == Config.Team.PLAYER:
		return pos.z >= z0 + h * 2.0 / 3.0 and pos.z <= z0 + h
	return pos.z <= z0 + h / 3.0 and pos.z >= z0


func _touchdown_spell_zone_ok(team: int, pos: Vector3) -> bool:
	var z0: float = Config.ARENA_ORIGIN.z
	var h: float = Config.ARENA_HEIGHT
	if team == Config.Team.PLAYER:
		return pos.z >= z0 + h / 3.0 and pos.z <= z0 + h
	return pos.z <= z0 + h * 2.0 / 3.0 and pos.z >= z0


func _in_extended_zone(pos: Vector3, tower_x: float) -> bool:
	var mid_z = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT / 2   # 桥线
	return abs(pos.x - tower_x) <= 5.5 and pos.z >= mid_z - 4.5 and pos.z <= mid_z

func _in_extended_zone_enemy(pos: Vector3, tower_x: float) -> bool:
	var mid_z = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT / 2
	return abs(pos.x - tower_x) <= 5.5 and pos.z >= mid_z and pos.z <= mid_z + 4.5
func update_drag(screen_pos: Vector2):
	if not drag_preview: return
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 100
	var result = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if result and result.collider.name == "GroundPlane":
		var p = result.position
		p.x = floor((p.x - Config.ARENA_ORIGIN.x) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.x + Config.GRID_SIZE * 0.5
		p.z = floor((p.z - Config.ARENA_ORIGIN.z) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.z + Config.GRID_SIZE * 0.5
		# 根据不同单位类型设置高度
		if drag_card and drag_card.config.type == Config.UnitType.AIR:
			p.y = 1.8   # 空军悬浮高度
		else:
			p.y = 0.05
		drag_preview.global_position = p

		# 合法性检测
		var valid = false
		var cfg = drag_card.config
		if SPELL_IDS.has(cfg.card_id) or cfg.card_id == 110:
			valid = _touchdown_spell_zone_ok(Config.Team.PLAYER, p) if win_condition == "touchdown" else true
			
			
		else:
			valid = is_valid_placement(drag_card.config, p, Config.Team.PLAYER)
		drag_valid = valid
		if roll_preview:
			var rw: float = 3.9 if cfg.card_id == 91 else 2.6
			var rl: float = 10.1 if cfg.card_id == 91 else 4.5
			var bmesh := roll_preview.mesh as BoxMesh
			if bmesh:
				bmesh.size = Vector3(rw, 0.02, rl)
			roll_preview.global_position = p + Vector3(0, 0.10, -rl * 0.5)
			roll_preview.visible = true
			# 边框：两侧长边 + 前后短边
			if _roll_edges.size() == 4:
				var e0: MeshInstance3D = _roll_edges[0]
				var e1: MeshInstance3D = _roll_edges[1]
				var e2: MeshInstance3D = _roll_edges[2]
				var e3: MeshInstance3D = _roll_edges[3]
				(e0.mesh as BoxMesh).size = Vector3(0.10, 0.04, rl)
				(e1.mesh as BoxMesh).size = Vector3(0.10, 0.04, rl)
				(e2.mesh as BoxMesh).size = Vector3(rw, 0.04, 0.10)
				(e3.mesh as BoxMesh).size = Vector3(rw, 0.04, 0.10)
				e0.position = Vector3(-rw * 0.5, 0.03, 0)
				e1.position = Vector3(rw * 0.5, 0.03, 0)
				e2.position = Vector3(0, 0.03, -rl * 0.5)
				e3.position = Vector3(0, 0.03, rl * 0.5)
			if _roll_arrow:
				_roll_arrow.position = Vector3(0, 0.10, -rl * 0.5 - 0.55)
				_roll_arrow.rotation = Vector3(-PI * 0.5, 0, 0)
			if _roll_mat:
				_roll_mat.albedo_color = Color(0.30, 1.0, 0.50, 0.42) if valid else Color(1.0, 0.22, 0.18, 0.42)
			if _roll_edge_mat:
				_roll_edge_mat.albedo_color = Color(0.55, 1.0, 0.60, 0.95) if valid else Color(1.0, 0.35, 0.25, 0.95)
		# 更新预览颜色（共用半透明材质）
		if drag_preview.get_child_count() > 0:
			_set_preview_alpha(drag_preview.get_child(0), 0.65 if valid else 0.85)
			_set_preview_tint(drag_preview.get_child(0), not valid)
		if drag_preview.get_child_count() > 0:
			(drag_preview.get_child(0) as Node3D).visible = not SPELL_IDS.has(cfg.card_id) and cfg.card_id != 91 and cfg.card_id != 110
	else:
		drag_preview.global_position = Vector3(0, -999, 0)

func end_drag(screen_pos: Vector2):
	if touchdown_resetting:
		cancel_drag()
		return
	if network_host_mode and network_countdown > 0.0:
		cancel_drag()
		return
	if network_guest_mode:
		if not drag_card:
			return
		var gpos := Vector3.ZERO
		var gcam = get_viewport().get_camera_3d()
		if gcam:
			var gf = gcam.project_ray_origin(screen_pos)
			var gt = gf + gcam.project_ray_normal(screen_pos) * 100.0
			var gr = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(gf, gt))
			if gr and gr.collider and gr.collider.name == "GroundPlane":
				gpos = gr.position
		if gpos != Vector3.ZERO:
			var cx: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
			var cz: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
			if network_guest_mirrored:
				NetworkManager.request_deploy(drag_card.config.card_id, cx * 2.0 - gpos.x, cz * 2.0 - gpos.z)
			else:
				NetworkManager.request_deploy(drag_card.config.card_id, gpos.x, gpos.z)
		cancel_drag()
		return
	if not drag_card:
		return
	if hud and hud.table_bg:
		if hud.table_bg.get_global_rect().has_point(screen_pos):
			cancel_drag()
			return
	var deploy_pos = Vector3.ZERO
	var cam = get_viewport().get_camera_3d()
	if cam:
		var from = cam.project_ray_origin(screen_pos)
		var to = from + cam.project_ray_normal(screen_pos) * 100.0
		var result = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		if result and result.collider.name == "GroundPlane":
			deploy_pos = result.position
			deploy_pos.x = floor((deploy_pos.x - Config.ARENA_ORIGIN.x) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.x + Config.GRID_SIZE * 0.5
			deploy_pos.z = floor((deploy_pos.z - Config.ARENA_ORIGIN.z) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.z + Config.GRID_SIZE * 0.5
			if drag_card and drag_card.config.type == Config.UnitType.AIR:
				deploy_pos.y = 1.8
	if drag_valid and player_elixir >= card_cost(drag_card.config):
		if SPELL_IDS.has(drag_card.config.card_id):
			deploy_spell(drag_card.config, Config.Team.PLAYER, deploy_pos)
		elif drag_card.config.card_id == 109:
			_deploy_miner_tunnel(drag_card.config, Config.Team.PLAYER, deploy_pos)
		elif drag_card.config.card_id == 110:
			_deploy_log_like(drag_card.config, Config.Team.PLAYER, deploy_pos)
		else:
			spawn_unit(drag_card.config, Config.Team.PLAYER, deploy_pos)
		_record_tutorial_card(int(drag_card.config.card_id))
		if not SPELL_IDS.has(int(drag_card.config.card_id)):
			PlayerData.record_card_use(int(drag_card.config.card_id))
		if replay_recorder:
			replay_recorder.record_player_action(drag_card.config, deploy_pos)
		if match_replay_recorder:
			match_replay_recorder.record_action(Config.Team.PLAYER, drag_card.config.card_id, deploy_pos)
		var dcost: int = card_cost(drag_card.config)
		player_elixir -= dcost
		stats_elixir_spent[Config.Team.PLAYER] += dcost
		if drag_card.config.card_id != 123:
			last_played_card_id = drag_card.config.card_id
		_cycle_card(drag_card)
	cancel_drag()

func cancel_drag():
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null
	drag_card = null
	drag_valid = false
	if roll_preview:
		roll_preview.queue_free()
		roll_preview = null
	is_dragging = false
	selected_card = null
	_clean_deny_masks()

func _resolve_battle_mode() -> void:
	# 联机对局：使用房主下发的派对规则（默认标准）
	if network_host_mode or network_guest_mode:
		var rule := "standard"
		if not NetworkManager.match_info.is_empty():
			rule = String(NetworkManager.match_info.get("party_rule", "standard"))
			if rule == "custom" and NetworkManager.match_info.get("custom_config", {}) is Dictionary:
				BATTLE_MODES.set_custom_config(Dictionary(NetworkManager.match_info.get("custom_config", {})))
		battle_mode = BATTLE_MODES.current() if rule == "custom" else BATTLE_MODES.get_by_id(rule)
	# 开发/自动化测试：CR_MODE_ID=double_elixir 等
	var env_mode := OS.get_environment("CR_MODE_ID")
	if env_mode != "" and not replay_mode:
		battle_mode = BATTLE_MODES.get_by_id(env_mode)
		if env_mode == "custom":
			battle_mode["elixir"] = float(OS.get_environment("CR_MODE_ELIXIR")) if OS.get_environment("CR_MODE_ELIXIR") != "" else 1.0
	if battle_mode.is_empty():
		battle_mode = BATTLE_MODES.current()
	mode_name = String(battle_mode.get("name", "标准对战"))
	mode_id = String(battle_mode.get("id", "standard"))
	sudden_death_enabled = bool(battle_mode.get("sudden_death", false))
	win_condition = String(battle_mode.get("win_condition", ""))
	touchdown_goal = int(battle_mode.get("score_to_win", 3))
	party_mode = bool(battle_mode.get("party", false))
	mode_vision_mult = 1.5 if win_condition == "touchdown" else 1.0
	Config.set_arena_size(
		Config.ARENA_TOUCHDOWN_WIDTH if win_condition == "touchdown" else Config.ARENA_BASE_WIDTH,
		Config.ARENA_TOUCHDOWN_HEIGHT if win_condition == "touchdown" else Config.ARENA_BASE_HEIGHT)
	mode_elixir_rate = float(battle_mode.get("elixir", 1.0))
	fixed_level_override = 11 if String(battle_mode.get("level", "own")) == "fixed" else -1
	if party_mode or PlayerData.test_mode:
		fixed_level_override = 11
	commando_mode = bool(battle_mode.get("commando", false))
	if commando_mode:
		_setup_commando()
	mode_player_deck.clear()
	mode_enemy_deck.clear()
	var deck_src := String(battle_mode.get("deck", "custom"))
	if deck_src == "classic":
		var decks: Array = BATTLE_MODES.classic_decks()
		if decks.size() > 0:
			mode_player_deck = _sanitize_mode_deck(decks[randi() % decks.size()])
			mode_enemy_deck = _sanitize_mode_deck(decks[randi() % decks.size()])
	elif deck_src == "draft":
		var drafted: Dictionary = BATTLE_MODES.draft_decks()
		mode_player_deck = _sanitize_mode_deck(drafted.get("player", []))
		mode_enemy_deck = _sanitize_mode_deck(drafted.get("enemy", []))
		if mode_player_deck.size() < 8 or mode_enemy_deck.size() < 8:
			# 未经过选卡界面（例如开发环境直接启动）：自动随机选卡
			mode_player_deck = _random_draft_deck(int(battle_mode.get("draft_choices", 4)))
			mode_enemy_deck = _random_draft_deck(int(battle_mode.get("draft_choices", 4)))
	elif deck_src == "mega":
		mode_player_deck = _build_mega_deck(Config.Team.PLAYER)
		mode_enemy_deck = _build_mega_deck(Config.Team.ENEMY)
	elif deck_src == "mirror":
		mode_player_deck = _build_party_deck(Config.Team.PLAYER)
		mode_enemy_deck = mode_player_deck.duplicate()
	elif deck_src == "swap_draft":
		if network_host_mode or network_guest_mode:
			var host_swap: Array = _sanitize_mode_deck(NetworkManager.network_draft_decks.get(1, []))
			mode_player_deck = host_swap if host_swap.size() >= 8 else _random_draft_deck(4)
			if OS.get_environment("CR_MODE_DEBUG") != "":
				print("[DraftNet] battle host swap deck=", str(mode_player_deck), " all=", str(NetworkManager.network_draft_decks))
			mode_enemy_deck = _random_draft_deck(4)
		else:
			var swap: Dictionary = BATTLE_MODES.swap_decks()
			mode_player_deck = _sanitize_mode_deck(swap.get("player", []))
			mode_enemy_deck = _sanitize_mode_deck(swap.get("enemy", []))
			if mode_player_deck.size() < 8 or mode_enemy_deck.size() < 8:
				mode_player_deck = _random_draft_deck(4)
				mode_enemy_deck = _random_draft_deck(4)
	elif deck_src == "duel" or win_condition == "duel":
		var st: Dictionary = BATTLE_MODES.duel_state()
		if not bool(st.get("active", false)):
			BATTLE_MODES.start_duel(_fallback_duel_decks(Config.Team.PLAYER), _fallback_duel_decks(Config.Team.ENEMY))
			st = BATTLE_MODES.duel_state()
		duel_round = clampi(int(st.get("round", 1)), 1, 3)
		duel_wins = Array(st.get("wins", [0, 0])).duplicate()
		var pds: Array = Array(st.get("player_decks", []))
		var eds: Array = Array(st.get("enemy_decks", []))
		if pds.size() >= duel_round:
			mode_player_deck = _sanitize_mode_deck(pds[duel_round - 1])
		if eds.size() >= duel_round:
			mode_enemy_deck = _sanitize_mode_deck(eds[duel_round - 1])
	if party_mode and deck_src == "custom":
		mode_player_deck = _sanitize_mode_deck(PlayerData.party_deck)
		if mode_player_deck.size() < 8:
			mode_player_deck = _build_party_deck(Config.Team.PLAYER)
		mode_enemy_deck = _build_party_deck(Config.Team.ENEMY)
	if OS.has_environment("CR_MODE_DEBUG"):
		print("[Mode] id=%s name=%s elixir=%.1f sudden_death=%s player_deck=%d enemy_deck=%d" % [
			mode_id, mode_name, mode_elixir_rate, str(sudden_death_enabled),
			mode_player_deck.size(), mode_enemy_deck.size()])


func _sanitize_mode_deck(src: Array) -> Array:
	var out: Array = []
	for cid_v in src:
		var cid: int = int(cid_v)
		if get_config(cid) != null and not out.has(cid):
			out.append(cid)
	return out


func _setup_commando() -> void:
	var candidates: Array = []
	for cfg in configs:
		if cfg.cost <= 0 or cfg.card_id < 4 or cfg.card_id == 123:
			continue
		if cfg.type == Config.UnitType.BUILDING:
			continue
		if SPELL_IDS.has(cfg.card_id) or cfg.card_id == 110:
			continue
		candidates.append(int(cfg.card_id))
	if candidates.is_empty():
		return
	var seed: int = BATTLE_MODES.commando_seed()
	if seed < 0:
		commando_card_id = clampi(-seed, 4, 9999)
		if get_config(commando_card_id) == null:
			commando_card_id = int(candidates[0])
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		commando_card_id = int(candidates[rng.randi() % candidates.size()])
	var cfg = get_config(commando_card_id)
	commando_card_name = cfg.card_name if cfg else ""


func _update_commando(delta: float) -> void:
	if not commando_mode or game_over or commando_card_id < 0:
		return
	commando_timer += delta
	if commando_timer < 15.0:
		return
	while commando_timer >= 15.0:
		commando_timer -= 15.0
	var count: int = 1 + int(game_time / 60000.0)
	_spawn_commando_wave(count)


func _spawn_commando_wave(count: int) -> void:
	var cfg = get_config(commando_card_id)
	if cfg == null:
		return
	var cx: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
	var player_king_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 29.0 / 32.0
	var enemy_king_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 3.0 / 32.0
	var side: int = commando_side
	for i in count:
		var dx: float = float(side) * (2.4 + float(i) * 0.9)
		var pz: float = player_king_z - 3.2
		var ez: float = enemy_king_z + 3.2
		var ppos := Vector3(cx + dx, 0.0, pz)
		var epos := Vector3(cx - dx, 0.0, ez)
		var lv: int = mode_level(Config.battle_level(PlayerData.get_card_level(commando_card_id)))
		spawn_unit(cfg, Config.Team.PLAYER, ppos, -1, lv)
		spawn_unit(cfg, Config.Team.ENEMY, epos, -1, lv)
	commando_side = -commando_side


func _build_party_deck(team: int) -> Array:
	var out: Array = []
	if team == Config.Team.PLAYER:
		out = _sanitize_mode_deck(PlayerData.party_deck)
	var pool: Array = []
	for cfg in configs:
		if cfg.cost > 0 and cfg.card_id >= 4 and cfg.card_id != 123:
			pool.append(int(cfg.card_id))
	pool.shuffle()
	for cid in pool:
		if out.size() >= 8:
			break
		if not out.has(cid):
			out.append(cid)
	return out


func _fallback_duel_decks(team: int) -> Array:
	var decks: Array = []
	if team == Config.Team.PLAYER:
		for d in PlayerData.custom_decks:
			var arr: Array = []
			for cid in Array(d):
				if int(cid) > 0 and get_config(int(cid)) != null:
					arr.append(int(cid))
			if arr.size() >= 8:
				decks.append(arr)
				if decks.size() >= 3:
					break
		while decks.size() < 3:
			decks.append(PlayerData.get_active_deck().duplicate())
	else:
		var classics: Array = BATTLE_MODES.classic_decks()
		classics.shuffle()
		for i in range(3):
			if classics.is_empty():
				break
			decks.append(Array(classics[i % classics.size()]).duplicate())
		while decks.size() < 3:
			decks.append(_random_draft_deck(4))
	return decks


func _draft_pool() -> Array:
	var pool: Array = []
	for cfg in configs:
		if cfg.cost > 0 and cfg.card_id >= 4 and cfg.card_id != 123:
			pool.append(int(cfg.card_id))
	return pool


func _random_draft_deck(_choices: int) -> Array:
	var pool: Array = _draft_pool()
	pool.shuffle()
	var out: Array = []
	for cid in pool:
		if out.size() >= 8:
			break
		if not out.has(cid):
			out.append(cid)
	return out


func _build_mega_deck(team: int) -> Array:
	var out: Array = []
	if team == Config.Team.PLAYER:
		for cid_v in PlayerData.get_active_deck():
			var cid: int = int(cid_v)
			if get_config(cid) != null and PlayerData.is_card_owned(cid) and not out.has(cid):
				out.append(cid)
		var pool: Array = []
		for cfg in configs:
			if cfg.cost > 0 and cfg.card_id >= 4 and cfg.card_id != 123 and PlayerData.is_card_owned(cfg.card_id):
				pool.append(int(cfg.card_id))
		pool.shuffle()
		for cid in pool:
			if out.size() >= 18:
				break
			if not out.has(cid):
				out.append(cid)
	else:
		var pool: Array = []
		var allowed: Array = PlayerData.get_ai_allowed_cards()
		for cfg in configs:
			if cfg.cost > 0 and cfg.card_id >= 4 and cfg.card_id != 123 and allowed.has(cfg.card_id):
				pool.append(int(cfg.card_id))
		pool.shuffle()
		for cid in pool:
			if out.size() >= 18:
				break
			if not out.has(cid):
				out.append(cid)
	return out


func mode_level(level: int) -> int:
	return fixed_level_override if fixed_level_override > 0 else level


func mode_badge_text() -> String:
	return BATTLE_MODES.mode_label(battle_mode)


func _team_tower_total_health(team: int) -> float:
	var total := 0.0
	for u in units.get_children():
		if u is Unit and u.config and u.config.card_id <= 3 and u.team == team:
			total += maxf(0.0, float(u.health))
	return total


func _setup_touchdown_zones() -> void:
	var top_z: float = Config.ARENA_ORIGIN.z + 3.0
	var bottom_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT - 3.0
	_add_touchdown_zone(Vector3(0, 0.03, top_z), Color(0.30, 0.55, 1.0, 0.28))
	_add_touchdown_zone(Vector3(0, 0.03, bottom_z), Color(1.0, 0.30, 0.28, 0.28))


func _add_touchdown_zone(center: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(Config.ARENA_WIDTH * 0.94, 0.03, 4.0)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position = center
	add_child(mi)
	# 金色边线提示
	var line := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(Config.ARENA_WIDTH * 0.94, 0.035, 0.10)
	line.mesh = lb
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.78, 0.36, 0.9)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line.material_override = lm
	line.position = center + Vector3(0, 0.005, 2.0)
	add_child(line)
	var line2 := MeshInstance3D.new()
	var lb2 := BoxMesh.new()
	lb2.size = Vector3(Config.ARENA_WIDTH * 0.94, 0.035, 0.10)
	line2.mesh = lb2
	line2.material_override = lm
	line2.position = center + Vector3(0, 0.005, -2.0)
	add_child(line2)


func _update_touchdown() -> void:
	var top_z: float = Config.ARENA_ORIGIN.z + 5.5
	var bottom_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT - 5.5
	for u in units.get_children():
		if not (u is Unit) or u.config == null or u.health <= 0:
			continue
		if int(u.config.card_id) < 4:
			continue
		var z: float = u.global_position.z
		if u.team == Config.Team.PLAYER and z <= top_z:
			_touchdown_score(Config.Team.PLAYER, u)
			return
		if u.team == Config.Team.ENEMY and z >= bottom_z:
			_touchdown_score(Config.Team.ENEMY, u)
			return


func _touchdown_score(team: int, scorer: Unit = null) -> void:
	if touchdown_resetting or game_over:
		return
	touchdown_score[team] = int(touchdown_score[team]) + 1
	touchdown_round += 1
	if hud and hud.has_method("set_touchdown_score"):
		hud.set_touchdown_score(int(touchdown_score[0]), int(touchdown_score[1]), touchdown_goal)
	if int(touchdown_score[team]) >= touchdown_goal:
		game_over = true
		winner = team
		return
	_touchdown_round_break(scorer)


func _touchdown_round_break(scorer: Unit = null) -> void:
	# 立即清空场上所有单位/子弹/法术
	touchdown_resetting = true
	touchdown_scorer = scorer
	if network_host_mode:
		NetworkManager.send_touchdown_break(touchdown_round, int(touchdown_score[0]), int(touchdown_score[1]))
	var victims: Array = []
	for u in units.get_children():
		if u is Unit and u != scorer:
			victims.append(u)
	for u in victims:
		if is_instance_valid(u):
			u.queue_free()
	if scorer != null and is_instance_valid(scorer):
		scorer.play_touchdown_cheer()
	for b in bullets.get_children():
		b.queue_free()
	for s in spells.get_children():
		s.queue_free()
	if hud and hud.has_method("show_touchdown_round_break"):
		hud.show_touchdown_round_break(touchdown_round, int(touchdown_score[0]), int(touchdown_score[1]))
	# 2 秒内不可放牌；结束后双方圣水重置为 5
	await get_tree().create_timer(2.0).timeout
	player_elixir = 5.0
	enemy_elixir = 5.0
	for sk in remote_players.keys():
		var rp: Dictionary = remote_players[sk]
		rp["elixir"] = 5.0
		remote_players[sk] = rp
	if scorer != null and is_instance_valid(scorer):
		scorer.queue_free()
	touchdown_scorer = null
	if hud and hud.has_method("hide_touchdown_round_break"):
		hud.hide_touchdown_round_break()
	if network_host_mode:
		NetworkManager.send_touchdown_break_end()
	touchdown_resetting = false


func _ready():
	add_to_group("battle_manager")
	_apply_mobile_safe_rendering()
	tutorial_battle = PlayerData.tutorial_practice or OS.get_environment("CR_TUTORIAL_BATTLE") != ""
	PlayerData.tutorial_practice = false
	network_host_mode = NetworkManager.role == NetworkManager.Role.HOST and NetworkManager.consume_host_match()
	if network_host_mode:
		_setup_network_team_sizes()
	load_card_configs()
	_resolve_battle_mode()
	spawn_initial_towers()
	if win_condition == "touchdown":
		_setup_touchdown_zones()
	_initialize_player_deck()
	if network_host_mode:
		_init_network_remote()
	if tutorial_battle:
		_spawn_tutorial_targets()
	hud.battle = self
	if network_host_mode and hud.has_signal("emote_sent"):
		hud.emote_sent.connect(func(id, team): NetworkManager.broadcast_emote(id, team))
	start_time = Time.get_ticks_msec()
	if replay_mode:
		var bgm_r = load("res://assets/audio/bgm/battle_theme.ogg")
		if bgm_r:
			AudioManager.play_bgm(bgm_r)
		return
	var ai_system = null
	if network_host_mode:
		add_child(preload("res://scripts/net/NetworkHost.gd").new())
		if PlayerData.record_replays:
			match_replay_recorder = preload("res://scripts/core/ReplayRecorder.gd").new()
			match_replay_recorder._snap_interval = 0.05
			add_child(match_replay_recorder)
		NetworkManager.clients_ready.connect(_on_clients_ready)
		network_wait_ready = NetworkManager.guest_count() > 0
		entry_intro_active = true
		if NetworkManager.all_clients_ready():
			call_deferred("_on_clients_ready")
		else:
			call_deferred("_network_ready_timeout")
	elif not tutorial_battle:
		ai_system = preload("res://scripts/ai/AISystem.gd").new()
		add_child(ai_system)
	if PlayerData.record_replays and not network_host_mode:
		replay_recorder = preload("res://scripts/core/MatchRecorder.gd").new()
		add_child(replay_recorder)
		if replay_recorder.has_method("bind_ai") and ai_system:
			replay_recorder.bind_ai(ai_system)
		match_replay_recorder = preload("res://scripts/core/ReplayRecorder.gd").new()
		add_child(match_replay_recorder)
	var bgm = load("res://assets/audio/bgm/battle_theme.ogg")
	if bgm:
		AudioManager.play_bgm(bgm)
	if not network_host_mode:
		entry_intro_active = true
		call_deferred("play_entry_intro")

func _apply_mobile_safe_rendering() -> void:
	# 手机端稳定性：Compatibility + Android 驱动对 MSAA/SSAO/辉光/阴影较敏感。
	# 关闭这些高风险的 3D 后处理，并降低 3D 渲染分辨率；菜单/2D UI 不受影响。
	if not OS.has_feature("mobile") and OS.get_environment("CR_MOBILE_SAFE") != "1":
		return
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = 0.72
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment.ssao_enabled = false
		we.environment.glow_enabled = false
		we.environment.background_mode = Environment.BG_COLOR
		we.environment.background_color = Color(0.08, 0.13, 0.22)
	var dl := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if dl:
		dl.shadow_enabled = false



func _setup_network_team_sizes() -> void:
	network_team_sizes.clear()
	for seat in NetworkManager.match_info.get("seats", []):
		var tm: int = int(seat.get("team", 0))
		network_team_sizes[tm] = int(network_team_sizes.get(tm, 0)) + 1
	player_max_elixir = 20.0 if (team_size(0) == 1 and team_size(1) >= 2) else 10.0

func team_size(team: int) -> int:
	return int(network_team_sizes.get(team, 1))

func king_duo(team: int) -> bool:
	return network_host_mode and team_size(team) >= 2

func team_elixir_cap(team: int) -> float:
	return 20.0 if (team_size(team) == 1 and team_size(1 - team) >= 2) else 10.0

func team_elixir_gain_mult(team: int) -> float:
	return 2.0 if (team_size(team) == 1 and team_size(1 - team) >= 2) else 1.0

func _can_slot_place(_slot: int, _pos: Vector3) -> bool:
	return true

func _init_network_remote() -> void:
	var info: Dictionary = NetworkManager.match_info
	remote_players.clear()
	var seat_list: Array = info.get("seats", [])
	for seat in seat_list:
		var team: int = int(seat.get("team", 0))
		var idx: int = int(seat.get("idx", 0))
		var slot: int = team * 2 + idx
		var peer: int = int(seat.get("peer", 0))
		if slot == 0 and peer == 1:
			continue
		var rd: Array = []
		for cid in seat.get("deck", []):
			rd.append(int(cid))
		if rd.is_empty():
			for cid in PlayerData.get_active_deck():
				rd.append(int(cid))
		var hand: Array = []
		for i in range(4):
			if rd.is_empty(): break
			hand.append(rd.pop_front())
		remote_players[slot] = {
			"team": team, "deck": rd, "hand": hand,
			"levels": Dictionary(seat.get("levels", {})).duplicate(true),
			"elixir": 5.0, "peer": peer, "ai": bool(seat.get("ai", true)) or peer == 0,
		}
		if not bool(remote_players[slot].ai):
			_ai_timers.erase(slot)
	_apply_network_party_decks()
	if remote_players.has(1):
		remote_hand = remote_players[1].hand.duplicate()
		remote_deck = remote_players[1].deck.duplicate()
		remote_levels = remote_players[1].levels.duplicate(true)
	for rk2 in remote_players.keys():
		var tm2: int = int(remote_players[rk2].team)
		remote_max_elixirs[rk2] = 20.0 if (team_size(tm2) == 1 and team_size(1 - tm2) >= 2) else 10.0
	player_elixir = 5.0
	enemy_elixir = 5.0
	network_countdown = 3.0
	if OS.get_environment("CR_NET_TEST_DEPLOY") != "":
		call_deferred("_network_test_deploy")
	if NetworkManager.guest_count() == 0:
		call_deferred("_start_host_no_guest")

func _apply_network_party_decks() -> void:
	var rule := String(NetworkManager.match_info.get("party_rule", "standard"))
	if rule == "standard" or rule == "":
		return
	var mode: Dictionary = BATTLE_MODES.get_by_id(rule)
	var deck_src := String(mode.get("deck", "custom"))
	for slot in remote_players.keys():
		var rp: Dictionary = remote_players[slot]
		var team: int = int(rp.get("team", Config.Team.ENEMY))
		var deck: Array = []
		if deck_src == "mirror":
			deck = _sanitize_mode_deck(mode_player_deck)
		elif deck_src == "classic":
			var classics: Array = BATTLE_MODES.classic_decks()
			deck = _sanitize_mode_deck(Array(classics[randi() % classics.size()]))
		elif deck_src == "draft" or deck_src == "swap_draft":
			var peer_id: int = int(rp.get("peer", 0))
			var submitted: Array = _sanitize_mode_deck(NetworkManager.network_draft_decks.get(peer_id, []))
			if submitted.size() >= 8:
				deck = submitted
			else:
				var picks: int = int(mode.get("draft_choices", 4))
				deck = _random_draft_deck(picks)
			if OS.get_environment("CR_MODE_DEBUG") != "":
				print("[DraftNet] remote slot=", slot, " peer=", peer_id, " deck=", str(deck))
		elif deck_src == "mega":
			deck = _build_mega_deck(team)
		else:
			deck = _sanitize_mode_deck(Array(rp.get("deck", [])))
			if deck.size() < 8:
				deck = _build_party_deck(team)
		if deck_src != "mega" and deck.size() < 8:
			var pool: Array = []
			for cfg in configs:
				if cfg.cost > 0 and cfg.card_id >= 4 and cfg.card_id != 123:
					pool.append(int(cfg.card_id))
			pool.shuffle()
			for cid in pool:
				if deck.size() >= 8:
					break
				if not deck.has(int(cid)):
					deck.append(int(cid))
		var hand: Array = []
		for i in range(4):
			if deck.is_empty():
				break
			hand.append(int(deck.pop_front()))
		rp["hand"] = hand
		rp["deck"] = deck
		rp["levels"] = Dictionary(rp.get("levels", {})).duplicate(true)
		remote_players[slot] = rp


func _network_test_deploy() -> void:
	await get_tree().create_timer(1.0).timeout
	if not remote_players.has(1) or remote_players[1].hand.is_empty():
		return
	var cid: int = int(remote_players[1].hand[0])
	var pos := Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5, 0.0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.22)
	var reason := network_remote_deploy_slot(1, cid, pos.x, pos.z)
	print("NET test deploy ", cid, " => ", reason, " units=", units.get_child_count())

func network_player_hands() -> Array:
	var host_hand: Array = []
	for card in player_hand:
		if card and card.config:
			host_hand.append(int(card.config.card_id))
	var out: Array = [host_hand]
	for k in range(1, 4):
		if remote_players.has(k):
			out.append(Array(remote_players[k].hand).duplicate())
		else:
			out.append([])
	return out

func network_player_elixirs() -> Array:
	var out: Array = [player_elixir]
	for k in range(1, 4):
		if remote_players.has(k):
			out.append(float(remote_players[k].elixir))
		else:
			out.append(0.0)
	return out

func network_player_max_elixirs() -> Array:
	var out: Array = [player_max_elixir]
	for k in range(1, 4):
		out.append(float(remote_max_elixirs.get(k, 10.0)))
	return out

func network_team_hand(team: int) -> Array:
	if team == 0:
		var h0: Array = []
		for card in player_hand:
			if card and card.config: h0.append(int(card.config.card_id))
		return h0
	for k in range(1, 4):
		if remote_players.has(k) and int(remote_players[k].team) == team:
			return Array(remote_players[k].hand).duplicate()
	return []

func network_guest_sync_hand(ids: Array) -> void:
	if is_dragging:
		return
	var cur: Array = []
	for card in player_hand:
		if card and card.config:
			cur.append(int(card.config.card_id))
	if cur == ids:
		return
	for card in player_hand:
		if card:
			card.queue_free()
	player_hand.clear()
	if hud and hud.card_container == null:
		return
	for i in range(ids.size()):
		var cfg = get_config(int(ids[i]))
		if cfg == null:
			continue
		var card_ui = CardUI.new()
		card_ui.setup(cfg, player_hand.size(), self)
		player_hand.append(card_ui)
		hud.card_container.add_child(card_ui)
		card_ui.gui_input.connect(_on_card_gui_input.bind(card_ui))

func network_remote_deploy_slot(slot: int, card_id: int, x: float, z: float) -> String:
	if not network_host_mode:
		return "非房主"
	if network_countdown > 0.0:
		return "准备中"
	if not remote_players.has(slot):
		return "玩家不存在"
	var rp: Dictionary = remote_players[slot]
	var team: int = int(rp.team)
	var cfg = get_config(card_id)
	if cfg == null:
		return "未知卡牌"
	if not Array(rp.hand).has(card_id):
		return "手牌中没有这张卡"
	var pos := Vector3(x, 0.0, z)
	var is_spell: bool = SPELL_IDS.has(card_id)
	if not is_spell and not is_valid_placement(cfg, pos, team):
		return "不能在当前位置部署"
	if float(rp.elixir) < float(card_cost(cfg)):
		return "圣水不足"
	if is_spell:
		deploy_spell(cfg, team, pos)
	else:
		var lv: int = int(Dictionary(rp.levels).get(str(card_id), PlayerData.get_card_level(card_id)))
		lv = mode_level(lv)
		if card_id == 109:
			_deploy_miner_tunnel(cfg, team, pos)
		elif card_id == 110:
			_deploy_log_like(cfg, team, pos)
		else:
			spawn_unit(cfg, team, pos, -1, lv)
	rp.elixir = float(rp.elixir) - float(card_cost(cfg))
	stats_elixir_spent[team] += card_cost(cfg)
	if match_replay_recorder and match_replay_recorder.has_method("record_action"):
		match_replay_recorder.record_action(team, card_id, pos)
	var h: Array = rp.hand
	h.erase(card_id)
	var d: Array = rp.deck
	d.append(card_id)
	if not d.is_empty():
		h.append(d.pop_front())
	rp["hand"] = h
	rp["deck"] = d
	remote_players[slot] = rp
	if slot == 1:
		remote_hand = Array(h).duplicate()
		remote_deck = Array(d).duplicate()
		enemy_elixir = float(rp.elixir)
	return ""

func network_remote_deploy(card_id: int, x: float, z: float) -> String:
	return network_remote_deploy_slot(1, card_id, x, z)

func _start_host_no_guest() -> void:
	network_wait_ready = false
	LoadingScreen.hide_loading()
	await play_entry_intro()
	_begin_network_countdown()

func _network_ready_timeout() -> void:
	await get_tree().create_timer(8.0).timeout
	if network_host_mode and network_wait_ready:
		network_wait_ready = false
		NetworkManager.send_entry_start()
		LoadingScreen.hide_loading()
		await play_entry_intro()
		_begin_network_countdown()

func _on_clients_ready() -> void:
	if not network_host_mode or not network_wait_ready:
		return
	network_wait_ready = false
	NetworkManager.send_entry_start()
	LoadingScreen.hide_loading()
	await play_entry_intro()
	_begin_network_countdown()

func _begin_network_countdown() -> void:
	network_countdown = 3.0
	NetworkManager.send_countdown(3.0)
	if _countdown_overlay and is_instance_valid(_countdown_overlay):
		_countdown_overlay.queue_free()
	_countdown_overlay = preload("res://scripts/ui/CountdownOverlay.gd").new()
	hud.add_child(_countdown_overlay)
	_countdown_overlay.start(3.0)

func play_entry_intro() -> void:
	entry_intro_active = true
	LoadingScreen.hide_loading()
	var cam = get_viewport().get_camera_3d()
	var base_size: float = 36.5
	if cam:
		base_size = cam.size
		hud.visible = false
		cam.size = base_size + 13.0
		var tw := create_tween()
		tw.tween_property(cam, "size", base_size, 1.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	if hud:
		hud.visible = true
		if tutorial_battle:
			var ov = preload("res://scripts/ui/TutorialBattleOverlay.gd").new()
			ov.battle = self
			hud.add_child(ov)
	entry_intro_active = false

func _process(delta):
	if entry_intro_active:
		return
	if network_host_mode and network_wait_ready:
		return
	if network_host_mode and network_countdown > 0.0:
		network_countdown = maxf(0.0, network_countdown - delta)
		if network_countdown > 0.0:
			return
	if touchdown_resetting and win_condition == "touchdown":
		# 2 秒回合间隙内除得分单位外保持清场（防止 AI/延迟生成）
		var extra: Array = []
		for u in units.get_children():
			if u is Unit and u != touchdown_scorer:
				extra.append(u)
		for u in extra:
			u.queue_free()
	if game_over:
		if win_condition == "duel" and not duel_finished:
			if not duel_transition:
				_duel_round_end()
			return
		if king_sequence or timeout_sequence:
			return
		if not hud.game_over_panel.visible:
			_show_game_over()
		return
	game_time += delta * 1000.0
	var now = game_time
	if not timeout_checked and now >= Config.GAME_TIME_LIMIT and not game_over:
		_check_timeout()
	if overtime and not game_over and not tower_bleed_active and not timeout_sequence:
		_update_overtime()
	if tower_bleed_active and not game_over and not timeout_sequence:
		_update_tower_bleed(delta)
	if win_condition == "touchdown" and not game_over and not touchdown_resetting and not timeout_sequence:
		_update_touchdown()
	_update_elixir(delta)
	_update_commando(delta)
	_update_network_ai(delta)
	_update_tutorial_enemy(delta)


# ============ 配置加载 ============
func load_card_configs():
	const P2M = 0.05  # 像素→米 系数
	# 优先从本地 11 级单位表读取（data/units_level11.csv，可直接编辑）
	if _try_load_unit_table():
		return

	configs = [
		_make_card("公主塔", 1, 0, 1, Config.UnitType.BUILDING, 3052, 109, 800, 7, 0, Config.TargetType.ALL, 0, 1, 7, 1.4, 0, [], [], 1, [], []),
		_make_card("王子塔", 2, 0, 1, Config.UnitType.BUILDING, 2616, 320, 2200, 7, 0, Config.TargetType.ALL, 0, 1, 7, 1.4, 0, [], [], 1, [], []),
		_make_card("国王塔", 3, 0, 1, Config.UnitType.BUILDING, 4824, 109, 1000, 6.5, 0, Config.TargetType.ALL, 0, 1, 6, 1.9, 0, [], [], 1, [], []),
		_make_card("骑士", 4, 3, 1, Config.UnitType.GROUND, 1766, 168, 1200, 0.4, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 2.5, 0.5, 0, [], [], 1, [], []),
		_make_card("骷髅军团", 5, 3, 15, Config.UnitType.GROUND, 81, 81, 1100, 0.25, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 2.5, 0.30000000000000004, 0, [], [], 1, [], []),
		_make_card("闪电法师", 6, 4, 1, Config.UnitType.GROUND, 714, 115, 1800, 4.5, 0, Config.TargetType.ALL, 1.2, 1, 5, 0.6666666666666667, 0, [190, 2, 2, 3, -1], [], 2, [2, 1], []),
		_make_card("法师", 7, 5, 1, Config.UnitType.GROUND, 755, 281, 1400, 5, 1.2000000000000002, Config.TargetType.ALL, 1.2, 1, 5.5, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("亡灵", 8, 3, 3, Config.UnitType.AIR, 230, 107, 1100, 2, 0, Config.TargetType.ALL, 1.6, 1, 3, 0.4, 0, [], [], 1, [], []),
		_make_card("巨人", 9, 5, 1, Config.UnitType.GROUND, 4090, 253, 1500, 0.4, 0, Config.TargetType.BUILDING_ONLY, 0.7, 0, 6, 1, 0, [], [], 1, [], []),
		_make_card("万箭齐发", 10, 3, 1, Config.UnitType.GROUND, 1, 366, 0, 3.5, 3.5, Config.TargetType.ALL, 0, 1, 0, 3.5, 0, [], [], 1, [], []),
		_make_card("火球", 11, 4, 1, Config.UnitType.GROUND, 1, 688, 0, 2.5, 2.5, Config.TargetType.ALL, 0, 0, 0, 2.5, 0, [], [], 1, [], []),
		_make_card("瓦基丽武神", 12, 4, 1, Config.UnitType.GROUND, 1907, 266, 1500, 0.4, 1.25, Config.TargetType.GROUND_ONLY, 1.1, 1, 3, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("迷你皮卡", 13, 4, 1, Config.UnitType.GROUND, 1433, 755, 1600, 0.25, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 3.5, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("飞龙宝宝", 14, 4, 1, Config.UnitType.AIR, 1152, 161, 1500, 3, 0.9, Config.TargetType.ALL, 1.2, 1, 3.5, 0.75, 0, [], [], 1, [], []),
		_make_card("皮卡超人", 15, 7, 1, Config.UnitType.GROUND, 3760, 816, 1800, 0.4, 0, Config.TargetType.GROUND_ONLY, 0.7, 1, 5, 0.9166666666666666, 0, [], [], 1, [], []),
		_make_card("王子", 16, 5, 1, Config.UnitType.GROUND, 1920, 391, 1400, 0.6000000000000001, 0, Config.TargetType.GROUND_ONLY, 1.2, 2, 3, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("野猪骑士", 17, 4, 1, Config.UnitType.GROUND, 1697, 317, 1600, 0.25, 0, Config.TargetType.BUILDING_ONLY, 1.6, 3, 6, 0.8333333333333335, 0, [], [], 1, [], []),
		_make_card("寒冰法师", 18, 3, 1, Config.UnitType.GROUND, 688, 89, 1700, 5, 0.8, Config.TargetType.ALL, 1.2, 1, 5, 0.5, 0, [84, 1.75, 3, 3, -1], [], 3, [], []),
		_make_card("女巫", 19, 5, 1, Config.UnitType.GROUND, 839, 135, 1100, 5, 0.8, Config.TargetType.ALL, 1.2, 1, 5.5, 0.8333333333333335, 0, [], [5, 4, 7000], 1, [], []),
		_make_card("电击法术", 20, 2, 1, Config.UnitType.GROUND, 1, 192, 0, 2.5, 2.5, Config.TargetType.ALL, 0, 0, 0, 2.5, 0, [], [], 2, [], []),
		_make_card("特斯拉电磁塔", 21, 4, 1, Config.UnitType.BUILDING, 1152, 220, 1100, 5, 0, Config.TargetType.ALL, 0, 1, 5, 0.8333333333333335, 0, [], [], 1, [], []),
		_make_card("蝙蝠", 22, 2, 5, Config.UnitType.AIR, 81, 81, 1300, 0.4, 0, Config.TargetType.ALL, 1.6, 1, 3.5, 0.25, 0, [], [], 1, [], []),
		_make_card("黑暗王子", 23, 4, 1, Config.UnitType.GROUND, 1200, 266, 1300, 0.4, 1, Config.TargetType.GROUND_ONLY, 1.2, 2, 3.5, 0.75, 240, [], [], 1, [], []),
		_make_card("骷髅墓碑", 24, 3, 1, Config.UnitType.BUILDING, 529, 0, 0, 0, 0, Config.TargetType.ALL, 0, 1, 2.5, 0.75, 0, [], [5, 1, 4000], 1, [], []),
		_make_card("气球兵", 25, 5, 1, Config.UnitType.AIR, 1679, 640, 2000, 0, 0, Config.TargetType.BUILDING_ONLY, 0.8, 1, 6, 1, 0, [220, 1.2, 1, 3, 2000], [], 1, [], []),
		_make_card("炸弹塔", 26, 4, 1, Config.UnitType.BUILDING, 1356, 222, 1800, 5.5, 1.3, Config.TargetType.GROUND_ONLY, 0, 1, 4.5, 0.8333333333333335, 0, [222, 1.2, 1, 3, 2000], [], 1, [], []),
		_make_card("地狱飞龙", 27, 4, 1, Config.UnitType.AIR, 1295, 35, 400, 3, 0, Config.TargetType.ALL, 1.2, 1, 4, 0.75, 0, [], [], 4, [], []),
		_make_card("电磁炮", 28, 6, 1, Config.UnitType.GROUND, 1451, 1331, 4000, 4.5, 1.4000000000000001, Config.TargetType.GROUND_ONLY, 0.8, 1, 5, 0.8333333333333335, 0, [], [], 5, [], []),
		_make_card("野蛮人精锐", 29, 6, 2, Config.UnitType.GROUND, 1341, 384, 1400, 0.6000000000000001, 0, Config.TargetType.GROUND_ONLY, 1.5, 1, 3.5, 0.75, 0, [], [], 1, [], []),
		_make_card("戈仑冰人", 30, 2, 1, Config.UnitType.GROUND, 1315, 84, 2500, 0.25, 0, Config.TargetType.BUILDING_ONLY, 0.7, 1, 2.5, 0.8333333333333335, 0, [84, 1.3, 3, 3, 100], [], 3, [], []),
		_make_card("大雪球", 31, 2, 1, Config.UnitType.GROUND, 1, 179, 0, 2.5, 2.5, Config.TargetType.ALL, 0, 1, 0, 2.5, 0, [], [], 3, [], []),
		_make_card("吹箭哥布林", 32, 3, 1, Config.UnitType.GROUND, 261, 156, 800, 6, 0, Config.TargetType.ALL, 1.6, 1, 6.5, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("地狱之塔", 33, 5, 1, Config.UnitType.BUILDING, 1748, 43, 400, 5.5, 0, Config.TargetType.ALL, 0, 1, 5.5, 1, 0, [], [], 4, [], []),
		_make_card("皇家巨人", 34, 6, 1, Config.UnitType.GROUND, 3164, 307, 1700, 4.5, 0, Config.TargetType.BUILDING_ONLY, 0.7, 1, 5, 1.3333333333333335, 0, [], [], 1, [], []),
		_make_card("冰雪精灵", 35, 1, 1, Config.UnitType.GROUND, 230, 110, 1300, 2, 1.2000000000000002, Config.TargetType.ALL, 2, 1, 2.5, 0.6666666666666667, -1, [], [], 3, [], []),
		_make_card("雷电飞龙", 36, 5, 1, Config.UnitType.AIR, 943, 192, 2100, 3, 0, Config.TargetType.ALL, 1.1, 1, 5, 0.8333333333333335, 0, [], [], 2, [3, 2], []),
		_make_card("暗夜女巫", 37, 4, 1, Config.UnitType.GROUND, 906, 314, 1300, 0.75, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 2.5, 0.8333333333333335, 0, [], [22, 2, 5000], 1, [], []),
		_make_card("皇家野猪", 38, 5, 4, Config.UnitType.GROUND, 837, 74, 1200, 0.25, 0, Config.TargetType.BUILDING_ONLY, 1.6, 3, 6, 0.8333333333333335, 0, [], [], 1, [], []),
		_make_card("哥布林", 39, 2, 4, Config.UnitType.GROUND, 202, 120, 1100, 0.25, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 2, 0.5, 0, [], [], 1, [], []),
		_make_card("哥布林飞桶", 40, 3, 1, Config.UnitType.GROUND, 1, 0, 0, 1.5, 1.5, Config.TargetType.GROUND_ONLY, 0, 0, 0, 0.6666666666666667, 0, [], [39, 3, 0], 1, [], []),
		_make_card("骷髅巨人", 41, 6, 1, Config.UnitType.GROUND, 3617, 276, 1300, 0.25, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 2.5, 1.1666666666666667, 0, [535, 1.5, 1, 3, 3000], [], 1, [], []),
		_make_card("攻城炸弹人", 42, 2, 2, Config.UnitType.GROUND, 330, 1, 500, 0.25, 2, Config.TargetType.BUILDING_ONLY, 2.1, 1, 6, 0.5833333333333334, -1, [350, 2, 1, 3, 0], [], 1, [], []),
		_make_card("烟花炮手", 43, 3, 1, Config.UnitType.GROUND, 304, 64, 3000, 6, 1.4000000000000001, Config.TargetType.ALL, 1.6, 1, 6.5, 0.5833333333333334, 0, [], [], 1, [], [15, 5, 20, 2, 1]),
		_make_card("弓箭手", 44, 3, 2, Config.UnitType.GROUND, 304, 112, 900, 5.5, 0, Config.TargetType.ALL, 1.1, 1, 6.5, 0.5833333333333334, 0, [], [], 1, [], []),
		_make_card("雷电精灵", 45, 1, 1, Config.UnitType.GROUND, 230, 99, 1300, 2.5, 0, Config.TargetType.ALL, 2, 1, 2.5, 0.6666666666666667, -1, [], [], 2, [9, 2], []),
		_make_card("治疗精灵", 46, 1, 1, Config.UnitType.GROUND, 230, 110, 1300, 2.5, 0, Config.TargetType.ALL, 2, 1, 3.5, 0.6666666666666667, -1, [400, 2.5, 8, 3, 100], [], 8, [], []),
		_make_card("战斗天使", 47, 4, 1, Config.UnitType.GROUND, 1717, 148, 1500, 0.75, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 3, 0.75, 0, [120, 2.5, 8, 3, 0], [], 1, [], []),
		_make_card("雷电法术", 48, 6, 1, Config.UnitType.GROUND, 1, 1057, 0, 3.5, 3.5, Config.TargetType.ALL, 0, 0, 0, 3.5, 0, [], [], 2, [3, 3], []),
		_make_card("野蛮人小屋", 49, 6, 1, Config.UnitType.BUILDING, 1164, 0, 0, 0, 0, Config.TargetType.ALL, 0, 1, 0, 1, 0, [], [57, 3, 15000], 1, [], []),
		_make_card("烈焰精灵", 50, 1, 1, Config.UnitType.GROUND, 230, 207, 1300, 2.5, 2, Config.TargetType.ALL, 2, 1, 3.5, 0.5, -1, [], [], 1, [], []),
		_make_card("烈焰熔炉", 51, 4, 1, Config.UnitType.GROUND, 727, 179, 1700, 5.5, 0, Config.TargetType.ALL, 1.2, 1, 6.5, 0.75, 0, [], [50, 1, 7000], 1, [], []),
		_make_card("神箭游侠", 52, 4, 1, Config.UnitType.GROUND, 529, 143, 1100, 6, 0.5, Config.TargetType.ALL, 1.2, 1, 7.5, 0.75, 0, [], [], 1, [], [0, 1, 100, 11, 2]),
		_make_card("皇家速递", 53, 3, 1, Config.UnitType.GROUND, 537, 133, 1300, 0.75, 0, Config.TargetType.GROUND_ONLY, 1.1, 1, 3, 0.6666666666666667, 240, [437, 3, 1, 3, -2000], [], 1, [], []),
		_make_card("飞行机器", 54, 4, 1, Config.UnitType.AIR, 614, 171, 1100, 5.5, 0, Config.TargetType.ALL, 1.2, 1, 6.5, 0.8333333333333335, 0, [], [], 1, [], []),
		_make_card("十字连弩", 55, 6, 1, Config.UnitType.BUILDING, 1600, 43, 300, 11, 0, Config.TargetType.GROUND_ONLY, 0, 1, 11, 1, 0, [], [], 1, [], []),
		_make_card("猎人", 56, 4, 1, Config.UnitType.GROUND, 885, 84, 2200, 4, 1.25, Config.TargetType.ALL, 1.2, 1, 5, 0.8333333333333335, 0, [], [], 1, [], [5, 10, 40, 6.5, 3]),
		_make_card("野蛮人", 57, 5, 5, Config.UnitType.GROUND, 737, 192, 1300, 0.25, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 2.5, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("亡灵大军", 58, 5, 6, Config.UnitType.AIR, 230, 107, 1200, 2.5, 0, Config.TargetType.ALL, 1.6, 1, 3, 0.4, 0, [], [], 1, [], []),
		_make_card("重甲亡灵", 59, 3, 1, Config.UnitType.AIR, 837, 312, 1500, 0.8, 0, Config.TargetType.ALL, 1.2, 1, 2, 0.5, 0, [], [], 1, [], []),
		_make_card("电击车小队", 60, 4, 3, Config.UnitType.GROUND, 529, 117, 2100, 4.5, 0, Config.TargetType.ALL, 1.2, 1, 5, 0.5, 0, [], [], 2, [], []),
		_make_card("加农炮", 61, 3, 1, Config.UnitType.BUILDING, 824, 202, 1000, 5.5, 0, Config.TargetType.GROUND_ONLY, 0, 1, 5.5, 0.75, 0, [], [], 1, [], []),
		_make_card("哥布林投矛手", 62, 2, 3, Config.UnitType.GROUND, 133, 81, 1700, 5, 0, Config.TargetType.ALL, 2, 1, 5.5, 0.41666666666666674, 0, [], [], 1, [], []),
		_make_card("哥布林小屋", 63, 5, 1, Config.UnitType.BUILDING, 1228, 1, 2200, 6, 0, Config.TargetType.ALL, 0, 1, 6, 0.75, 0, [], [62, 1, 100000], 1, [], []),
		_make_card("骷髅气球", 64, 3, 1, Config.UnitType.AIR, 532, 145, 0, 0.5, 0.9, Config.TargetType.BUILDING_ONLY, 1.6, 1, 5, 0.8333333333333335, -1, [], [5, 7, 100000], 1, [], []),
		_make_card("骷髅守卫", 65, 3, 3, Config.UnitType.GROUND, 81, 117, 1000, 0.7000000000000001, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 2.5, 0.33333333333333337, 256, [], [], 1, [], []),
		_make_card("骷髅飞龙", 66, 4, 2, Config.UnitType.AIR, 560, 161, 2000, 3.5, 1.25, Config.TargetType.ALL, 1.6, 1, 4, 0.5, 0, [], [], 1, [], []),
		_make_card("公主", 67, 3, 1, Config.UnitType.GROUND, 261, 168, 3000, 9, 1.4, Config.TargetType.ALL, 1.2, 1, 10, 0.5, 0, [], [], 1, [], []),
		_make_card("炸弹兵", 68, 2, 1, Config.UnitType.GROUND, 304, 225, 1800, 4.5, 1.3, Config.TargetType.GROUND_ONLY, 1.2, 1, 5, 0.33333333333333337, 0, [], [], 1, [], []),
		_make_card("野蛮人攻城槌", 69, 4, 1, Config.UnitType.GROUND, 967, 286, 100, 0.6, 0, Config.TargetType.BUILDING_ONLY, 1.2, 2, 5, 0.8333333333333335, -1, [], [57, 2, 100000], 1, [], []),
		_make_card("掘地矿工", 70, 3, 1, Config.UnitType.GROUND, 1210, 194, 1300, 0.5, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 3.5, 0.5, 0, [], [], 1, [], []),
		_make_card("火枪手", 71, 4, 1, Config.UnitType.GROUND, 721, 217, 1000, 6, 0, Config.TargetType.ALL, 1.2, 1, 6.5, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("迫击炮", 72, 4, 1, Config.UnitType.BUILDING, 1369, 266, 5000, 11.5, 1, Config.TargetType.GROUND_ONLY, 0, 1, 11.5, 0.75, 0, [], [], 1, [], []),
		_make_card("精灵女王", 73, 6, 1, Config.UnitType.AIR, 1177, 309, 1400, 5, 0, Config.TargetType.ALL, 1.2, 1, 3, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("皇家卫队", 74, 7, 6, Config.UnitType.GROUND, 537, 133, 1300, 0.75, 0, Config.TargetType.GROUND_ONLY, 1.1, 1, 3, 0.6666666666666667, 240, [], [], 1, [], []),
		_make_card("狂战士", 75, 2, 1, Config.UnitType.GROUND, 896, 102, 600, 1, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 2, 0.33333333333333337, 0, [], [], 1, [], []),
		_make_card("三个火枪手", 76, 9, 3, Config.UnitType.GROUND, 883, 204, 1300, 6, 0, Config.TargetType.ALL, 1.2, 1, 6.5, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("火箭", 77, 6, 1, Config.UnitType.GROUND, 1, 1484, 0, 2, 2, Config.TargetType.ALL, 0, 1, 0, 2, 0, [], [], 1, [], []),
		_make_card("狂暴法术", 78, 2, 1, Config.UnitType.GROUND, 1, 179, 4500, 3, 3, Config.TargetType.ALL, 1.6, 1, 3, 0.4, 0, [], [], 9, [], []),
		_make_card("狂暴樵夫", 79, 4, 1, Config.UnitType.GROUND, 1282, 256, 800, 0.8, 0, Config.TargetType.GROUND_ONLY, 2, 1, 2, 0.5, 0, [], [], 1, [], []),
		_make_card("冰冻法术", 80, 4, 1, Config.UnitType.GROUND, 1, 148, 0, 3, 3, Config.TargetType.ALL, 1.2, 1, 5, 0.5, 0, [], [], 10, [], []),
		_make_card("幻影刺客", 81, 3, 1, Config.UnitType.GROUND, 906, 194, 1000, 0.4, 0, Config.TargetType.GROUND_ONLY, 1.6, 6, 5.5, 0.75, 0, [], [], 1, [], []),
		_make_card("熔岩猎犬", 82, 7, 1, Config.UnitType.AIR, 3581, 53, 1300, 3.5, 0, Config.TargetType.BUILDING_ONLY, 0.8, 1, 5.5, 0.41666666666666674, 0, [], [101, 6, 100000], 1, [], []),
		_make_card("超级骑士", 83, 7, 1, Config.UnitType.GROUND, 3993, 268, 1700, 0.7000000000000001, 1.2, Config.TargetType.GROUND_ONLY, 1.2, 5, 6, 0.8333333333333335, 0, [537, 1.4, 1, 2, -1], [], 1, [], []),
		_make_card("哥布林机甲", 84, 5, 1, Config.UnitType.GROUND, 2150, 212, 1200, 0.6000000000000001, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 3, 0.8333333333333335, 0, [], [99, 1, -1], 1, [], []),
		_make_card("骷髅召唤", 85, 5, 1, Config.UnitType.GROUND, 1, 0, 7000, 4, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 2.5, 0.33333333333333337, 0, [], [], 1, [], []),
		_make_card("蛮羊骑士", 86, 5, 1, Config.UnitType.GROUND, 1697, 250, 1800, 0.4, 0, Config.TargetType.BUILDING_ONLY, 1.2, 2, 6, 0.5, 0, [], [98, 1, -1], 1, [], []),
		_make_card("女巫婆婆", 87, 4, 1, Config.UnitType.GROUND, 529, 133, 1000, 5.5, 0, Config.TargetType.ALL, 1.2, 1, 6, 0.5, 0, [], [], 7, [], []),
		_make_card("凤凰", 88, 4, 1, Config.UnitType.AIR, 1052, 217, 1000, 0.8, 0, Config.TargetType.ALL, 1.2, 1, 5, 0.33333333333333337, 0, [163, 1.2, 1, 3, 100], [102, 1, 100000], 1, [], []),
		_make_card("渔夫", 89, 3, 1, Config.UnitType.GROUND, 870, 194, 1300, 0.6, 0, Config.TargetType.GROUND_ONLY, 1.2, 7, 5, 0.8333333333333335, 0, [], [], 1, [], []),
		_make_card("皇家幽灵", 90, 3, 1, Config.UnitType.GROUND, 1210, 261, 1800, 0.6000000000000001, 0.7000000000000001, Config.TargetType.GROUND_ONLY, 1.6, 1, 3.5, 0.5, 0, [], [], 1, [], []),
		_make_card("滚木", 91, 2, 1, Config.UnitType.GROUND, 1, 268, 800, 10.100000000000001, 3.9, Config.TargetType.GROUND_ONLY, 1.2, 1, 5, 0.6666666666666667, 0, [], [], 1, [], [0, 1, 20, 10.1, 5]),
		_make_card("戈仑石人", 92, 8, 1, Config.UnitType.GROUND, 5120, 312, 2500, 0.4, 1, Config.TargetType.BUILDING_ONLY, 0.8, 1, 5, 0.75, 0, [225, 1.7, 1, 3, 100], [100, 2, 100000], 1, [], []),
		_make_card("雷电巨人", 93, 7, 1, Config.UnitType.GROUND, 3855, 162, 2100, 0.6000000000000001, 0, Config.TargetType.BUILDING_ONLY, 1.2, 1, 3, 1, 0, [], [], 1, [], []),
		_make_card("哥布林巨人", 94, 6, 1, Config.UnitType.GROUND, 3020, 176, 1500, 0.4, 0, Config.TargetType.BUILDING_ONLY, 1.1, 1, 6, 0.6666666666666667, 0, [], [62, 2, -1], 1, [], []),
		_make_card("加农炮战车", 95, 5, 1, Config.UnitType.GROUND, 1809, 212, 900, 5.5, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 6, 0.6666666666666667, 0, [], [], 1, [], []),
		_make_card("飞斧屠夫", 96, 5, 1, Config.UnitType.GROUND, 1280, 179, 2400, 4.5, 1.5, Config.TargetType.ALL, 1.2, 1, 5.5, 0.6666666666666667, 0, [], [], 1, [], [0, 1, 80, 7.5, 4]),
		_make_card("巨石投手", 97, 5, 1, Config.UnitType.GROUND, 2081, 289, 2500, 4, 1, Config.TargetType.GROUND_ONLY, 0.8, 1, 5, 1, 0, [], [], 1, [], [0, 1, 20, 7.5, 5]),
		_make_card("羊骑士", 98, 0, 1, Config.UnitType.GROUND, 0, 104, 1100, 5.5, 0, Config.TargetType.ALL, 86, 4, 5.5, 0.33333333333333337, 0, [], [], 6, [], []),
		_make_card("炸药桶", 99, 0, 1, Config.UnitType.GROUND, 0, 304, 3500, 3.75, 1, Config.TargetType.ALL, 84, 4, 5, 0.30000000000000004, 0, [], [], 1, [], []),
		_make_card("小戈仑石人", 100, 0, 1, Config.UnitType.GROUND, 1039, 84, 2500, 0.4, 0, Config.TargetType.BUILDING_ONLY, 0.8, 1, 5.5, 0.33333333333333337, 0, [99, 1.2, 1, 3, 100], [], 1, [], []),
		_make_card("熔岩幼犬", 101, 0, 1, Config.UnitType.AIR, 215, 81, 1700, 0.8, 0, Config.TargetType.ALL, 1.2, 1, 2.5, 0.33333333333333337, 0, [], [], 1, [], []),
		_make_card("凤凰蛋", 102, 0, 1, Config.UnitType.GROUND, 317, 0, 3800, 0, 0, Config.TargetType.ALL, 0, 1, 50, 0.33333333333333337, 0, [], [88, 1, 7300], 1, [], []),
		_make_card("小猪", 103, 0, 1, Config.UnitType.GROUND, 629, 53, 1200, 0.4, 0, Config.TargetType.BUILDING_ONLY, 2, 1, 5, 0.33333333333333337, 0, [], [], 1, [], []),
		_make_card("飓风法术", 104, 3, 1, Config.UnitType.GROUND, 1, 84, 0, 2.5, 5.5, Config.TargetType.ALL, 0, 1, 2.5, 5.5, 0, [], [], 1, [], []),
		_make_card("哥布林爆破手", 105, 4, 1, Config.UnitType.GROUND, 1300, 186, 1100, 5, 1.3, Config.TargetType.GROUND_ONLY, 1.3, 1, 5.5, 1, 0, [], [], 1, [], []),
		_make_card("圣水戈仑", 106, 3, 1, Config.UnitType.GROUND, 1569, 253, 1100, 0.5, 0, Config.TargetType.BUILDING_ONLY, 0.9, 1, 6, 1.2, 0, [], [124, 2, 100000], 1, [], []),
		_make_card("毒药法术", 107, 4, 1, Config.UnitType.GROUND, 1, 92, 8000, 3.5, 3.5, Config.TargetType.ALL, 0, 1, 3.5, 3.5, 0, [], [], 7, [], []),
		_make_card("可疑草丛", 108, 2, 1, Config.UnitType.GROUND, 81, 0, 0, 0, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 6, 0.8, 0, [], [126, 2, 100000], 1, [], []),
		_make_card("哥布林钻机", 109, 4, 1, Config.UnitType.BUILDING, 1313, 0, 0, 0, 0, Config.TargetType.ALL, 0, 1, 0, 1, 0, [], [39, 1, 3000], 1, [], []),
		_make_card("野蛮人滚桶", 110, 2, 1, Config.UnitType.GROUND, 1, 215, 0, 2.6, 2.6, Config.TargetType.GROUND_ONLY, 0, 1, 2.6, 2.6, 0, [], [], 1, [], []),
		_make_card("符文巨人", 111, 4, 1, Config.UnitType.GROUND, 2816, 153, 1500, 0.8, 0, Config.TargetType.BUILDING_ONLY, 1, 1, 6, 1.2, 0, [], [], 1, [], []),
		_make_card("藤蔓法术", 112, 3, 1, Config.UnitType.GROUND, 1, 153, 2000, 2.5, 2.5, Config.TargetType.ALL, 0, 1, 2.5, 2.5, 0, [], [], 2, [], []),
		_make_card("虚空法术", 113, 5, 1, Config.UnitType.GROUND, 1, 696, 3000, 2, 2, Config.TargetType.ALL, 0, 1, 2, 2, 0, [], [], 1, [], []),
		_make_card("哥布林牢笼", 114, 4, 1, Config.UnitType.BUILDING, 780, 0, 0, 0, 0, Config.TargetType.BUILDING_ONLY, 0, 1, 0, 1, 0, [], [127, 1, 100000], 1, [], []),
		_make_card("地震法术", 115, 3, 1, Config.UnitType.GROUND, 1, 81, 3000, 3.5, 3.5, Config.TargetType.GROUND_ONLY, 0, 1, 3.5, 3.5, 0, [], [], 1, [], []),
		_make_card("哥布林魔咒", 116, 2, 1, Config.UnitType.GROUND, 1, 35, 6000, 3, 3, Config.TargetType.ALL, 0, 1, 3, 3, 0, [], [], 7, [], []),
		_make_card("绿林团伙", 117, 5, 1, Config.UnitType.GROUND, 1832, 217, 1500, 0.5, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 6, 1, 0, [], [118, 2, -1], 1, [], []),
		_make_card("绿林小妹", 118, 0, 1, Config.UnitType.GROUND, 261, 125, 1000, 5, 0, Config.TargetType.ALL, 1.2, 1, 5.5, 1, 0, [], [], 1, [], []),
		_make_card("骷髅兵", 119, 1, 3, Config.UnitType.GROUND, 81, 81, 1100, 0.25, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 2, 0.3, 0, [], [], 1, [], []),
		_make_card("圣水收集器", 120, 6, 1, Config.UnitType.BUILDING, 1070, 0, 0, 0, 0, Config.TargetType.ALL, 0, 1, 0, 0.75, 0, [], [], 1, [], []),
		_make_card("哥布林团伙", 121, 3, 1, Config.UnitType.GROUND, 1, 0, 0, 0, 0, Config.TargetType.ALL, 0, 1, 0, 0.3, 0, [], [], 1, [], []),
		_make_card("克隆法术", 122, 3, 1, Config.UnitType.GROUND, 1, 0, 0, 3, 3, Config.TargetType.ALL, 0, 1, 3, 3, 0, [], [], 1, [], []),
		_make_card("镜像法术", 123, 0, 1, Config.UnitType.GROUND, 1, 0, 0, 3, 3, Config.TargetType.ALL, 0, 1, 3, 3, 0, [], [], 1, [], []),
		_make_card("圣水小戈仑", 124, 0, 1, Config.UnitType.GROUND, 762, 128, 1100, 0.5, 0, Config.TargetType.BUILDING_ONLY, 1.2, 1, 4.5, 0.8, 0, [], [125, 2, 100000], 1, [], []),
		_make_card("圣水泡泡", 125, 0, 1, Config.UnitType.GROUND, 360, 64, 1100, 0.5, 0, Config.TargetType.BUILDING_ONLY, 1.5, 1, 3, 0.4, 0, [], [], 1, [], []),
		_make_card("草丛哥布林", 126, 0, 1, Config.UnitType.GROUND, 337, 256, 1400, 0.5, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 4, 0.5, 0, [], [], 1, [], []),
		_make_card("哥布林硬汉", 127, 0, 1, Config.UnitType.GROUND, 1121, 337, 1100, 0.5, 0, Config.TargetType.GROUND_ONLY, 1.5, 1, 5, 0.7, 0, [], [], 1, [], []),
		_make_card("亡灵巨人", 128, 4, 1, Config.UnitType.AIR, 1817, 153, 1700, 4, 0, Config.TargetType.BUILDING_ONLY, 1.2, 1, 6, 0.8, 0, [], [], 1, [], []),
		_make_card("浪人", 129, 5, 1, Config.UnitType.GROUND, 1779, 285, 1300, 0.8, 0, Config.TargetType.GROUND_ONLY, 1.5, 1, 5, 0.8, 0, [], [], 1, [], []),
	]	
	


func _make_card(
	name: String, id: int, cost: int, num: int, type: int,
	max_health: float, damage: float, attack_speed: int,
	attack_range: float, damage_range: float,
	target_type: int, move_speed: float, move_type: int,
	horizon: float, size: float,  # size 已经是碰撞半径(米)
	shield: float = 0,
	extra_spell: Array = [],
	spawn_unit: Array = [],
	attack_type: int = 1,
	multiple_targets: Array = [],
	multiple_process: Array = []
) -> CardData:
	var c = CardData.new()
	c.card_name = name
	c.card_id = id
	c.cost = cost
	c.num = num
	c.type = type
	c.max_health = max_health
	c.damage = damage
	c.attack_speed = attack_speed
	c.attack_range = attack_range
	c.damage_range = damage_range
	c.target_type = target_type
	c.move_speed = move_speed*24
	c.move_type = move_type
	c.horizon = horizon
	c.size = size
	c.shield = shield
	c.extra_spell = extra_spell
	c.spawn_unit = spawn_unit
	c.attack_type = attack_type
	c.multiple_targets = multiple_targets
	c.multiple_process = multiple_process
	return c
func card_cost(cfg: CardData) -> int:
	if cfg == null:
		return 0
	if cfg.card_id == 123:
		if last_played_card_id < 0:
			return 999
		var lc = get_config(last_played_card_id)
		return int(lc.cost) + 1 if lc else 999
	return cfg.cost

func get_config(card_id: int) -> CardData:
	for cfg in configs:
		if cfg.card_id == card_id:
			return cfg
	return null

# ============ 初始建筑 ============
func _network_tower_data() -> Array:
	var out: Array = []
	var lv: int = PlayerData.get_tower_level()
	for team in [0, 1]:
		var seats_t: Array = []
		for s in NetworkManager.match_info.get("seats", []):
			if int(s.get("team", 0)) == team:
				seats_t.append(s)
		seats_t.sort_custom(func(a, b): return int(a.idx) < int(b.idx))
		var t0: int = int(seats_t[0].get("tower_choice", 1)) if seats_t.size() > 0 else 1
		var t1: int = int(seats_t[1].get("tower_choice", 1)) if seats_t.size() > 1 else t0
		if t0 not in [1, 2]: t0 = 1
		if t1 not in [1, 2]: t1 = 1
		var left_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0
		var right_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0
		var mid_x: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 9.0 / 18.0
		var pr_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (25.5 / 32.0 if team == 0 else 6.5 / 32.0)
		var king_z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * (29.0 / 32.0 if team == 0 else 3.0 / 32.0)
		out.append([0, t0, team, Vector3(left_x, 0, pr_z)])
		out.append([1, t1, team, Vector3(right_x, 0, pr_z)])
		out.append([2, 3, team, Vector3(mid_x, 0, king_z)])
	return out

func _spawn_tutorial_targets() -> void:
	var archer := get_config(44)
	if archer == null:
		return
	var cx: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
	var z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.30
	for i in range(3):
		var pos := Vector3(cx + (float(i) - 1.0) * 2.2, 0.0, z + absf(float(i) - 1.0) * 0.8)
		spawn_unit(archer, Config.Team.ENEMY, pos, 1, PlayerData.ai_level(44))
	var knight := get_config(4)
	if knight:
		spawn_unit(knight, Config.Team.ENEMY, Vector3(cx, 0.0, z - 1.8), 1, PlayerData.ai_level(4))

func _record_tutorial_card(card_id: int) -> void:
	if tutorial_battle and not tutorial_played.has(card_id):
		tutorial_played.append(card_id)

func spawn_initial_towers():
	if win_condition == "touchdown" or String(battle_mode.get("win_condition", "")) == "touchdown":
		return
	if replay_skip_towers:
		return
	if replay_mode and replay_towers.size() >= 6:
		for tw in replay_towers:
			var cfg = get_config(int(tw.get("card_id", 1)))
			if cfg == null: continue
			var team_t: int = int(tw.get("team", 0))
			var cx: float = float(tw.get("x", 0.0))
			var slot: int = 2 if int(cfg.card_id) == 3 else (0 if cx < Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5 else 1)
			var pos := Vector3(cx, 0.0, float(tw.get("z", 0.0)))
			var unit = spawn_unit(cfg, team_t, pos, -1, int(tw.get("level", PlayerData.get_tower_level())))
			if unit:
				var idx: int = slot if team_t == Config.Team.PLAYER else 3 + slot
				unit.id = idx
				healths[idx] = unit.health
				if idx >= Unit._next_id:
					Unit._next_id = idx + 1
		return
	var player_type: int = PlayerData.tower_choice
	if player_type not in [1, 2]:
		player_type = 1
	var enemy_type: int = 1 if randi() % 2 == 0 else 2
	var king_level: int = 11 if (party_mode or fixed_level_override > 0 or PlayerData.test_mode) else PlayerData.get_tower_level()
	var tower_data = []
	if network_host_mode:
		tower_data = _network_tower_data()
	else:
		tower_data = [
		# [槽位, 塔类型, 队伍, 位置]
		[0, player_type, Config.Team.PLAYER, Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5/18, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 25.5 / 32.0)],
		[1, player_type, Config.Team.PLAYER, Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5/18, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 25.5 / 32.0)],
		[2, 3, Config.Team.PLAYER, Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 9/18, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 29 / 32.0)],
		[0, enemy_type, Config.Team.ENEMY, Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5/18, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 6.5 / 32.0)],
		[1, enemy_type, Config.Team.ENEMY, Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5/18, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 6.5 / 32.0)],
		[2, 3, Config.Team.ENEMY, Vector3(Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 9/18, 0, Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 3 / 32.0)],
	]
	if win_condition == "touchdown":
		# 冲线模式没有任何皇家塔
		tower_data = []
	for data in tower_data:
		var slot: int = int(data[0])
		var type: int = int(data[1])
		var team: int = int(data[2])
		var pos: Vector3 = data[3]
		var cfg = get_config(type)
		if cfg == null:
			continue
		if tutorial_battle and team == Config.Team.ENEMY and (type == 1 or type == 2):
			var tut_cfg = cfg.duplicate()
			tut_cfg.max_health = float(cfg.max_health) * 0.45
			tut_cfg.damage = float(cfg.damage) * 0.55
			cfg = tut_cfg
		if type == 3 and network_host_mode and String(NetworkManager.room_mode) != "1v1":
			var cfg2 = cfg.duplicate()
			cfg2.max_health = float(cfg.max_health) * 1.5
			cfg2.damage = float(cfg.damage) * 1.5
			cfg = cfg2
		var unit = spawn_unit(cfg, team, pos, -1, king_level)
		if unit:
			if type == 3 and team_size(team) >= 2:
				unit.king_duo = true
				unit.apply_king_duo_visual()
			var idx: int = slot if team == Config.Team.PLAYER else 3 + slot
			unit.id = idx
			healths[idx] = unit.health
			if idx >= Unit._next_id:
				Unit._next_id = idx + 1

func _get_tower_index(team: int, slot: int) -> int:
	return slot if team == Config.Team.PLAYER else 3 + slot

func spawn_unit(config: CardData, team: int, pos: Vector3, override_num: int = -1,level: int = 0,follow=null,ignore_clamp: bool = false, replay_visual: bool = false) -> Unit:
	
	var count = override_num if override_num >= 0 else config.num
	var first_unit: Unit = null
	for i in range(count):
		var unit = Unit.new()
		var offset
		unit.config = config
		unit.team = team
		unit.level = level
		unit.ignore_level_clamp = ignore_clamp
		unit.replay_visual = replay_visual
		if follow:
			unit.follow = follow
		if count > 1:
			if config.card_id == 74:
				var base_x = (i / float(count)) * Config.ARENA_WIDTH + Config.ARENA_ORIGIN.x
				unit.position = Vector3(base_x, pos.y, pos.z)
				
			else:
				var angle = (i / float(count)) * 2.0 * PI
				if config.type == Config.UnitType.AIR:
					offset = Vector3(cos(angle), 3.0, sin(angle)) * 0.6
				else:
					offset = Vector3(cos(angle), config.size, sin(angle)) * 0.6
				unit.position = pos + offset
			
			
		else:
			unit.position = pos
		
		units.add_child(unit)
		_spawn_effect(unit.global_position)
		if i == 0:
			first_unit = unit
	if first_unit:
		pass
	var deploy_sfx = load("res://assets/audio/sfx/deploy.wav")
	if deploy_sfx:
		AudioManager.play_sfx(deploy_sfx, first_unit.global_position)
	return first_unit
func _spawn_effect(pos: Vector3):
	# 简单白色闪烁粒子（使用 GpuParticles3D 或临时球体）
	for i in range(8):
		var spark = MeshInstance3D.new()
		spark.mesh = SphereMesh.new()
		spark.mesh.radius = 0.15
		spark.mesh.height = 0.3
		spark.material_override = StandardMaterial3D.new()
		spark.material_override.albedo_color = Color.WHITE
		spark.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.position = pos + Vector3(randf_range(-0.5,0.5), randf_range(0,0.5), randf_range(-0.5,0.5))
		add_child(spark)
		# 0.3秒后消失
		var tween = create_tween()
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.3)
		tween.tween_callback(spark.queue_free)
	

# ============ 圣水系统 ============
func _update_elixir(delta):
	if touchdown_resetting and win_condition == "touchdown":
		return
	var now = Time.get_ticks_msec() - start_time
	if mode_elixir_rate != 1.0:
		elixir_rate = mode_elixir_rate
	elif now >= 240000:
		elixir_rate = 3.0
	elif now >= 180000:
		elixir_rate = 2.0
	elif now >= 120000:
		elixir_rate = 1.5
	var gain: float = elixir_rate * delta * 0.3
	var g0: float = gain * team_elixir_gain_mult(0)
	var cap0: float = player_max_elixir
	if player_elixir < cap0:
		var p_new: float = minf(cap0, player_elixir + g0)
		stats_elixir_overflow[Config.Team.PLAYER] += maxf(0.0, player_elixir + g0 - cap0)
		player_elixir = p_new
	else:
		stats_elixir_overflow[Config.Team.PLAYER] += g0
	var g1: float = gain * team_elixir_gain_mult(1)
	var cap1: float = team_elixir_cap(1)
	if enemy_elixir < cap1:
		var e_new: float = minf(cap1, enemy_elixir + g1)
		stats_elixir_overflow[Config.Team.ENEMY] += maxf(0.0, enemy_elixir + g1 - cap1)
		enemy_elixir = e_new
	else:
		stats_elixir_overflow[Config.Team.ENEMY] += g1
	for sk in remote_players.keys():
		var rp: Dictionary = remote_players[sk]
		var st: int = int(rp.team)
		var cap: float = float(remote_max_elixirs.get(sk, team_elixir_cap(st)))
		rp.elixir = minf(cap, float(rp.elixir) + gain * team_elixir_gain_mult(st))
		remote_players[sk] = rp


func _update_tutorial_enemy(delta: float) -> void:
	if not tutorial_battle or game_over:
		return
	_tutorial_ai_timer -= delta
	if _tutorial_ai_timer > 0.0:
		return
	_tutorial_ai_timer = 7.0
	var pool: Array = [44, 4, 8, 10]
	var cid: int = int(pool[randi() % pool.size()])
	var cfg = get_config(cid)
	if cfg == null:
		return
	var cx: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
	var x: float = cx + randf_range(-4.5, 4.5)
	var z: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * randf_range(0.16, 0.28)
	spawn_unit(cfg, Config.Team.ENEMY, Vector3(x, 0.0, z), -1, PlayerData.ai_level(cid))

func network_ai_takeover(slot: int) -> void:
	if not remote_players.has(slot):
		return
	var rp: Dictionary = remote_players[slot]
	rp["ai"] = true
	remote_players[slot] = rp
	_ai_timers[slot] = randf_range(1.0, 2.5)

func _update_network_ai(delta: float) -> void:
	if not network_host_mode or network_countdown > 0.0 or touchdown_resetting:
		return
	for slot in remote_players.keys():
		var rp: Dictionary = remote_players[slot]
		if not bool(rp.get("ai", false)):
			continue
		var tm: float = float(_ai_timers.get(slot, 3.0)) - delta
		if tm > 0.0:
			_ai_timers[slot] = tm
			continue
		_ai_timers[slot] = randf_range(2.2, 4.0)
		var hand: Array = Array(rp.hand)
		if hand.is_empty():
			continue
		hand.shuffle()
		var team: int = int(rp.team)
		var slot_i: int = int(slot)
		for cid in hand:
			var cfg = get_config(int(cid))
			if cfg == null:
				continue
			if float(rp.elixir) < float(card_cost(cfg)):
				continue
			var xr: Vector2 = Vector2(0.12, 0.45) if slot_i % 2 == 0 else Vector2(0.55, 0.88)
			var zr: Vector2 = Vector2(0.14, 0.32) if team == 1 else Vector2(0.68, 0.86)
			var px: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * randf_range(xr.x, xr.y)
			var pz: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * randf_range(zr.x, zr.y)
			var reason: String = network_remote_deploy_slot(slot_i, int(cid), px, pz)
			if reason == "":
				break

func _score_tied() -> bool:
	if win_condition == "touchdown":
		return int(touchdown_score[0]) == int(touchdown_score[1])
	return player_crowns == enemy_crowns

func _score_winner() -> int:
	if win_condition == "touchdown":
		return Config.Team.PLAYER if int(touchdown_score[0]) > int(touchdown_score[1]) else Config.Team.ENEMY
	return Config.Team.PLAYER if player_crowns > enemy_crowns else Config.Team.ENEMY

func _check_timeout():
	if timeout_checked or game_over:
		return
	timeout_checked = true
	if _score_tied():
		_start_overtime()
	else:
		game_over = true
		winner = _score_winner()
		_timeout_game_over()

func _start_overtime() -> void:
	overtime = true
	overtime_end_ms = game_time + 120000.0
	if hud and hud.has_method("set_overtime_ui"):
		hud.set_overtime_ui(true)

func _update_overtime() -> void:
	if not _score_tied():
		game_over = true
		winner = _score_winner()
		_timeout_game_over()
		return
	if game_time >= overtime_end_ms:
		if win_condition == "touchdown":
			game_over = true
			match_draw = true
			winner = -1
			if hud and hud.has_method("show_battle_notice"):
				hud.show_battle_notice("平局", "冲线模式加时结束，双方比分相同", 2.0)
			_timeout_game_over()
		else:
			_begin_tower_bleed()

func _begin_tower_bleed() -> void:
	tower_bleed_active = true
	tower_bleed_acc = 0.0
	# 清空场上所有非皇家塔单位、子弹和法术
	for u in units.get_children():
		if u is Unit and u.config and int(u.config.card_id) > 3:
			u.queue_free()
	for b in bullets.get_children():
		b.queue_free()
	for s in spells.get_children():
		if s is Spell:
			s.queue_free()
	if hud and hud.has_method("set_tower_bleed_ui"):
		hud.set_tower_bleed_ui(true)

func _update_tower_bleed(delta: float) -> void:
	tower_bleed_acc += delta
	while tower_bleed_acc >= 0.01 and not game_over:
		tower_bleed_acc -= 0.01
		var dead_team: int = -1
		for u in units.get_children():
			if not (u is Unit) or u.config == null or int(u.config.card_id) > 3 or u.health <= 0:
				continue
			u.health = maxf(0.0, float(u.health) - 1.0)
			var idx: int = int(u.id)
			if idx >= 0 and idx < healths.size():
				healths[idx] = u.health
			if u.health <= 0.0 and dead_team < 0:
				dead_team = int(u.team)
		if dead_team >= 0:
			tower_bleed_active = false
			game_over = true
			winner = 1 - dead_team
			# 若双方同时被扣到 0，按剩余总塔血判定
			var hp0: float = _team_tower_total_health(Config.Team.PLAYER)
			var hp1: float = _team_tower_total_health(Config.Team.ENEMY)
			if absf(hp0 - hp1) < 0.5:
				match_draw = true
				winner = -1
			_timeout_game_over()
			return

func _timeout_game_over() -> void:
	timeout_sequence = true
	for u in units.get_children():
		if u is Unit:
			u.set_physics_process(false)
			u.set_process(false)
	for b in bullets.get_children():
		b.set_physics_process(false)
	for s in spells.get_children():
		s.active = false
	if hud:
		hud.hide_card_tray()
	await get_tree().create_timer(0.35).timeout
	var cam := get_viewport().get_camera_3d()
	if cam is Camera3D:
		var tw := create_tween()
		tw.tween_property(cam, "size", cam.size + 9.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.7).timeout
	timeout_sequence = false
	_show_game_over()

# ============ 玩家手牌 ============
func _initialize_player_deck():
	card_desk.clear()
	if replay_mode and not replay_player_deck.is_empty():
		for cid in replay_player_deck:
			card_desk.append(int(cid))
		for i in range(mini(4, card_desk.size())):
			_draw_card()
		return
	# 模式指定卡组（经典卡组模式）
	if not mode_player_deck.is_empty():
		card_desk = mode_player_deck.duplicate()
	# 测试模式：随机全卡（不受未解锁限制），等级由 battle_level 固定为 11
	elif PlayerData.test_mode:
		var all_ids: Array = []
		for cfg in configs:
			if (cfg.cost > 0 or cfg.card_id == 123) and cfg.card_id >= 4:
				all_ids.append(cfg.card_id)
		all_ids.shuffle()
		for i in range(mini(8, all_ids.size())):
			card_desk.append(all_ids[i])
	else:
		# 非测试模式：只使用当前卡组中已拥有并解锁的卡牌
		var deck: Array = PlayerData.get_active_deck()
		for cid_v in deck:
			if card_desk.size() >= 8:
				break
			var cid: int = int(cid_v)
			if get_config(cid) != null and PlayerData.is_card_owned(cid) and not card_desk.has(cid):
				card_desk.append(cid)
		# 严格只使用卡组内的卡牌（不足 8 张时不随机补卡）
	if tutorial_battle:
		# 实战训练固定起手：骑士、弓箭手、火球、巨人
		card_desk = [4, 8, 11, 9, 44, 10]
	#card_desk = [78,79,85,91,97,84,86,91]
	# 初始手牌4张（镜像不能作为起始卡）
	for i in range(4):
		_draw_card()
	for _i in range(6):
		var mirror_card = null
		for c in player_hand:
			if c.config.card_id == 123:
				mirror_card = c
				break
		if mirror_card == null:
			break
		card_desk.append(123)
		player_hand.erase(mirror_card)
		mirror_card.queue_free()
		_draw_card()

func next_card_id() -> int:
	return card_desk[0] if card_desk.size() > 0 else -1

func _draw_card(insert_at: int = -1):
	if card_desk.is_empty():
		return
	var card_id = card_desk.pop_front()
	var cfg = get_config(card_id)
	if not cfg:
		return
	var card_ui = CardUI.new()
	card_ui.setup(cfg, player_hand.size(), self)
	player_hand.append(card_ui)
	hud.card_container.add_child(card_ui)
	if insert_at >= 0 and insert_at < hud.card_container.get_child_count() - 1:
		hud.card_container.move_child(card_ui, insert_at)
	card_ui.gui_input.connect(_on_card_gui_input.bind(card_ui))

func _on_card_gui_input(event: InputEvent, card: CardUI):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_card == card:
			selected_card = null
		else:
			selected_card = card

func _cycle_card(used_card: CardUI):
	var idx: int = used_card.get_index()
	# 先从容器移除（queue_free 延迟，避免新卡插入位置错乱）
	player_hand.erase(used_card)
	if hud and hud.card_container and used_card.get_parent() == hud.card_container:
		hud.card_container.remove_child(used_card)
	used_card.queue_free()
	# 将使用的卡牌 id 放回卡组末尾
	card_desk.append(used_card.config.card_id)
	# 抽一张新卡并放回原位置
	_draw_card(idx)
	if hud:
		hud._next_shown_id = -2
		hud.play_next_card_fly(idx)

# ============ 战场点击部署 ============
func _input(event):
	# 拖拽期间完全由拖拽系统处理
	if is_dragging:
		return

	# 非拖拽选中卡牌时，鼠标移动更新范围圆环
	if selected_card and not is_dragging:
		if event is InputEventMouseMotion:
			update_selection_preview(event.position)
			return
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 获取战场点击位置，部署单位
			var cam = get_viewport().get_camera_3d()
			if not cam: return
			var from = cam.project_ray_origin(event.position)
			var to = from + cam.project_ray_normal(event.position) * 100
			var result = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
			if result and result.collider.name == "GroundPlane":
				var pos = result.position
				pos.x = floor((pos.x - Config.ARENA_ORIGIN.x) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.x + Config.GRID_SIZE * 0.5
				pos.z = floor((pos.z - Config.ARENA_ORIGIN.z) / Config.GRID_SIZE) * Config.GRID_SIZE + Config.ARENA_ORIGIN.z + Config.GRID_SIZE * 0.5
				# 边界检查
				if pos.x < Config.ARENA_ORIGIN.x or pos.x > Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH: return
				if pos.z < Config.ARENA_ORIGIN.z or pos.z > Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT: return

				var cfg = selected_card.config
				if network_guest_mode:
					if network_guest_mirrored:
						var gcx: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 0.5
						var gcz: float = Config.ARENA_ORIGIN.z + Config.ARENA_HEIGHT * 0.5
						NetworkManager.request_deploy(cfg.card_id, gcx * 2.0 - pos.x, gcz * 2.0 - pos.z)
					else:
						NetworkManager.request_deploy(cfg.card_id, pos.x, pos.z)
					cancel_drag()
					return
				if SPELL_IDS.has(cfg.card_id):
					if player_elixir >= card_cost(cfg):
						deploy_spell(cfg, Config.Team.PLAYER, pos)
						if replay_recorder:
							replay_recorder.record_player_action(cfg, pos)
						if match_replay_recorder:
							match_replay_recorder.record_action(Config.Team.PLAYER, cfg.card_id, pos)
						var ccost: int = card_cost(cfg)
						player_elixir -= ccost
						stats_elixir_spent[Config.Team.PLAYER] += ccost
						if cfg.card_id != 123:
							last_played_card_id = cfg.card_id
						_cycle_card(selected_card)
						selected_card = null
				else:
					if is_valid_placement(selected_card.config, pos, Config.Team.PLAYER):
						if player_elixir >= card_cost(cfg):
							if cfg.card_id == 109:
								_deploy_miner_tunnel(cfg, Config.Team.PLAYER, pos)
							elif cfg.card_id == 110:
								_deploy_log_like(cfg, Config.Team.PLAYER, pos)
							else:
								spawn_unit(cfg, Config.Team.PLAYER, pos)
							PlayerData.record_card_use(int(cfg.card_id))
							if replay_recorder:
								replay_recorder.record_player_action(cfg, pos)
							if match_replay_recorder:
								match_replay_recorder.record_action(Config.Team.PLAYER, cfg.card_id, pos)
							var ucost: int = card_cost(cfg)
							player_elixir -= ucost
							stats_elixir_spent[Config.Team.PLAYER] += ucost
							_cycle_card(selected_card)
							selected_card = null
			return

func deploy_spell(config: CardData, team: int, target_pos: Vector3, level_override: int = -1):
	if touchdown_resetting and win_condition == "touchdown":
		return
	if win_condition == "touchdown" and not _touchdown_spell_zone_ok(team, target_pos):
		return
	if team == Config.Team.PLAYER:
		_record_tutorial_card(int(config.card_id))
		if not replay_mode:
			PlayerData.record_card_use(int(config.card_id))
	if config.card_id == 48:
		# 雷电法术：不从国王塔飞出，3 道雷电依次从天而降（间隔 0.67s）
		_lightning_spell_strikes(config, team, target_pos)
		return
	if config.card_id == 122:
		for u in units.get_children():
			if not (u is Unit) or u.team != team or u.health <= 0:
				continue
			if u.config.type == Config.UnitType.BUILDING:
				continue
			if u.global_position.distance_to(target_pos) > 3.0:
				continue
			var cu = spawn_unit(u.config, team, u.global_position + Vector3(0.6, 0, 0.6), 1)
			if cu:
				cu.max_health = 1
				cu.health = 1
				if cu.visual_root:
					cu._set_ghost_alpha(cu.visual_root, 0.55)
		return
	if config.card_id == 123:
		if last_played_card_id < 0:
			return
		var last_cfg = get_config(last_played_card_id)
		if last_cfg == null or last_cfg.card_id == 123:
			return
		# 镜像等级 = 镜像卡等级 + 1
		var mirror_lv: int = PlayerData.get_card_level(123) + 1
		if last_cfg.card_id == 91 or last_cfg.card_id == 110:
			_deploy_log_like(last_cfg, team, target_pos, mirror_lv)
			return
		if SPELL_IDS.has(last_cfg.card_id):
			if last_cfg.attack_speed > 0:
				var msp = Spell.create(target_pos, team, int(last_cfg.damage * Config.level_mult(mirror_lv)), last_cfg.damage_range, 0, last_cfg.attack_type, last_cfg.target_type)
				msp.card_id = last_cfg.card_id
				msp.time = last_cfg.attack_speed
				spells.add_child(msp)
			else:
				var isp = Spell.create(target_pos, team, int(last_cfg.damage * Config.level_mult(mirror_lv)), last_cfg.damage_range, 0, last_cfg.attack_type, last_cfg.target_type)
				isp.card_id = last_cfg.card_id
				isp.time = 0
				spells.add_child(isp)
		else:
			spawn_unit(last_cfg, team, target_pos, 1, mirror_lv)
		return
	if config.card_id == 110:
		var bb = Bullet.new()
		bb.config = config
		bb.team = team
		bb.split_speed = 5.0
		bb.size = 2.6
		bb.position = target_pos
		bb.splited = 1
		bb.split_distance = 4.5
		bb.split_angle = PI/2 if team == Config.Team.PLAYER else -PI/2
		bb.split_penetrate = 1
		bullets.add_child(bb)
		return
	if config.card_id in [20, 78, 80, 104]:
		# 电击/狂暴/冰冻：立即在目标处生效，不从国王塔发射
		_instant_spell(config, team, target_pos)
		return
	if config.card_id == 91:
		_deploy_log_like(config, team, target_pos, level_override)
		return
	if config.card_id == 70:
		_deploy_miner_tunnel(config, team, target_pos)
		return
	if config.attack_speed>0 and config.card_id != 70:
		var level
		if team ==Config.Team.PLAYER:
			level =PlayerData.get_card_level(config.card_id)
		else:
			level = PlayerData.ai_level(config.card_id)
		level = mode_level(Config.battle_level(level))
		var spell = Spell.create(target_pos, team,
			int(config.damage *Config.level_mult(level)), config.damage_range,
			0, config.attack_type, config.target_type)
		spell.card_id = config.card_id
		spell.time = config.attack_speed
		spells.add_child(spell)
		var boom = load("res://assets/audio/sfx/deploy_wizard.wav")
		if boom:
			AudioManager.play_sfx(boom, target_pos)
		return
	var start_pos: Vector3
	if win_condition == "touchdown":
		# 冲线模式没有国王塔：发射性法术从己方冲线中央出发
		var own_z: float = Config.ARENA_ORIGIN.z + (Config.ARENA_HEIGHT - 2.0 if team == Config.Team.PLAYER else 2.0)
		start_pos = Vector3(0.0, 1.2, own_z)
	else:
		var king_tower = get_king_tower(team)
		start_pos = king_tower.global_position if king_tower else target_pos + Vector3(0, 10, 0)

	# 根据法术类型设定飞行速度
	var speed = 20.0
	if config.card_id == 40:   # 哥布林飞桶
		speed = 10.0
	elif config.card_id in [11, 31]:   # 火球、大雪球
		speed = 15.0

	var callback = Callable(self, "_on_spell_projectile_arrive").bind(config, team, target_pos)
	var proj = Bullet.create_spell_projectile(start_pos, target_pos, speed, team, config, callback)

	# 个性化法术投射物颜色（仅当首个子节点是 MeshInstance3D 时）
	var first := proj.get_child(0) as MeshInstance3D
	if first and first.material_override:
		match config.card_id:
			11: pass  # 火球保留模型自带火焰配色
			31: first.material_override.albedo_color = Color.WHITE    # 大雪球
		# 万箭齐发、电击等可自行添加
	bullets.add_child(proj)
	if config.card_id == 40:
		proj.arc_height = 3.2
	if config.card_id == 77:
		proj.arc_height = 3.8
	# 圣水已在外层扣除，此处不重复扣费
# ============================================================
# 掘地矿工：从国王塔钻地 → 横平竖直路径 → 过桥 → 目的地出土
# ============================================================
func _deploy_miner_tunnel(_config: CardData, team: int, target_pos: Vector3) -> void:
	var cfg = _config
	var start: Vector3
	if win_condition == "touchdown":
		var own_z: float = Config.ARENA_ORIGIN.z + (Config.ARENA_HEIGHT - 2.0 if team == Config.Team.PLAYER else 2.0)
		start = Vector3(0.0, 0.05, own_z)
	else:
		var kt = get_king_tower(team)
		start = kt.global_position if kt else target_pos + Vector3(0, 0, 8.0)
	start.y = 0.05
	var unit: Unit = spawn_unit(cfg, team, start, 1)
	if unit == null:
		return
	unit.tunnel = true
	if unit.visual_root:
		unit.visual_root.visible = false
	var col := unit.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = true
	var path: Array = _miner_path_touchdown(start, target_pos) if win_condition == "touchdown" else _miner_path(start, target_pos)
	_show_tunnel_path(start, path)
	_run_miner_tunnel(unit, start, path)

func _miner_path_touchdown(from: Vector3, to: Vector3) -> Array:
	# 足球场没有河/桥：直接斜线钻到目标，不再绕桥
	return [Vector3(to.x, 0.05, to.z)]


func _miner_path(from: Vector3, to: Vector3) -> Array:
	var a := Vector3(from.x, 0.05, from.z)
	var b := Vector3(to.x, 0.05, to.z)
	var pts: Array = []
	var b1: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 3.5 / 18.0
	var b2: float = Config.ARENA_ORIGIN.x + Config.ARENA_WIDTH * 14.5 / 18.0
	if signf(a.z) != signf(b.z):
		var bridge: float = b1 if absf(a.x - b1) + absf(b.x - b1) < absf(a.x - b2) + absf(b.x - b2) else b2
		pts.append(Vector3(bridge, 0.05, a.z))   # 横移到桥头
		pts.append(Vector3(bridge, 0.05, 0.0))   # 竖直过桥
		pts.append(Vector3(bridge, 0.05, b.z))   # 出桥
		pts.append(b)                            # 横移到目标
	else:
		pts.append(Vector3(b.x, 0.05, a.z))      # 先横后竖
		pts.append(b)
	return pts

func _show_tunnel_path(start: Vector3, path: Array) -> void:
	var prev: Vector3 = start
	for p in path:
		var d: Vector3 = p - prev
		var l: float = Vector2(d.x, d.z).length()
		if l > 0.05:
			var cy := CylinderMesh.new()
			cy.top_radius = 0.16
			cy.bottom_radius = 0.16
			cy.height = l
			cy.radial_segments = 8
			var mi := MeshInstance3D.new()
			mi.mesh = cy
			var mid: Vector3 = (prev + p) * 0.5
			mi.position = Vector3(mid.x, 0.05, mid.z)
			mi.quaternion = Quaternion(Vector3.UP, Vector3(d.x, 0.0, d.z).normalized())
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.42, 0.28, 0.16, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			var tw := mi.create_tween()
			tw.tween_interval(1.0)
			tw.tween_property(m, "albedo_color:a", 0.0, 1.0)
			tw.tween_callback(mi.queue_free)
		prev = p

func _run_miner_tunnel(unit: Unit, start: Vector3, path: Array) -> void:
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.30
	sm.height = 0.32
	mound.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.40, 0.28, 0.16)
	mm.roughness = 1.0
	mound.material_override = mm
	mound.position = Vector3(start.x, 0.12, start.z)
	add_child(mound)
	var prev: Vector3 = start
	var idx := 0
	for p in path:
		var d: Vector3 = p - prev
		var dist: float = Vector2(d.x, d.z).length()
		var steps: int = maxi(1, int(dist / 0.45))
		for i in range(steps):
			var t: float = float(i + 1) / float(steps)
			mound.position = Vector3(prev.x + d.x * t, 0.12, prev.z + d.z * t)
			idx += 1
			if idx % 2 == 0:
				_spawn_dirt_puff(mound.position)
			await get_tree().create_timer(0.03).timeout
		prev = p
	mound.queue_free()
	var end: Vector3 = path[path.size() - 1]
	unit.global_position = Vector3(end.x, 0.05, end.z)
	if unit.visual_root:
		unit.visual_root.position.y = -1.0
		var tw2 := unit.create_tween()
		tw2.tween_property(unit.visual_root, "position:y", 0.0, 0.22)
		unit.visual_root.visible = true
	var col := unit.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		col.disabled = false
	unit.tunnel = false
	unit._on_tunnel_emerge()
	for i in 8:
		_spawn_dirt_puff(unit.global_position)

func _spawn_dirt_puff(pos: Vector3) -> void:
	var puff := MeshInstance3D.new()
	var s := SphereMesh.new()
	var r: float = randf_range(0.07, 0.15)
	s.radius = r
	s.height = r * 2.0
	puff.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.45, 0.31, 0.18, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material_override = m
	puff.position = pos + Vector3(randf_range(-0.2, 0.2), 0.12, randf_range(-0.2, 0.2))
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	var tw := puff.create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "position:y", puff.position.y + 0.35, 0.45)
	tw.tween_property(puff, "scale", Vector3(1.7, 1.7, 1.7), 0.45)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(puff.queue_free)

func _on_spell_projectile_arrive(config: CardData, team: int, pos: Vector3):
	if config.card_id == 40:   # 哥布林飞桶
		var goblin_cfg = get_config(39)
		for i in range(4):
			var offset = Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
			spawn_unit(goblin_cfg, team, pos + offset,1)
	elif config.card_id == 70:
		var miner_cfg = get_config(70)
		spawn_unit(miner_cfg,team,pos)
	else:
		
		var level
		if team ==Config.Team.PLAYER:
			level =PlayerData.get_card_level(config.card_id)
		else:
			level = PlayerData.ai_level(config.card_id)
		level = mode_level(Config.battle_level(level))
		var spell = Spell.create(pos, team,
			int(config.damage *Config.level_mult(level)), config.damage_range,
			0, config.attack_type, config.target_type)
		spell.card_id = config.card_id
		spells.add_child(spell)
	var boom = load("res://assets/audio/sfx/deploy_wizard.wav")
	if boom:
		AudioManager.play_sfx(boom, pos)
	_spawn_effect(pos)
func show_network_result(winner_team: int, crowns: Array, local_team: int, duration_sec: float = -1.0, extra: Dictionary = {}) -> void:
	if hud == null:
		return
	var cs0: int = int(crowns[0]) if crowns.size() > 0 else 0
	var cs1: int = int(crowns[1]) if crowns.size() > 1 else 0
	var my_c: int = cs0 if local_team == 0 else cs1
	var en_c: int = cs1 if local_team == 0 else cs0
	if not replay_mode and not tutorial_battle:
		PlayerData.add_season_crowns(my_c)
	var data := {
		"win": winner_team == local_team and winner_team >= 0,
		"custom_title": "平  局" if winner_team < 0 else ("胜  利" if winner_team == local_team else "失  败"),
		"custom_sub": "D R A W" if winner_team < 0 else ("V I C T O R Y" if winner_team == local_team else "D E F E A T"),
		"crowns_my": my_c,
		"crowns_en": en_c,
		"trophy": 0,
		"duration": "%d:%02d" % [int((duration_sec if duration_sec >= 0.0 else game_time / 1000.0) / 60.0), int(duration_sec if duration_sec >= 0.0 else game_time / 1000.0) % 60],
		"my_spent": int(extra.get("spent0", 0)) if local_team == 0 else int(extra.get("spent1", 0)),
		"enemy_spent": int(extra.get("spent1", 0)) if local_team == 0 else int(extra.get("spent0", 0)),
		"my_over": float(extra.get("over0", 0.0)) if local_team == 0 else float(extra.get("over1", 0.0)),
		"enemy_over": float(extra.get("over1", 0.0)) if local_team == 0 else float(extra.get("over0", 0.0)),
		"my_top": extra.get("top0", []) if local_team == 0 else extra.get("top1", []),
		"enemy_top": extra.get("top1", []) if local_team == 0 else extra.get("top0", []),
	}
	if hud.game_over_screen:
		hud.game_over_screen.populate(data)
	hud.hide_battle_hud_for_result()
	hud.game_over_panel.visible = true

func _duel_round_end() -> void:
	if duel_transition or duel_finished:
		return
	duel_transition = true
	var round_winner: int = winner
	for u in units.get_children():
		if u is Unit:
			u.set_physics_process(false)
			u.set_process(false)
	for b in bullets.get_children():
		b.set_physics_process(false)
	for s in spells.get_children():
		s.active = false
	if hud:
		hud.hide_card_tray()
	var res: Dictionary = BATTLE_MODES.duel_advance(round_winner)
	duel_wins = Array(res.get("wins", duel_wins)).duplicate()
	_show_duel_overlay(round_winner, res)
	await get_tree().create_timer(1.7).timeout
	if bool(res.get("match_over", false)):
		duel_finished = true
		duel_match_winner = int(res.get("match_winner", round_winner))
		winner = duel_match_winner
		duel_transition = false
		_show_game_over()
		return
	get_tree().reload_current_scene()


func _show_duel_overlay(round_winner: int, res: Dictionary) -> void:
	if hud == null:
		return
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 200
	hud.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -180
	panel.offset_bottom = 180
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, 0.98)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.945, 0.765, 0.36, 0.8)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 26
	vbox.offset_right = -26
	vbox.offset_top = 22
	vbox.offset_bottom = -22
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var font: Font = load(ThemeHelper.DEFAULT_FONT_PATH)
	var title := Label.new()
	title.text = "决斗 · 第 %d 回合" % int(res.get("round", duel_round))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.945, 0.765, 0.36))
	if font != null:
		title.add_theme_font_override("font", font)
	vbox.add_child(title)
	var result := Label.new()
	result.text = "你赢下本回合" if round_winner == Config.Team.PLAYER else "对手赢下本回合"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 20)
	result.add_theme_color_override("font_color", Color(0.93, 0.90, 0.80))
	if font != null:
		result.add_theme_font_override("font", font)
	vbox.add_child(result)
	var score := Label.new()
	score.text = "总比分  %d : %d" % [int(duel_wins[0]), int(duel_wins[1])]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 34)
	score.add_theme_color_override("font_color", Color(0.945, 0.765, 0.36))
	if font != null:
		score.add_theme_font_override("font", font)
	vbox.add_child(score)
	var hint := Label.new()
	hint.text = "决斗结束" if bool(res.get("match_over", false)) else "准备下一回合…"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.63, 0.68, 0.795))
	if font != null:
		hint.add_theme_font_override("font", font)
	vbox.add_child(hint)


func _show_game_over() -> void:
	if not replay_mode and not suppress_game_over_ui and not network_host_mode and not network_guest_mode:
		var CH := preload("res://scripts/core/Challenges.gd")
		if CH.active_id() != "":
			challenge_result = CH.report_result(winner == Config.Team.PLAYER)
	if network_host_mode:
		var extra := {
			"top0": _top3_arr(0), "top1": _top3_arr(1),
			"spent0": float(stats_elixir_spent[0]), "spent1": float(stats_elixir_spent[1]),
			"over0": float(stats_elixir_overflow[0]), "over1": float(stats_elixir_overflow[1]),
		}
		NetworkManager.send_match_end(winner, [player_crowns, enemy_crowns], game_time / 1000.0, extra)
		show_network_result(winner, [player_crowns, enemy_crowns], 0, game_time / 1000.0, extra)
		return
	if replay_mode or suppress_game_over_ui:
		return
	if hud == null:
		return
	var win: bool = winner == Config.Team.PLAYER and not match_draw and winner >= 0
	var trophy_change: int = 0
	if winner < 0 or match_draw:
		AudioManager.play_sfx(ProceduralAudio.get_sound("defeat"))
	elif win:
		trophy_change = randi_range(25, 35)
		AudioManager.play_sfx(ProceduralAudio.get_sound("victory"))
	else:
		trophy_change = -randi_range(25, 35)
		AudioManager.play_sfx(ProceduralAudio.get_sound("defeat"))
	if win and PlayerData.consume_daily_chest_win():
		var rand = randf()
		if rand < 0.7:
			PlayerData.add_chest("silver")
		elif rand < 0.95:
			PlayerData.add_chest("gold")
		else:
			PlayerData.add_chest("magical")
		_pending_chest_index = PlayerData.chests.size() - 1
	if trophy_change != 0:
		PlayerData.add_trophies(trophy_change)
	if trophy_change != 0:
		LeaderboardAPI.submit_trophies(PlayerData.trophies, PlayerData.player_name)
	if not replay_mode and not tutorial_battle:
		PlayerData.add_season_crowns(player_crowns)
	var dur: String = "%d:%02d" % [int(game_time / 60000.0), int(game_time / 1000.0) % 60]
	var data := {
		"win": win,
		"custom_title": "平  局" if (winner < 0 or match_draw) else ("胜  利" if win else "失  败"),
		"custom_sub": "D R A W" if (winner < 0 or match_draw) else ("V I C T O R Y" if win else "D E F E A T"),
		"crowns_my": player_crowns,
		"crowns_en": enemy_crowns,
		"trophy": trophy_change,
		"duration": dur,
		"my_spent": stats_elixir_spent[Config.Team.PLAYER],
		"enemy_spent": stats_elixir_spent[Config.Team.ENEMY],
		"my_over": stats_elixir_overflow[Config.Team.PLAYER],
		"enemy_over": stats_elixir_overflow[Config.Team.ENEMY],
		"my_top": _top3_arr(Config.Team.PLAYER),
		"enemy_top": _top3_arr(Config.Team.ENEMY),
	}
	if hud.game_over_screen:
		hud.game_over_screen.populate(data)
	hud.hide_battle_hud_for_result()
	hud.game_over_panel.visible = true

func _top3_arr(team: int) -> Array:
	var d: Dictionary = stats_tower_damage[int(team)]
	var arr: Array = []
	for cid in d.keys():
		var cfg = get_config(int(cid))
		arr.append([cfg.card_name if cfg else str(cid), int(d[cid]), int(cid)])
	arr.sort_custom(func(a, b): return a[1] > b[1])
	return arr.slice(0, 3)
# ============================================================
# 皇冠动画 / 国王塔被摧毁流程
# ============================================================
func add_crown(tower_team: int, world_pos: Vector3) -> void:
	var scorer: int = Config.Team.ENEMY if tower_team == Config.Team.PLAYER else Config.Team.PLAYER
	if hud:
		await hud.fly_crown(world_pos, scorer)
	if scorer == Config.Team.PLAYER:
		player_crowns += 1
	else:
		enemy_crowns += 1
	if hud:
		hud.update_crown_labels(player_crowns, enemy_crowns)
	if win_condition == "touchdown":
		return
	if mode_id == "sudden_death" and not game_over:
		game_over = true
		winner = scorer
	elif player_crowns >= 3 or enemy_crowns >= 3:
		game_over = true
		winner = Config.Team.PLAYER if player_crowns > enemy_crowns else Config.Team.ENEMY

func on_king_destroyed(tower_team: int, world_pos: Vector3) -> void:
	if win_condition == "touchdown":
		return
	if king_sequence or game_over:
		return
	king_sequence = true
	game_over = true
	winner = Config.Team.ENEMY if tower_team == Config.Team.PLAYER else Config.Team.PLAYER
	# 立即冻结在场所有单位/子弹/法术
	for u in units.get_children():
		if u is Unit:
			u.set_physics_process(false)
			u.set_process(false)
	for b in bullets.get_children():
		b.set_physics_process(false)
	for s in spells.get_children():
		s.active = false
	var crown_positions: Array = []
	if hud:
		hud.hide_card_tray()
	# 敌方（战败方）公主塔同时播放摧毁动画并产生王冠
	for u in units.get_children():
		if not (u is Unit):
			continue
		if u.team != tower_team:
			continue
		if u.config.card_id == 1 or u.config.card_id == 2:
			if u.health > 0:
				u._play_tower_destruction()
				if u.visual_root:
					u.visual_root.visible = false
				if hud:
					hud.remove_health_bar(u)
				if u.get_node_or_null("CollisionShape3D"):
					(u.get_node("CollisionShape3D") as CollisionShape3D).disabled = true
			crown_positions.append(u.global_position + Vector3.UP * 1.2)
	crown_positions.append(world_pos + Vector3.UP * 0.6)
	# 等爆炸
	await get_tree().create_timer(0.9).timeout
	# 相机拉高（正交相机 = 增大 size）
	var cam := get_viewport().get_camera_3d()
	if cam is Camera3D:
		var tw := create_tween()
		tw.tween_property(cam, "size", cam.size + 9.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# 王冠飞向计数（国王塔 + 两座公主塔同时飞出）
	if hud:
		for cp in crown_positions:
			hud.fly_crown(cp, winner)
	if winner == Config.Team.PLAYER:
		player_crowns = 3
		enemy_crowns = enemy_crowns
	else:
		enemy_crowns = 3
	if hud:
		hud.update_crown_labels(player_crowns, enemy_crowns)
	await get_tree().create_timer(0.4).timeout
	king_sequence = false
	_show_game_over()
func _lightning_spell_strikes(config: CardData, team: int, target_pos: Vector3) -> void:
	var level: int
	if team == Config.Team.PLAYER:
		level = PlayerData.get_card_level(config.card_id)
	else:
		level = PlayerData.ai_level(config.card_id)
	level = mode_level(Config.battle_level(level))
	var total_dmg: int = int(config.damage * Config.level_mult(level))
	for i in range(3):
		var ang: float = float(i) * TAU / 3.0 + randf() * 0.6
		var r: float = config.damage_range * 0.45
		var p: Vector3 = target_pos + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var spell = Spell.create(p, team, total_dmg / 3, config.damage_range, 0, config.attack_type, config.target_type)
		spell.card_id = 48
		spells.add_child(spell)
		if i < 2:
			await get_tree().create_timer(0.67).timeout
func _instant_spell(config: CardData, team: int, target_pos: Vector3, level_override: int = -1) -> void:
	var level: int
	if team == Config.Team.PLAYER:
		level = PlayerData.get_card_level(config.card_id)
	else:
		level = PlayerData.ai_level(config.card_id)
	level = mode_level(Config.battle_level(level))
	var spell = Spell.create(target_pos, team, int(config.damage * Config.level_mult(level)), config.damage_range, 0, config.attack_type, config.target_type)
	spell.card_id = config.card_id
	spell.time = config.attack_speed if config.attack_speed > 0 else 0
	spells.add_child(spell)
	var boom = load("res://assets/audio/sfx/deploy_wizard.wav")
	if boom:
		AudioManager.play_sfx(boom, target_pos)

func add_tower_damage(team: int, card_id: int, amount: float) -> void:
	if amount <= 0.0:
		return
	var idx: int = int(team)
	if idx < 0 or idx > 1:
		return
	var d: Dictionary = stats_tower_damage[idx]
	d[card_id] = float(d.get(card_id, 0.0)) + amount
	stats_tower_damage[idx] = d

func _stats_text() -> String:
	var my_spent: float = stats_elixir_spent[Config.Team.PLAYER]
	var my_over: float = stats_elixir_overflow[Config.Team.PLAYER]
	var en_spent: float = stats_elixir_spent[Config.Team.ENEMY]
	var en_over: float = stats_elixir_overflow[Config.Team.ENEMY]
	var txt: String = "\n\n—— 对局统计 ——"
	txt += "\n我方：花费 %d 圣水 · 溢出 %.1f" % [int(my_spent), my_over]
	txt += "\n敌方：花费 %d 圣水 · 溢出 %.1f" % [int(en_spent), en_over]
	txt += "\n\n皇家塔伤害 TOP3（我方）"
	txt += _top3_text(Config.Team.PLAYER)
	txt += "\n皇家塔伤害 TOP3（敌方）"
	txt += _top3_text(Config.Team.ENEMY)
	return txt

func _top3_text(team: int) -> String:
	var d: Dictionary = stats_tower_damage[int(team)]
	var arr: Array = []
	for cid in d.keys():
		arr.append([float(d[cid]), int(cid)])
	arr.sort_custom(func(a, b): return a[0] > b[0])
	var out: String = ""
	for i in range(mini(3, arr.size())):
		var cfg = get_config(arr[i][1])
		var nm: String = cfg.card_name if cfg else str(arr[i][1])
		out += "\n  %d. %s  %d" % [i + 1, nm, int(arr[i][0])]
	if out == "":
		out = "\n  暂无"
	return out
# ============ 单位数据表（11 级） ============
func _try_load_unit_table() -> bool:
	# 两张表都允许作为数据源；以修改时间最新的为准，避免改了旧表却不生效。
	var paths: Array = []
	for path in ["res://data/units_level11_utf8.csv", "res://data/units_level11.csv"]:
		if FileAccess.file_exists(path):
			paths.append({"path": path, "mtime": FileAccess.get_modified_time(path)})
	paths.sort_custom(func(a, b): return int(a.mtime) > int(b.mtime))
	for p in paths:
		if _load_unit_table_file(String(p.path)):
			return true
	return false

func _load_unit_table_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var head := f.get_csv_line()
	var ci := {}
	for i in range(head.size()):
		ci[String(head[i]).strip_edges()] = i
	var need := ["id", "name", "cost", "num", "type", "hp", "damage", "attack_speed",
		"attack_range", "damage_range", "target_type", "move_speed", "move_type",
		"horizon", "size", "shield", "extra_spell", "spawn_unit", "attack_type",
		"multiple_targets", "multiple_process"]
	for k in need:
		if not ci.has(k):
			push_error("units_level11.csv 缺少列: " + k)
			f.close()
			return false
	var type_map := {
		"BUILDING": Config.UnitType.BUILDING,
		"GROUND": Config.UnitType.GROUND,
		"AIR": Config.UnitType.AIR,
	}
	var tgt_map := {
		"ALL": Config.TargetType.ALL,
		"GROUND_ONLY": Config.TargetType.GROUND_ONLY,
		"BUILDING_ONLY": Config.TargetType.BUILDING_ONLY,
	}
	var rows: Array = []
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < head.size():
			continue
		var nm := String(line[ci["name"]]).strip_edges()
		if nm == "" or nm.begins_with("name:"):
			continue
		if nm.contains("�"):
			f.close()
			return false
		var ctype: int = type_map.get(String(line[ci["type"]]).strip_edges(), Config.UnitType.GROUND)
		var ctgt: int = tgt_map.get(String(line[ci["target_type"]]).strip_edges(), Config.TargetType.ALL)
		rows.append(_make_card(
			nm,
			_csv_int(line[ci["id"]]),
			_csv_int(line[ci["cost"]]),
			_csv_int(line[ci["num"]]),
			ctype,
			_csv_float(line[ci["hp"]]),
			_csv_float(line[ci["damage"]]),
			_csv_int(line[ci["attack_speed"]]),
			_csv_float(line[ci["attack_range"]]),
			_csv_float(line[ci["damage_range"]]),
			ctgt,
			_csv_float(line[ci["move_speed"]]),
			_csv_int(line[ci["move_type"]]),
			_csv_float(line[ci["horizon"]]),
			_csv_float(line[ci["size"]]),
			_csv_float(line[ci["shield"]]),
			_csv_arr(line[ci["extra_spell"]]),
			_csv_arr(line[ci["spawn_unit"]]),
			_csv_int(line[ci["attack_type"]]),
			_csv_arr(line[ci["multiple_targets"]]),
			_csv_arr(line[ci["multiple_process"]])
		))
	f.close()
	if rows.size() < 10:
		push_error("units_level11.csv 有效数据不足: %d 行" % rows.size())
		return false
	configs = rows
	print("单位表已加载: %d 条（%s）" % [configs.size(), path])
	return true

func _csv_float(s: String) -> float:
	var t: String = s.strip_edges()
	return float(t) if t != "" else 0.0

func _csv_int(s: String) -> int:
	var t: String = s.strip_edges()
	if t == "" or t == "?":
		return 0
	if not t.is_valid_float():
		return 0
	return int(float(t))

func _csv_arr(s: String) -> Array:
	var t: String = s.strip_edges()
	if t == "" or t == "[]":
		return []
	var v = JSON.parse_string(t)
	if not (v is Array):
		return []
	# JSON 数字默认是 float，把整数值转回 int，避免 range()/数组下标类型问题
	var out: Array = []
	for item in v:
		if typeof(item) == TYPE_FLOAT and is_equal_approx(item, floorf(item)):
			out.append(int(item))
		else:
			out.append(item)
	return out
func gain_elixir(team: int, amount: int, world_pos: Vector3) -> void:
	if amount <= 0:
		return
	if team == Config.Team.PLAYER:
		player_elixir = minf(10.0, player_elixir + float(amount))
	else:
		enemy_elixir = minf(10.0, enemy_elixir + float(amount))
	_spawn_elixir_gain_fx(world_pos, team, amount)

func _spawn_elixir_gain_fx(pos: Vector3, team: int, amount: int) -> void:
	var col: Color = Color(0.72, 0.42, 1.0) if team == Config.Team.PLAYER else Color(1.0, 0.30, 0.26)
	# 3D 圣水水滴上升
	for i in range(6):
		var p := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = randf_range(0.06, 0.12)
		s.height = s.radius * 2.0
		p.mesh = s
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 1.5
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p.material_override = m
		p.position = pos + Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", p.position + Vector3(randf_range(-0.2, 0.2), 1.3, randf_range(-0.2, 0.2)), 0.8)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.8)
		tw.chain().tween_callback(p.queue_free)
	# 圣水水滴图标（紫色=我方 / 红色=敌方）
	var icon := Node3D.new()
	var drop := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.20
	sm.height = 0.34
	drop.mesh = sm
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.19
	cm.height = 0.28
	top.mesh = cm
	top.position.y = 0.24
	var im := StandardMaterial3D.new()
	im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	im.albedo_color = col
	im.emission_enabled = true
	im.emission = col
	im.emission_energy_multiplier = 1.8
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material_override = im
	top.material_override = im
	icon.add_child(drop)
	icon.add_child(top)
	icon.position = pos + Vector3(0, 0.6, 0)
	add_child(icon)
	var tw2 := icon.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(icon, "position", icon.position + Vector3(0, 1.5, 0), 0.9)
	tw2.tween_property(icon, "scale", Vector3(1.55, 1.55, 1.55), 0.9)
	tw2.tween_property(im, "albedo_color:a", 0.0, 0.9)
	tw2.chain().tween_callback(icon.queue_free)
func _deploy_log_like(cfg: CardData, team: int, pos: Vector3, lvl: int = 0) -> void:
	var bb := Bullet.new()
	bb.config = cfg
	bb.team = team
	bb.level = lvl
	bb.split_speed = 5.0
	bb.size = 2.6 if cfg.card_id == 110 else 3.9
	bb.position = pos
	bb.splited = 1
	bb.split_distance = 4.5 if cfg.card_id == 110 else 10.1
	bb.split_angle = PI / 2 if team == Config.Team.PLAYER else -PI / 2
	bb.split_penetrate = 1
	bullets.add_child(bb)
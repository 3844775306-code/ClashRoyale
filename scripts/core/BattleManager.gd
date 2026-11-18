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
var _network_count_label: Label = null
var _countdown_overlay: Control = null
var replay_meta: Dictionary = {}
var replay_player_deck: Array = []
var replay_towers: Array = []
var replay_arena: int = 0
var suppress_game_over_ui: bool = false
var enemy_elixir: float = 5.0
var elixir_rate: float = 1.0
var game_time: float = 0.0
var player_crowns: int = 0
var enemy_crowns: int = 0
var winner: int = -1
var game_over: bool = false
var king_sequence: bool = false
var timeout_sequence: bool = false
var overtime: bool = false
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
	# ----- 不可放置区域红色遮罩 -----
	if not SPELL_IDS.has(cfg.card_id) and cfg.card_id != 109:
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
		if SPELL_IDS.has(cfg.card_id):
			valid = true
			
			
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

func _ready():
	add_to_group("battle_manager")
	network_host_mode = NetworkManager.role == NetworkManager.Role.HOST and NetworkManager.consume_host_match()
	if network_host_mode:
		_setup_network_team_sizes()
	load_card_configs()
	spawn_initial_towers()
	_initialize_player_deck()
	if network_host_mode:
		_init_network_remote()
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
	else:
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
	if game_over:
		if king_sequence or timeout_sequence:
			return
		if not hud.game_over_panel.visible:
			_show_game_over()
		return
	game_time += delta * 1000.0
	var now = game_time
	if now >= Config.GAME_TIME_LIMIT and not game_over:
		_check_timeout()
	_update_elixir(delta)
	_update_network_ai(delta)


# ============ 配置加载 ============
func load_card_configs():
	const P2M = 0.05  # 像素→米 系数
	# 优先从本地 11 级单位表读取（data/units_level11.csv，可直接编辑）
	if _try_load_unit_table():
		return

	configs = [
		# ===== 塔 (id 1-3) =====
		_make_card("公主塔",      1, 0, 1, Config.UnitType.BUILDING, 3052, 109, 800,  140*P2M, 0, Config.TargetType.ALL, 0, 1, 140*P2M, 1.4),
		_make_card("王子塔",      2, 0, 1, Config.UnitType.BUILDING, 2616, 320, 2200, 140*P2M, 0, Config.TargetType.ALL, 0, 1, 140*P2M, 1.4),
		_make_card("国王塔",      3, 0, 1, Config.UnitType.BUILDING, 4824, 109, 1000, 130*P2M, 0, Config.TargetType.ALL, 0, 1, 120*P2M, 1.9),

		# ===== 部队 (id 4-57) =====
		_make_card("骑士",          4, 3, 1,  Config.UnitType.GROUND, 1766,168,1200, 8*P2M,   0,      Config.TargetType.GROUND_ONLY, 1.2, 1, 50*P2M,   (30/3.0)*P2M),
		_make_card("骷髅军团", 5, 3, 15, Config.UnitType.GROUND, 81, 81, 1100, 5*P2M, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 50*P2M, (18/3.0)*P2M),
		_make_card("闪电法师",      6, 4, 1,  Config.UnitType.GROUND, 714,115,1800,  90*P2M,  0,      Config.TargetType.ALL, 1.2, 1, 100*P2M,  (40/3.0)*P2M, 0, [190,2,2,3,-1], [], 2, [2,1]),
		_make_card("法师",          7, 5, 1,  Config.UnitType.GROUND, 755,281,1400,  100*P2M, 24*P2M, Config.TargetType.ALL, 1.2, 1, 110*P2M,  (40/3.0)*P2M),
		_make_card("亡灵", 8, 3, 3, Config.UnitType.AIR, 230, 107, 1100, 40*P2M, 0, Config.TargetType.ALL, 1.6, 1, 60*P2M, (24/3.0)*P2M),
		_make_card("巨人",          9, 5, 1,  Config.UnitType.GROUND, 4090,253,1500, 8*P2M,   0,      Config.TargetType.BUILDING_ONLY, 0.7, 0, 120*P2M,  (60/3.0)*P2M),
		_make_card("万箭齐发",         10, 3, 1,  Config.UnitType.GROUND, 1,366,0,    70*P2M,  70*P2M, Config.TargetType.ALL, 0, 1, 0,         (210/3.0)*P2M),
		_make_card("火球",         11, 4, 1,  Config.UnitType.GROUND, 1,688,0,   50*P2M,   50*P2M, Config.TargetType.ALL, 0, 0, 0,         (150/3.0)*P2M),
		_make_card("瓦基丽武神",   12, 4, 1,  Config.UnitType.GROUND, 1907,266,1500, 8*P2M,   25*P2M, Config.TargetType.GROUND_ONLY, 1.1, 1, 60*P2M,   (40/3.0)*P2M),
		_make_card("迷你皮卡", 13, 4, 1, Config.UnitType.GROUND, 1433, 755, 1600, 5*P2M, 0, Config.TargetType.GROUND_ONLY, 1.6, 1, 70*P2M, (40/3.0)*P2M),
		_make_card("飞龙宝宝",     14, 4, 1,  Config.UnitType.AIR,    1152,161,1500, 60*P2M,  18*P2M, Config.TargetType.ALL, 1.2, 1, 70*P2M,   (45/3.0)*P2M),
		_make_card("皮卡超人",     15, 7, 1,  Config.UnitType.GROUND, 3760,816,1800, 8*P2M,   0,      Config.TargetType.GROUND_ONLY, 0.7, 1, 100*P2M,  (55/3.0)*P2M),
		_make_card("王子",         16, 5, 1,  Config.UnitType.GROUND, 1920,391,1400, 12*P2M,  0,      Config.TargetType.GROUND_ONLY, 1.2, 2, 60*P2M,   (40/3.0)*P2M),
		_make_card("野猪骑士",     17, 4, 1,  Config.UnitType.GROUND, 1697,317,1600, 5*P2M,   0,      Config.TargetType.BUILDING_ONLY, 1.6, 3, 120*P2M,  (50/3.0)*P2M),
		_make_card("寒冰法师",     18, 3, 1,  Config.UnitType.GROUND, 688,89,1700,   100*P2M, 16*P2M, Config.TargetType.ALL, 1.2, 1, 100*P2M,  (30/3.0)*P2M, 0, [84,1.75,3,3,-1], [], 3),
		_make_card("女巫",         19, 5, 1,  Config.UnitType.GROUND, 839,135,1100,  100*P2M, 16*P2M, Config.TargetType.ALL, 1.2, 1, 110*P2M,  (50/3.0)*P2M, 0, [], [5,4,7000], 1),
		_make_card("电击法术",     20, 2, 1,  Config.UnitType.GROUND, 1,192,0,    50*P2M,  50*P2M, Config.TargetType.ALL, 0, 0, 0,         (150/3.0)*P2M, 0, [], [], 2),
		_make_card("特斯拉电磁塔", 21, 4, 1,  Config.UnitType.BUILDING,1152,220,1100,100*P2M, 0,      Config.TargetType.ALL, 0, 1, 100*P2M,  (50/3.0)*P2M),
		_make_card("蝙蝠",         22, 2, 5,  Config.UnitType.AIR,    81,81,1300,    8*P2M,   0,      Config.TargetType.ALL, 1.6, 1, 70*P2M,   (15/3.0)*P2M),
		_make_card("黑暗王子",     23, 4, 1,  Config.UnitType.GROUND, 1200,266,1300, 8*P2M,   20*P2M, Config.TargetType.GROUND_ONLY, 1.2, 2, 70*P2M,   (45/3.0)*P2M, 240),
		_make_card("骷髅墓碑",     24, 3, 1,  Config.UnitType.BUILDING,529,0,0,      0,       0,      Config.TargetType.ALL, 0, 1, 50*P2M,   (45/3.0)*P2M, 0, [], [5,1,4000], 1),
		_make_card("气球兵",       25, 5, 1,  Config.UnitType.AIR,    1679,640,2000, 0,       0,      Config.TargetType.BUILDING_ONLY, 0.8, 1, 120*P2M,  (60/3.0)*P2M, 0, [220,1.2,1,3,2000], [], 1),
		_make_card("炸弹塔", 26, 4, 1, Config.UnitType.BUILDING, 1356, 222, 1800, 110*P2M, 26*P2M, Config.TargetType.GROUND_ONLY, 0, 1, 90*P2M, (50/3.0)*P2M, 0, [222,1.2,1,3,2000], [], 1),
		_make_card("地狱飞龙",     27, 4, 1,  Config.UnitType.AIR,    1295,35,400,   60*P2M,  0,      Config.TargetType.ALL, 1.2, 1, 80*P2M,   (45/3.0)*P2M, 0, [], [], 4),
		_make_card("电磁炮",       28, 6, 1,  Config.UnitType.GROUND, 1451,1331,4000,90*P2M,  28*P2M, Config.TargetType.GROUND_ONLY, 0.8, 1, 100*P2M,  (50/3.0)*P2M, 0, [], [], 5),
		_make_card("野蛮人精锐",   29, 6, 2,  Config.UnitType.GROUND, 1341,384,1400, 12*P2M,  0,      Config.TargetType.GROUND_ONLY, 1.5, 1, 70*P2M,   (45/3.0)*P2M),
		_make_card("戈仑冰人",     30, 2, 1,  Config.UnitType.GROUND, 1315,84,2500,  5*P2M,   0,      Config.TargetType.BUILDING_ONLY, 0.7, 1, 50*P2M,   (50/3.0)*P2M, 0, [84,1.3,3,3,100], [], 3),
		_make_card("大雪球",         31, 2, 1,  Config.UnitType.GROUND, 1,179,0,   50*P2M,  50*P2M, Config.TargetType.ALL, 0, 1, 0,         (150/3.0)*P2M, 0, [], [], 3),
		_make_card("吹箭哥布林", 32, 3, 1, Config.UnitType.GROUND, 261, 156, 800, 120*P2M, 0, Config.TargetType.ALL, 1.6, 1, 130*P2M, (40/3.0)*P2M),
		_make_card("地狱之塔", 33, 5, 1, Config.UnitType.BUILDING, 1748, 43, 400, 110*P2M, 0, Config.TargetType.ALL, 0, 1, 110*P2M, (60/3.0)*P2M, 0, [], [], 4),
		_make_card("皇家巨人",     34, 6, 1,  Config.UnitType.GROUND, 3164,307,1700, 90*P2M,  0,      Config.TargetType.BUILDING_ONLY, 0.7, 1, 100*P2M,  (80/3.0)*P2M),
		_make_card("冰雪精灵",     35, 1, 1,  Config.UnitType.GROUND, 230,110,1300,  40*P2M,  24*P2M, Config.TargetType.ALL, 2.0, 1, 50*P2M,   (40/3.0)*P2M, -1, [], [], 3),
		_make_card("雷电飞龙",     36, 5, 1,  Config.UnitType.AIR,    943,192,2100,  60*P2M,  0,      Config.TargetType.ALL, 1.1, 1, 60*P2M,   (50/3.0)*P2M, 0, [], [], 2, [3,2]),
		_make_card("暗夜女巫",     37, 4, 1,  Config.UnitType.GROUND, 906,314,1300,  15*P2M,  0,      Config.TargetType.GROUND_ONLY, 1.2, 1, 50*P2M,   (50/3.0)*P2M, 0, [], [22,2,5000], 1),
		_make_card("皇家野猪",     38, 5, 4,  Config.UnitType.GROUND, 837,74,1200,   5*P2M,   0,      Config.TargetType.BUILDING_ONLY, 1.6, 3, 120*P2M,  (50/3.0)*P2M),
		_make_card("哥布林",       39, 2, 4,  Config.UnitType.GROUND, 202,120,1100,  5*P2M,   0,      Config.TargetType.GROUND_ONLY, 1.6, 1, 40*P2M,   (30/3.0)*P2M),
		_make_card("哥布林飞桶",   40, 3, 1,  Config.UnitType.GROUND, 1,0,0,     30*P2M,  30*P2M, Config.TargetType.GROUND_ONLY, 0, 0, 0,         (40/3.0)*P2M, 0, [], [39,3,0], 1),
		_make_card("骷髅巨人", 41, 6, 1, Config.UnitType.GROUND, 3617, 276, 1300, 5*P2M, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 50*P2M, (70/3.0)*P2M, 0, [535,1.5,1,3,3000], [], 1),
		_make_card("攻城炸弹人",   42, 2, 2,  Config.UnitType.GROUND, 330,1,500,     5*P2M,   40*P2M, Config.TargetType.BUILDING_ONLY, 2.1, 1, 120*P2M,  (35/3.0)*P2M, -1, [350,2,1,3,0], [], 1),
		_make_card("烟花炮手",     43, 3, 1,  Config.UnitType.GROUND, 304,64,3000,   120*P2M, 28*P2M, Config.TargetType.ALL, 1.6, 1, 130*P2M,  (35/3.0)*P2M, 0, [], [], 1, [], [15,5,20,2,1]),
		_make_card("弓箭手",       44, 3, 2,  Config.UnitType.GROUND, 304,112,900,   110*P2M, 0,      Config.TargetType.ALL, 1.1, 1, 130*P2M,  (35/3.0)*P2M),
		_make_card("雷电精灵",     45, 1, 1,  Config.UnitType.GROUND, 230,99,1300,   50*P2M,  0,      Config.TargetType.ALL, 2.0, 1, 50*P2M,   (40/3.0)*P2M, -1, [], [], 2, [9,2]),
		_make_card("治疗精灵",     46, 1, 1,  Config.UnitType.GROUND, 230,110,1300,  50*P2M,  0,      Config.TargetType.ALL, 2.0, 1, 70*P2M,   (40/3.0)*P2M, -1, [400,2.5,8,3,100], [], 8),
		_make_card("战斗天使",     47, 4, 1,  Config.UnitType.GROUND, 1717,148,1500, 15*P2M,  0,      Config.TargetType.GROUND_ONLY, 1.2, 1, 60*P2M,   (45/3.0)*P2M, 0, [120,2.5,8,3,0], [], 1),
		_make_card("雷电法术",     48, 6, 1,  Config.UnitType.GROUND, 1,1057,0,   70*P2M,  70*P2M, Config.TargetType.ALL, 0, 0, 0,         (70)*P2M, 0, [], [], 2, [3,3]),
		_make_card("野蛮人小屋",   49, 6, 1,  Config.UnitType.BUILDING,1164,0,0,     0,       0,      Config.TargetType.ALL, 0, 1, 0,         (60/3.0)*P2M, 0, [], [57,3,15000], 1),
		_make_card("烈焰精灵",     50, 1, 1,  Config.UnitType.GROUND, 230,207,1300,  50*P2M,  40*P2M, Config.TargetType.ALL, 2.0, 1, 70*P2M,   (30/3.0)*P2M, -1),
		_make_card("烈焰熔炉",     51, 4, 1,  Config.UnitType.GROUND, 727,179,1700,  110*P2M, 0,      Config.TargetType.ALL, 1.2, 1, 130*P2M,  (45/3.0)*P2M, 0, [], [50,1,7000], 1),
		_make_card("神箭游侠",     52, 4, 1,  Config.UnitType.GROUND, 529,143,1100,  120*P2M, 10*P2M, Config.TargetType.ALL, 1.2, 1, 150*P2M,  (45/3.0)*P2M, 0, [], [], 1, [], [0,1,100,11,2]),
		_make_card("皇家速递",     53, 3, 1,  Config.UnitType.GROUND, 537,133,1300,  15*P2M,  0,      Config.TargetType.GROUND_ONLY, 1.1, 1, 60*P2M,   (40/3.0)*P2M, 240, [437,3,1,3,-2000], [], 1),
		_make_card("飞行机器",       54, 4, 1,  Config.UnitType.AIR,    614,171,1100,  110*P2M, 0,      Config.TargetType.ALL, 1.2, 1, 130*P2M,  (50/3.0)*P2M),
		_make_card("十字连弩",        55, 6, 1,  Config.UnitType.BUILDING,1600,43,300,   220*P2M, 0,      Config.TargetType.GROUND_ONLY, 0, 1, 220*P2M,  (60/3.0)*P2M, 0, [], [], 1),
		_make_card("猎人",         56, 4, 1,  Config.UnitType.GROUND, 885,84,2200,   80*P2M,  25*P2M, Config.TargetType.ALL, 1.2, 1, 100*P2M,  (50/3.0)*P2M, 0, [], [], 1, [], [5,10,40,6.5,3]),
		_make_card("野蛮人", 57, 5, 5, Config.UnitType.GROUND, 737, 192, 1300, 5*P2M, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 50*P2M, (40/3.0)*P2M),
		_make_card("亡灵大军", 58, 5, 6, Config.UnitType.AIR, 230, 107, 1200, 50*P2M, 0*P2M, Config.TargetType.ALL, 1.6, 1, 3, (24/3.0)*P2M),
		_make_card("重甲亡灵",   59, 3, 1,  Config.UnitType.AIR,837,312,1500,     0.8,       0,      Config.TargetType.ALL, 1.2, 1, 2,         (30/3.0)*P2M),
		_make_card("电击车小队",     60, 4, 3,  Config.UnitType.GROUND, 529,117,2100,  90*P2M,  0*P2M, Config.TargetType.ALL, 1.2, 1, 100*P2M,   (30/3.0)*P2M,0,[],[],2),
		_make_card("加农炮", 61, 3, 1, Config.UnitType.BUILDING, 824, 202, 1000, 110*P2M, 0, Config.TargetType.GROUND_ONLY, 0, 1, 110*P2M, (45/3.0)*P2M),
		_make_card("哥布林投矛手", 62, 2, 3, Config.UnitType.GROUND, 133, 81, 1700, 100*P2M, 0, Config.TargetType.ALL, 2, 1, 110*P2M, (25/3.0)*P2M),
		_make_card("哥布林小屋", 63, 5, 1, Config.UnitType.BUILDING, 1228, 1, 2200, 120*P2M, 0, Config.TargetType.ALL, 0, 1, 120*P2M, (45/3.0)*P2M, 0, [], [62,1,100000], 1),
		_make_card("骷髅气球",       64, 3, 1,  Config.UnitType.AIR,    532,145,0,  10*P2M, 0.9,      Config.TargetType.BUILDING_ONLY, 1.6, 1, 100*P2M,  (50/3.0)*P2M,-1,[], [5,7,100000], 1),
		_make_card("骷髅守卫",        65, 3, 3,  Config.UnitType.GROUND,81,117,1000,   14*P2M, 0,      Config.TargetType.GROUND_ONLY, 1.6, 1, 50*P2M,  (20/3.0)*P2M, 256),
		_make_card("骷髅飞龙", 66, 4, 2, Config.UnitType.AIR, 560, 161, 2000, 70*P2M, 25*P2M, Config.TargetType.ALL, 1.6, 1, 80*P2M, (30/3.0)*P2M),
		_make_card("公主",       67, 3, 1,  Config.UnitType.GROUND, 261,168,3000,  180*P2M,   1.4,      Config.TargetType.ALL, 1.2, 1, 200*P2M,   (30/3.0)*P2M),
		_make_card("炸弹兵",     68, 2, 1,  Config.UnitType.GROUND, 304,225,1800,   90*P2M,  30*P2M, Config.TargetType.GROUND_ONLY, 1.2, 1, 5,         (20/3.0)*P2M),
		_make_card("野蛮人攻城槌",   69, 4, 1,  Config.UnitType.GROUND,967,286,100,     0.6,       0,      Config.TargetType.BUILDING_ONLY, 1.2, 2, 5,         (50/3.0)*P2M, -1, [], [57,2,100000], 1),
		_make_card("掘地矿工", 70, 3, 1, Config.UnitType.GROUND, 1210, 194, 1300, 10*P2M, 0*P2M, Config.TargetType.GROUND_ONLY, 1.6, 1, 70*P2M, (30/3.0)*P2M),
		_make_card("火枪手",     71, 4, 1,  Config.UnitType.GROUND, 721,217,1000,  120*P2M, 0,      Config.TargetType.ALL, 1.2, 1, 130*P2M,  (40/3.0)*P2M),
		_make_card("迫击炮",     72, 4, 1,  Config.UnitType.BUILDING, 1369,266,5000,  230*P2M, 20*P2M, Config.TargetType.GROUND_ONLY, 0, 1, 230*P2M,  (45/3.0)*P2M),
		_make_card("精灵女王",     73, 6, 1,  Config.UnitType.AIR, 1177,309,1400,  100*P2M,  0,      Config.TargetType.ALL, 1.2, 1, 60*P2M,   (40/3.0)*P2M),
		_make_card("皇家卫队", 74, 7, 6, Config.UnitType.GROUND, 537, 133, 1300, 15*P2M, 0, Config.TargetType.GROUND_ONLY, 1.1, 1, 60*P2M, (40/3.0)*P2M, 240),
		_make_card("狂战士",        75, 2, 1,  Config.UnitType.GROUND,896,102,600,   20*P2M, 0,      Config.TargetType.GROUND_ONLY, 1.6, 1, 40*P2M,  (20/3.0)*P2M),
		_make_card("三个火枪手", 76, 9, 3, Config.UnitType.GROUND, 883, 204, 1300, 120*P2M, 0, Config.TargetType.ALL, 1.2, 1, 130*P2M, (40/3.0)*P2M),
		_make_card("火箭",       77, 6, 1,  Config.UnitType.GROUND, 1,1484,0,  40*P2M,   40*P2M,      Config.TargetType.ALL, 0, 1, 0,   (40)*P2M),
		_make_card("狂暴法术",     78, 2, 1,  Config.UnitType.GROUND, 1,179,4500,   60*P2M,  60*P2M, Config.TargetType.ALL, 1.6, 1, 3,         (24/3.0)*P2M,0,[],[],9),
		_make_card("狂暴樵夫",   79, 4, 1,  Config.UnitType.GROUND,1282,256,800,     0.8,       0,      Config.TargetType.GROUND_ONLY, 2, 1, 2,         (30/3.0)*P2M),
		_make_card("冰冻法术",     80, 4, 1,  Config.UnitType.GROUND, 1,148,0,  60*P2M,  60*P2M, Config.TargetType.ALL, 1.2, 1, 100*P2M,   (30/3.0)*P2M,0,[],[],10),
		_make_card("幻影刺客",     81, 3, 1,  Config.UnitType.GROUND, 906,194,1000,  8*P2M, 0,      Config.TargetType.GROUND_ONLY, 1.6, 6, 110*P2M,  (45/3.0)*P2M),
		_make_card("熔岩猎犬",     82, 7, 1,  Config.UnitType.AIR, 3581,53,1300,  70*P2M, 0, Config.TargetType.BUILDING_ONLY, 0.8, 1, 110*P2M,  (25/3.0)*P2M, 0, [],[101,6,100000],  1),
		_make_card("超级骑士",     83, 7, 1,  Config.UnitType.GROUND, 3993,268,1700,  14*P2M,  1.2,      Config.TargetType.GROUND_ONLY, 1.2, 5, 120*P2M,   (50/3.0)*P2M, 0, [537,1.4,1,2,-1]),
		_make_card("哥布林机甲",       84, 5, 1,  Config.UnitType.GROUND,    2150,212,1200,  12*P2M, 0,      Config.TargetType.GROUND_ONLY, 1.2, 1, 60*P2M,  (50/3.0)*P2M, 0, [], [99,1,-1], 1),
		_make_card("骷髅召唤",        85, 5, 1,  Config.UnitType.GROUND,1,0,7000,   80*P2M, 0,      Config.TargetType.GROUND_ONLY, 1.6, 1, 50*P2M,  (20/3.0)*P2M),
		_make_card("蛮羊骑士", 86, 5, 1, Config.UnitType.GROUND, 1697, 250, 1800, 8*P2M, 0*P2M, Config.TargetType.BUILDING_ONLY, 1.2, 2, 120*P2M, (30/3.0)*P2M, 0, [], [98,1,-1], 1),
		_make_card("女巫婆婆",       87, 4, 1,  Config.UnitType.GROUND, 529,133,1000,  110*P2M,   0,      Config.TargetType.ALL, 1.2, 1, 200*P2M,   (30/3.0)*P2M,0,[],[],7),
		_make_card("凤凰",     88, 4, 1,  Config.UnitType.AIR, 1052,217,1000,   16*P2M,  0*P2M, Config.TargetType.ALL, 1.2, 1, 5,         (20/3.0)*P2M,0, [163,1.2,1,3,100],[102,1,100000]),
		_make_card("渔夫",   89, 3, 1,  Config.UnitType.GROUND,870,194,1300,     0.6,       0,      Config.TargetType.GROUND_ONLY, 1.2, 7, 5,         (50/3.0)*P2M),
		_make_card("皇家幽灵",     90, 3, 1,  Config.UnitType.GROUND, 1210,261,1800,  12*P2M,  14*P2M, Config.TargetType.GROUND_ONLY, 1.6, 1, 70*P2M,   (30/3.0)*P2M),
		_make_card("滚木",     91, 2, 1,  Config.UnitType.GROUND, 1,268,800,  202*P2M, 3.9,      Config.TargetType.GROUND_ONLY, 1.2, 1, 100*P2M,  (40/3.0)*P2M,0, [], [], 1, [], [0,1,20,10.1,5]),
		_make_card("戈仑石人",     92, 8, 1,  Config.UnitType.GROUND, 5120,312,2500,  8*P2M, 20*P2M, Config.TargetType.BUILDING_ONLY, 0.8, 1, 100*P2M,  (45/3.0)*P2M,0, [225,1.7,1,3,100],[100,2,100000]),
		_make_card("雷电巨人",     93, 7, 1,  Config.UnitType.GROUND, 3855,162,2100,  12*P2M,  0,      Config.TargetType.BUILDING_ONLY, 1.2, 1, 60*P2M,   (60/3.0)*P2M),
		_make_card("哥布林巨人",       94, 6, 1,   Config.UnitType.GROUND, 3020,176,1500,  8*P2M,  0,      Config.TargetType.BUILDING_ONLY, 1.1, 1, 120*P2M,   (40/3.0)*P2M, 0, [], [62,2,-1], 1),
		_make_card("加农炮战车", 95, 5, 1, Config.UnitType.GROUND, 1809, 212, 900, 110*P2M, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 120*P2M, (40/3.0)*P2M),
		_make_card("飞斧屠夫",         96, 5, 1,  Config.UnitType.GROUND, 1280,179,2400,   90*P2M,  1.5, Config.TargetType.ALL, 1.2, 1, 110*P2M,  (40/3.0)*P2M,0, [], [], 1, [], [0,1,80,7.5,4]),
		_make_card("巨石投手", 97, 5, 1, Config.UnitType.GROUND, 2081, 289, 2500, 80*P2M, 20*P2M, Config.TargetType.GROUND_ONLY, 0.8, 1, 5, (20)*P2M, 0, [], [], 1, [], [0,1,20,7.5,5]),
		_make_card("羊骑士",         98, 0, 1,  Config.UnitType.GROUND, 0,104,1100,   110*P2M,  0, Config.TargetType.ALL, 86, 4, 110*P2M,  (20/3.0)*P2M,0, [], [], 6),
		_make_card("炸药桶",       99, 0, 1,  Config.UnitType.GROUND, 0,304,3500,  75*P2M,   20*P2M,      Config.TargetType.ALL, 84, 4, 5,   (6)*P2M),
		_make_card("小戈仑石人",         100, 0, 1,  Config.UnitType.GROUND, 1039,84,2500,   8*P2M,  0, Config.TargetType.BUILDING_ONLY, 0.8, 1, 110*P2M,  (20/3.0)*P2M,0, [99,1.2,1,3,100]),
		_make_card("熔岩幼犬",         101, 0, 1,  Config.UnitType.AIR, 215,81,1700,   16*P2M,  0, Config.TargetType.ALL, 1.2, 1, 50*P2M,  (20/3.0)*P2M),
		_make_card("凤凰蛋",         102, 0, 1,  Config.UnitType.GROUND, 317,0,3800,   0*P2M,  0, Config.TargetType.ALL, 0, 1, 1000*P2M,  (20/3.0)*P2M, 0, [], [88,1,7300], 1),
		_make_card("小猪",         103, 0, 1,  Config.UnitType.GROUND, 629,53,1200,   8*P2M,  0, Config.TargetType.BUILDING_ONLY, 2, 1, 100*P2M,  (20/3.0)*P2M),
		_make_card("飓风法术",       104, 3, 1,  Config.UnitType.GROUND, 1, 30, 0, 2.5, 2.75, Config.TargetType.ALL, 0, 1, 2.5, 2.75, 0, [], [], 1),
		_make_card("哥布林爆破手",   105, 4, 1,  Config.UnitType.GROUND, 900, 180, 1200, 4.0, 1.0, Config.TargetType.GROUND_ONLY, 1.3, 1, 6.0, 1.0, 0, [], [], 1),
		_make_card("圣水戈仑",       106, 3, 1,  Config.UnitType.GROUND, 1400, 100, 1500, 0.5, 0, Config.TargetType.BUILDING_ONLY, 0.9, 1, 6.0, 1.2, 0, [], [100, 2, 100000], 1),
		_make_card("毒药法术",       107, 4, 1,  Config.UnitType.GROUND, 1, 55, 8000, 3.5, 3.5, Config.TargetType.ALL, 0, 1, 3.5, 3.5, 0, [], [], 7),
		_make_card("可疑草丛",       108, 2, 1,  Config.UnitType.GROUND, 700, 0, 0, 0, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 6.0, 0.8, 0, [], [62, 2, 100000], 1),
		_make_card("哥布林钻机",     109, 4, 1,  Config.UnitType.BUILDING, 900, 0, 0, 0, 0, Config.TargetType.ALL, 0, 1, 0, 1.0, 0, [], [62, 1, 3000], 1),
		_make_card("野蛮人滚桶",     110, 2, 1,  Config.UnitType.GROUND, 1, 260, 0, 2.5, 2.5, Config.TargetType.GROUND_ONLY, 0, 1, 2.5, 2.5, 0, [], [], 1),
		_make_card("符文巨人",       111, 4, 1,  Config.UnitType.GROUND, 1300, 110, 1800, 0.8, 0, Config.TargetType.BUILDING_ONLY, 1.0, 1, 6.0, 1.2, 0, [], [], 1),
		_make_card("藤蔓法术",       112, 3, 1,  Config.UnitType.GROUND, 1, 120, 0, 3.0, 3.0, Config.TargetType.ALL, 0, 1, 3.0, 3.0, 0, [], [], 2),
		_make_card("虚空法术",       113, 3, 1,  Config.UnitType.GROUND, 1, 350, 0, 2.0, 2.0, Config.TargetType.ALL, 0, 1, 2.0, 2.0, 0, [], [], 1),
		_make_card("哥布林牢笼",     114, 4, 1,  Config.UnitType.BUILDING, 1000, 0, 0, 0, 0, Config.TargetType.BUILDING_ONLY, 0, 1, 0, 1.0, 0, [], [62, 2, 100000], 1),
		_make_card("地震法术",       115, 3, 1,  Config.UnitType.GROUND, 1, 90, 3000, 2.5, 2.5, Config.TargetType.GROUND_ONLY, 0, 1, 2.5, 2.5, 0, [], [], 1),
		_make_card("哥布林魔咒",     116, 2, 1,  Config.UnitType.GROUND, 1, 60, 0, 3.0, 3.0, Config.TargetType.ALL, 0, 1, 3.0, 3.0, 0, [], [], 7),
		_make_card("绿林团伙",       117, 5, 1,  Config.UnitType.GROUND, 900, 120, 1400, 0.8, 0, Config.TargetType.GROUND_ONLY, 1.2, 1, 6.0, 1.0, 0, [], [118, 2, -1], 1),
		_make_card("绿林小妹",       118, 0, 1,  Config.UnitType.GROUND, 261,125,1000,  100*P2M,   0*P2M,      Config.TargetType.ALL, 1.2, 1, 5.5,   (20)*P2M),
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

func spawn_initial_towers():
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
	var king_level: int = PlayerData.get_tower_level()
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
	for data in tower_data:
		var slot: int = int(data[0])
		var type: int = int(data[1])
		var team: int = int(data[2])
		var pos: Vector3 = data[3]
		var cfg = get_config(type)
		if cfg == null:
			continue
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
	var now = Time.get_ticks_msec() - start_time
	if now >= 240000:
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


func network_ai_takeover(slot: int) -> void:
	if not remote_players.has(slot):
		return
	var rp: Dictionary = remote_players[slot]
	rp["ai"] = true
	remote_players[slot] = rp
	_ai_timers[slot] = randf_range(1.0, 2.5)

func _update_network_ai(delta: float) -> void:
	if not network_host_mode or network_countdown > 0.0:
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

func _check_timeout():
	if player_crowns != enemy_crowns:
		game_over = true
		winner = Config.Team.PLAYER if player_crowns > enemy_crowns else Config.Team.ENEMY
		_timeout_game_over()
	else:
		overtime = true

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
	# 测试模式：随机全卡（不受未解锁限制），等级由 battle_level 固定为 11
	if PlayerData.test_mode:
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
		level = Config.battle_level(level)
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
	var king_tower = get_king_tower(team)
	var start_pos = king_tower.global_position if king_tower else target_pos + Vector3(0, 10, 0)

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
	var kt = get_king_tower(team)
	var start: Vector3 = kt.global_position if kt else target_pos + Vector3(0, 0, 8.0)
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
	var path: Array = _miner_path(start, target_pos)
	_show_tunnel_path(start, path)
	_run_miner_tunnel(unit, start, path)

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
		level = Config.battle_level(level)
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
	var data := {
		"win": winner_team == local_team,
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

func _show_game_over() -> void:
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
	var win: bool = winner == Config.Team.PLAYER
	var trophy_change: int = 0
	if win:
		trophy_change = randi_range(25, 35)
		AudioManager.play_sfx(ProceduralAudio.get_sound("victory"))
	else:
		trophy_change = -randi_range(25, 35)
		AudioManager.play_sfx(ProceduralAudio.get_sound("defeat"))
	if win:
		var rand = randf()
		if rand < 0.7:
			PlayerData.add_chest("silver")
		elif rand < 0.95:
			PlayerData.add_chest("gold")
		else:
			PlayerData.add_chest("magical")
		_pending_chest_index = PlayerData.chests.size() - 1
	if trophy_change != 0:
		LeaderboardAPI.submit_trophies(PlayerData.trophies, PlayerData.player_name)
	PlayerData.add_trophies(trophy_change)
	var dur: String = "%d:%02d" % [int(game_time / 60000.0), int(game_time / 1000.0) % 60]
	var data := {
		"win": win,
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
		arr.append([cfg.card_name if cfg else str(cid), int(d[cid])])
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
	if player_crowns >= 3 or enemy_crowns >= 3:
		game_over = true
		winner = Config.Team.PLAYER if player_crowns > enemy_crowns else Config.Team.ENEMY

func on_king_destroyed(tower_team: int, world_pos: Vector3) -> void:
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
	level = Config.battle_level(level)
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
	level = Config.battle_level(level)
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
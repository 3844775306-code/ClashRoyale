# scripts/ui/ShopUI.gd
# 商店：4 件一排的橱窗（幸运宝箱 + 卡牌），纵向滚动
extends Control

const CARD_RARITY = preload("res://scripts/data/CardRarity.gd")
const REWARD_ICON = preload("res://scripts/ui/RewardIcon.gd")
const EMOTES = preload("res://scripts/data/EmoteCatalog.gd")
const EMOTE_ICON = preload("res://scripts/ui/EmoteIcon.gd")
const CHEST3D = preload("res://scripts/ui/Chest3DPreview.gd")

var currency_row: HBoxContainer
var card_grid: GridContainer
var card_tiles: Array = []
var chest_entries: Array = []
var emote_entries: Array = []
var status_lbl: Label
var _filter_mode: String = "all"
var _spell_ids: Array = []
var _cfg_by_id: Dictionary = {}
var _style_cache: Dictionary = {}
var _all_configs: Array = []

func _ready():
	_apply_text_theme()
	UiComponents.add_background(self)
	currency_row = UiComponents.make_header(self, "商店", _on_return_pressed, true)
	_all_configs = _get_configs()
	var scroll := UiComponents.make_content_scroll(self)
	var vbox := UiComponents.make_content_vbox()
	scroll.add_child(vbox)
	_build_banner(vbox)
	_build_chests(vbox)
	_build_cards(vbox)
	_refresh()
	UiComponents.fade_in(self)

func _apply_text_theme():
	var th := Theme.new()
	var f := load("res://assets/fonts/STZHONGS.TTF")
	if f:
		var fv := FontVariation.new()
		fv.base_font = f
		fv.variation_embolden = 0.7
		th.default_font = fv
	th.default_font_size = 16
	th.set_color("font_color", "Label", Color(0.98, 0.98, 0.95))
	th.set_color("font_outline_color", "Label", Color(0.04, 0.06, 0.10))
	th.set_constant("outline_size", "Label", 5)
	th.set_color("font_color", "Button", Color(0.99, 0.98, 0.92))
	th.set_color("font_outline_color", "Button", Color(0.04, 0.05, 0.08))
	th.set_constant("outline_size", "Button", 3)
	theme = th

func _build_banner(vbox: VBoxContainer):
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 108)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.16, 0.96)
	sb.border_color = Color(1.0, 0.72, 0.26)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(1.0, 0.60, 0.20, 0.25)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	vbox.add_child(p)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_top = 8
	v.offset_right = -18
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var t := Label.new()
	t.text = "🛒 今日商店"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	v.add_child(t)
	var s := Label.new()
	s.text = "4 件商品一排 · 今日卡牌含 1 件免费"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 14)
	s.add_theme_color_override("font_color", Color(0.76, 0.72, 0.92))
	v.add_child(s)
	status_lbl = Label.new()
	status_lbl.text = ""
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	v.add_child(status_lbl)

func _build_chests(vbox: VBoxContainer):
	vbox.add_child(UiComponents.make_section_title("🎁 幸运宝箱特惠"))
	var center := CenterContainer.new()
	vbox.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	for offer in _chest_offers():
		grid.add_child(_make_chest_card(offer))

func _chest_offers() -> Array:
	return [
		{"rarity": "silver", "name": "标准幸运宝箱 ★", "cost": 5, "desc": "普通卡 + 金币", "accent": Color(0.66, 0.80, 0.94), "handler": _on_buy_silver},
		{"rarity": "gold", "name": "标准幸运宝箱 ★★★", "cost": 20, "desc": "稀有卡 + 丰厚金币", "accent": Color(1.0, 0.78, 0.28), "handler": _on_buy_gold},
		{"rarity": "magical", "name": "魔法幸运宝箱 ★★★", "cost": 50, "desc": "史诗卡 + 海量奖励", "accent": Color(0.72, 0.44, 1.0), "handler": _on_buy_magical},
		{"rarity": "magical", "name": "魔法幸运宝箱 ★★★★★", "cost": 80, "desc": "高星奖励 + 传奇卡", "accent": Color(1.0, 0.84, 0.36), "handler": _on_buy_magical5},
	]

func _make_chest_card(offer: Dictionary) -> Panel:
	var accent: Color = offer.accent
	var p := Panel.new()
	p.custom_minimum_size = Vector2(168, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.085, 0.14, 0.97)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	sb.shadow_size = 6
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var icon = CHEST3D.new()
	icon.custom_minimum_size = Vector2(0, 112)
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.rarity = String(offer.rarity)
	v.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = offer.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", accent.lightened(0.2))
	v.add_child(name_lbl)
	var desc := Label.new()
	desc.text = offer.desc
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88))
	v.add_child(desc)
	var cost := Label.new()
	cost.text = "💎 %d" % int(offer.cost)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 18)
	cost.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	v.add_child(cost)
	var btn := _grad_button("购买", accent, Vector2(0, 40))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(offer.handler)
	v.add_child(btn)
	chest_entries.append({"btn": btn, "cost": int(offer.cost)})
	return p

func _build_cards(vbox: VBoxContainer):
	vbox.add_child(UiComponents.make_section_title("🃏 今日卡牌 · 8 件 · 每日 1 件免费"))
	_ensure_daily_offers()
	var center := CenterContainer.new()
	vbox.add_child(center)
	card_grid = GridContainer.new()
	card_grid.columns = 4
	card_grid.add_theme_constant_override("h_separation", 10)
	card_grid.add_theme_constant_override("v_separation", 10)
	center.add_child(card_grid)
	for i in range(PlayerData.shop_offers.size()):
		var offer: Dictionary = PlayerData.shop_offers[i]
		var cfg = _cfg_by_id.get(int(offer.card_id), null)
		if cfg == null:
			continue
		card_grid.add_child(_make_card_tile(cfg, offer, i))
	_build_emote_shop(vbox)
	_build_exchange(vbox)

func _build_emote_shop(vbox: VBoxContainer):
	vbox.add_child(UiComponents.make_section_title("表情商店"))
	var center := CenterContainer.new()
	vbox.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	var all: Array = EMOTES.all()
	for i in range(all.size()):
		var item: Dictionary = all[i]
		var cost: int = 100 + i * 25
		var owned: bool = PlayerData.owned_emotes.has(String(item.id))
		var p := Panel.new()
		p.custom_minimum_size = Vector2(168, 224)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.08, 0.14, 0.97)
		sb.border_color = Color(String(item.color))
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(13)
		p.add_theme_stylebox_override("panel", sb)
		grid.add_child(p)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 8
		v.offset_right = -8
		v.offset_top = 8
		v.offset_bottom = -8
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		var gl = EMOTE_ICON.new()
		gl.emote_id = String(item.id)
		gl.custom_minimum_size = Vector2(110, 110)
		gl.size = Vector2(110, 110)
		if not owned:
			gl.modulate = Color(0.45, 0.45, 0.50, 0.75)
		v.add_child(gl)
		var nm := Label.new()
		nm.text = String(item.name) if owned else "表情盲盒"
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 15)
		nm.add_theme_color_override("font_color", Color(String(item.color)))
		v.add_child(nm)
		var price := Label.new()
		price.text = "已拥有" if owned else "💎 %d" % cost
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.add_theme_font_size_override("font_size", 16)
		price.add_theme_color_override("font_color", Color(0.52, 0.86, 1.0))
		v.add_child(price)
		var btn := _grad_button("已拥有" if owned else "购买", Color(String(item.color)), Vector2(0, 40))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = owned
		var eid: String = String(item.id)
		var ecost: int = cost
		btn.pressed.connect(func(): _on_buy_emote(eid, ecost))
		v.add_child(btn)
		emote_entries.append({"btn": btn, "id": eid, "cost": cost, "owned": owned})

func _unit_price(card_id: int) -> int:
	match CARD_RARITY.rarity_of_id(card_id):
		"common": return 10
		"rare": return 50
		"epic": return 200
		"legendary": return 15000
	return 10

func _ensure_daily_offers():
	_cfg_by_id.clear()
	for cfg in _all_configs:
		if cfg.card_id >= 4 and cfg.cost > 0:
			_cfg_by_id[cfg.card_id] = cfg
	PlayerData.ensure_daily_shop_offers()

func _make_card_tile(cfg, offer: Dictionary, offer_index: int) -> Panel:
	var accent: Color = CARD_RARITY.rarity_color_by_id(cfg.card_id)
	var qty: int = int(offer.get("qty", 1))
	var unit: int = int(offer.get("unit", 10 + int(cfg.cost) * 5))
	var price: int = int(offer.get("price", unit * qty))
	var is_free: bool = bool(offer.get("free", false)) and price <= 0 and not bool(offer.get("sold", false))
	var p := Panel.new()
	p.custom_minimum_size = Vector2(168, 286)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.075, 0.12, 0.97)
	sb.border_color = Color(0.35, 0.95, 0.55) if is_free else accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(13)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	sb.shadow_size = 5
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 6
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var img_panel := Panel.new()
	img_panel.clip_contents = true
	img_panel.custom_minimum_size = Vector2(0, 154)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.14, 0.12, 0.20)
	isb.set_corner_radius_all(9)
	img_panel.add_theme_stylebox_override("panel", isb)
	v.add_child(img_panel)
	var path := "res://assets/cards_web/%s.png" % _safe(cfg.card_name)
	if not ResourceLoader.exists(path):
		path = "res://assets/cards_rendered/%s.png" % _safe(cfg.card_name)
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var bg_tr := TextureRect.new()
	bg_tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tr.stretch_mode = TextureRect.STRETCH_SCALE
	bg_tr.texture = tex
	bg_tr.modulate = Color(0.30, 0.30, 0.36)
	img_panel.add_child(bg_tr)
	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = tex
	img_panel.add_child(tr)
	var price_badge := Label.new()
	price_badge.text = "免费" if is_free else "🪙 %d/张" % unit
	price_badge.position = Vector2(5, 5)
	price_badge.add_theme_font_size_override("font_size", 13)
	price_badge.add_theme_color_override("font_color", Color(0.45, 1.0, 0.62) if is_free else Color(1.0, 0.86, 0.36))
	price_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	price_badge.add_theme_constant_override("outline_size", 3)
	img_panel.add_child(price_badge)
	var name_lbl := Label.new()
	name_lbl.text = cfg.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.97, 0.88))
	name_lbl.clip_text = true
	v.add_child(name_lbl)
	var total := Label.new()
	total.text = "免费领取 · ×%d张" % qty if is_free else "总价 🪙%d · ×%d张" % [price, qty]
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total.add_theme_font_size_override("font_size", 13)
	total.add_theme_color_override("font_color", Color(0.48, 1.0, 0.62) if is_free else Color(1.0, 0.82, 0.36))
	v.add_child(total)
	var owned := Label.new()
	owned.text = "已拥有 %d" % PlayerData.get_card_quantity(cfg.card_id)
	owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned.add_theme_font_size_override("font_size", 11)
	owned.add_theme_color_override("font_color", Color(0.66, 0.76, 0.88))
	v.add_child(owned)
	var btn := _grad_button("免费领取" if is_free else "购买 ×%d" % qty, Color(0.25, 0.82, 0.42) if is_free else accent, Vector2(0, 40))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): _on_buy_offer(offer_index))
	v.add_child(btn)
	card_tiles.append({"btn": btn, "price": price, "cfg": cfg, "owned": owned, "row": p, "offer": offer})
	_cfg_by_id[cfg.card_id] = cfg
	return p

func _build_exchange(vbox: VBoxContainer):
	vbox.add_child(UiComponents.make_section_title("💎 宝石兑换金币"))
	var center := CenterContainer.new()
	vbox.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	for item in [[10, 1000], [30, 3500], [60, 8000]]:
		var gems_cost: int = int(item[0])
		var gold_get: int = int(item[1])
		var p := Panel.new()
		p.custom_minimum_size = Vector2(224, 178)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.07, 0.15, 0.96)
		sb.border_color = Color(0.34, 0.78, 1.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		p.add_theme_stylebox_override("panel", sb)
		grid.add_child(p)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_right = -10
		v.offset_top = 8
		v.offset_bottom = -8
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		p.add_child(v)
		var t1 := Label.new()
		t1.text = "💎 %d → 🪙 %d" % [gems_cost, gold_get]
		t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t1.add_theme_font_size_override("font_size", 18)
		t1.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
		v.add_child(t1)
		var t2 := Label.new()
		t2.text = "兑换金币" 
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t2.add_theme_font_size_override("font_size", 12)
		t2.add_theme_color_override("font_color", Color(0.68, 0.76, 0.88))
		v.add_child(t2)
		var btn := _grad_button("兑换", Color(0.30, 0.70, 0.95), Vector2(0, 42))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_buy_gold_with_gems(gems_cost, gold_get))
		v.add_child(btn)
		chest_entries.append({"btn": btn, "cost": gems_cost, "kind": "gem_gold"})

func _refresh():
	UiComponents.refresh_currency_row(currency_row)
	for e in chest_entries:
		e.btn.disabled = PlayerData.gems < int(e.cost)
	for e in emote_entries:
		e.btn.disabled = bool(e.owned) or PlayerData.gems < int(e.cost)
	for e in card_tiles:
		var sold: bool = bool(e.offer.get("sold", false))
		e.btn.disabled = sold or PlayerData.gold < int(e.price)
		e.btn.text = "已售罄" if sold else ("免费领取" if bool(e.offer.get("free", false)) else "购买 ×%d" % int(e.offer.get("qty", 1)))
		e.owned.text = "已拥有 %d" % PlayerData.get_card_quantity(e.cfg.card_id)

func _on_buy_offer(offer_index: int):
	if offer_index < 0 or offer_index >= PlayerData.shop_offers.size():
		return
	var offer: Dictionary = PlayerData.shop_offers[offer_index]
	if bool(offer.get("sold", false)):
		return
	var price: int = int(offer.price)
	if PlayerData.gold < price:
		status_lbl.text = "金币不足"
		return
	var cfg = _cfg_by_id.get(int(offer.card_id), null)
	PlayerData.gold -= price
	PlayerData.add_card(int(offer.card_id), int(offer.qty))
	offer["sold"] = true
	PlayerData.shop_offers[offer_index] = offer
	PlayerData.save_data()
	if bool(offer.get("free", false)):
		status_lbl.text = "已免费领取 %s ×%d" % [cfg.card_name if cfg else "卡牌", int(offer.qty)]
	else:
		status_lbl.text = "已购买 %s ×%d" % [cfg.card_name if cfg else "卡牌", int(offer.qty)]
	_refresh()

func _on_buy_emote(id: String, cost: int):
	if PlayerData.owned_emotes.has(id):
		status_lbl.text = "已拥有该表情"
		return
	if PlayerData.gems < cost:
		status_lbl.text = "宝石不足"
		return
	PlayerData.gems -= cost
	PlayerData.add_emote(id)
	PlayerData.save_data()
	status_lbl.text = "已购买表情 %s" % EMOTES.name_of(id)
	for e in emote_entries:
		if String(e.id) == id:
			e.owned = true
			e.btn.text = "已拥有"
			e.btn.disabled = true
	_refresh()

func _on_buy_gold_with_gems(gems_cost: int, gold_get: int):
	if PlayerData.gems < gems_cost:
		status_lbl.text = "宝石不足"
		return
	PlayerData.gems -= gems_cost
	PlayerData.gold += gold_get
	PlayerData.save_data()
	status_lbl.text = "已兑换 %d 金币" % gold_get
	_refresh()

func _on_buy_silver():
	if PlayerData.gems < 5: return
	PlayerData.gems -= 5
	PlayerData.add_chest("silver")
	PlayerData.save_data()
	status_lbl.text = "已购买标准幸运宝箱"
	_refresh()

func _on_buy_gold():
	if PlayerData.gems < 20: return
	PlayerData.gems -= 20
	PlayerData.add_chest("gold")
	PlayerData.save_data()
	status_lbl.text = "已购买标准幸运宝箱 ★★★"
	_refresh()

func _on_buy_magical():
	if PlayerData.gems < 50: return
	PlayerData.gems -= 50
	PlayerData.add_chest("magical")
	PlayerData.save_data()
	status_lbl.text = "已购买魔法幸运宝箱"
	_refresh()

func _on_buy_magical5():
	if PlayerData.gems < 80: return
	PlayerData.gems -= 80
	PlayerData.add_chest("magical")
	var idx: int = PlayerData.chests.size() - 1
	PlayerData.chests[idx]["stars"] = 5
	PlayerData.save_data()
	status_lbl.text = "已购买魔法幸运宝箱 ★★★★★"
	_refresh()

func _get_configs() -> Array:
	var bm = get_tree().get_first_node_in_group("battle_manager")
	if not bm:
		bm = load("res://scripts/core/BattleManager.gd").new()
		bm.load_card_configs()
	_spell_ids = bm.SPELL_IDS.duplicate()
	return bm.configs

func _safe(n: String) -> String:
	return n.replace("/", "_").replace("\\", "_").replace(":", "_").replace("*", "_").replace("?", "_").replace("\"", "_").replace("<", "_").replace(">", "_").replace("|", "_")

func _grad_button(text: String, color: Color, size_px: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size_px
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", _gradient_style(color, "normal"))
	b.add_theme_stylebox_override("hover", _gradient_style(color, "hover"))
	b.add_theme_stylebox_override("pressed", _gradient_style(color, "pressed"))
	b.add_theme_color_override("font_color", Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06))
	b.add_theme_constant_override("outline_size", 3)
	return b

func _color_btn(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", _gradient_style(color, "normal"))
	b.add_theme_stylebox_override("hover", _gradient_style(color, "hover"))
	b.add_theme_stylebox_override("pressed", _gradient_style(color, "pressed"))

func _gradient_style(color: Color, state: String) -> StyleBoxTexture:
	var key: String = color.to_html() + state
	if _style_cache.has(key):
		return _style_cache[key]
	var c: Color = color
	if state == "hover": c = color.lightened(0.12)
	elif state == "pressed": c = color.darkened(0.16)
	var n: int = 40
	var r: int = 12
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(n):
		var ty: float = float(y) / float(n - 1)
		for x in range(n):
			var inside := true
			if x < r and y < r:
				inside = Vector2(r - x, r - y).length() <= float(r)
			elif x >= n - r and y < r:
				inside = Vector2(x - (n - r - 1), r - y).length() <= float(r)
			elif x < r and y >= n - r:
				inside = Vector2(r - x, y - (n - r - 1)).length() <= float(r)
			elif x >= n - r and y >= n - r:
				inside = Vector2(x - (n - r - 1), y - (n - r - 1)).length() <= float(r)
			if not inside:
				continue
			var col: Color = c.lightened(0.30 * (1.0 - ty)).darkened(0.32 * ty)
			if x < 2 or x >= n - 2 or y < 2 or y >= n - 2:
				col = col.lightened(0.22)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0))
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	sb.texture_margin_left = r
	sb.texture_margin_right = r
	sb.texture_margin_top = r
	sb.texture_margin_bottom = r
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_style_cache[key] = sb
	return sb

func _on_return_pressed():
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

extends RefCounted
class_name CardRarity

const RARITY := {"公主塔":"common","王子塔":"common","国王塔":"common","骑士":"common","骷髅军团":"epic","闪电法师":"legendary","法师":"rare","亡灵":"common","巨人":"rare","万箭齐发":"common","火球":"rare","瓦基丽武神":"rare","迷你皮卡":"rare","飞龙宝宝":"epic","皮卡超人":"epic","王子":"epic","野猪骑士":"rare","寒冰法师":"legendary","女巫":"epic","电击法术":"common","特斯拉电磁塔":"common","蝙蝠":"common","黑暗王子":"epic","骷髅墓碑":"rare","气球兵":"epic","炸弹塔":"rare","地狱飞龙":"legendary","电磁炮":"legendary","野蛮人精锐":"common","戈仑冰人":"rare","大雪球":"common","吹箭哥布林":"rare","地狱之塔":"rare","皇家巨人":"common","冰雪精灵":"common","雷电飞龙":"epic","暗夜女巫":"legendary","皇家野猪":"rare","哥布林":"common","哥布林飞桶":"epic","骷髅巨人":"epic","攻城炸弹人":"epic","烟花炮手":"common","弓箭手":"common","雷电精灵":"common","治疗精灵":"rare","战斗天使":"rare","雷电法术":"epic","野蛮人小屋":"rare","烈焰精灵":"common","烈焰熔炉":"rare","神箭游侠":"legendary","皇家速递":"common","飞行机器":"rare","十字连弩":"epic","猎人":"epic","野蛮人":"common","亡灵大军":"common","重甲亡灵":"rare","电击车小队":"rare","加农炮":"common","哥布林投矛手":"common","哥布林小屋":"rare","骷髅气球":"common","骷髅守卫":"epic","骷髅飞龙":"common","公主":"legendary","炸弹兵":"common","野蛮人攻城槌":"rare","掘地矿工":"legendary","火枪手":"rare","迫击炮":"common","精灵女王":"legendary","皇家卫队":"common","狂战士":"common","三个火枪手":"rare","火箭":"rare","狂暴法术":"epic","狂暴樵夫":"legendary","冰冻法术":"epic","幻影刺客":"legendary","熔岩猎犬":"legendary","超级骑士":"legendary","哥布林机甲":"legendary","骷髅召唤":"legendary","蛮羊骑士":"legendary","女巫婆婆":"legendary","凤凰":"legendary","渔夫":"legendary","皇家幽灵":"legendary","滚木":"legendary","戈仑石人":"epic","雷电巨人":"epic","哥布林巨人":"epic","加农炮战车":"epic","飞斧屠夫":"epic","巨石投手":"epic","羊骑士":"common","炸药桶":"common","小戈仑石人":"common","熔岩幼犬":"common","凤凰蛋":"common","小猪":"common","飓风法术":"epic","哥布林爆破手":"rare","圣水戈仑":"rare","毒药法术":"epic","可疑草丛":"rare","哥布林钻机":"epic","野蛮人滚桶":"epic","符文巨人":"epic","藤蔓法术":"epic","虚空法术":"epic","哥布林牢笼":"rare","地震法术":"rare","哥布林魔咒":"epic","绿林团伙":"common","绿林小妹":"common","骷髅兵":"common","圣水收集器":"rare","哥布林团伙":"common","克隆法术":"epic","镜像法术":"epic","圣水小戈仑":"common","圣水泡泡":"common","草丛哥布林":"common","哥布林硬汉":"common","亡灵巨人":"epic","浪人":"legendary"}

const RARITY_BY_ID := {"1":"common","2":"common","3":"common","4":"common","5":"epic","6":"legendary","7":"rare","8":"common","9":"rare","10":"common","11":"rare","12":"rare","13":"rare","14":"epic","15":"epic","16":"epic","17":"rare","18":"legendary","19":"epic","20":"common","21":"common","22":"common","23":"epic","24":"rare","25":"epic","26":"rare","27":"legendary","28":"legendary","29":"common","30":"rare","31":"common","32":"rare","33":"rare","34":"common","35":"common","36":"epic","37":"legendary","38":"rare","39":"common","40":"epic","41":"epic","42":"epic","43":"common","44":"common","45":"common","46":"rare","47":"rare","48":"epic","49":"rare","50":"common","51":"rare","52":"legendary","53":"common","54":"rare","55":"epic","56":"epic","57":"common","58":"common","59":"rare","60":"rare","61":"common","62":"common","63":"rare","64":"common","65":"epic","66":"common","67":"legendary","68":"common","69":"rare","70":"legendary","71":"rare","72":"common","73":"legendary","74":"common","75":"common","76":"rare","77":"rare","78":"epic","79":"legendary","80":"epic","81":"legendary","82":"legendary","83":"legendary","84":"legendary","85":"legendary","86":"legendary","87":"legendary","88":"legendary","89":"legendary","90":"legendary","91":"legendary","92":"epic","93":"epic","94":"epic","95":"epic","96":"epic","97":"epic","98":"common","99":"common","100":"common","101":"common","102":"common","103":"common","104":"epic","105":"rare","106":"rare","107":"epic","108":"rare","109":"epic","110":"epic","111":"epic","112":"epic","113":"epic","114":"rare","115":"rare","116":"epic","117":"common","118":"common","119":"common","120":"rare","121":"common","122":"epic","123":"epic","124":"common","125":"common","126":"common","127":"common","128":"epic","129":"legendary"}
const ARENA_UNLOCK := {"1":1,"2":1,"3":1,"4":1,"5":6,"6":11,"7":4,"8":1,"9":1,"10":1,"11":1,"12":2,"13":1,"14":6,"15":6,"16":7,"17":5,"18":12,"19":6,"20":5,"21":10,"22":5,"23":7,"24":2,"25":7,"26":4,"27":11,"28":11,"29":10,"30":8,"31":8,"32":9,"33":4,"34":7,"35":8,"36":12,"37":14,"38":7,"39":1,"40":6,"41":8,"42":12,"43":12,"44":1,"45":4,"46":13,"47":8,"48":8,"49":9,"50":4,"51":10,"52":13,"53":14,"54":1,"55":10,"56":10,"57":3,"58":10,"59":3,"60":10,"61":3,"62":1,"63":1,"64":9,"65":6,"66":4,"67":11,"68":2,"69":3,"70":11,"71":1,"72":5,"73":1,"74":7,"75":1,"76":7,"77":5,"78":14,"79":14,"80":8,"81":13,"82":13,"83":11,"84":1,"85":12,"86":11,"87":15,"88":12,"89":15,"90":12,"91":11,"92":10,"93":13,"94":9,"95":15,"96":14,"97":13,"98":1,"99":1,"100":1,"101":1,"102":1,"103":1,"104":15,"105":1,"106":14,"107":9,"108":1,"109":14,"110":9,"111":1,"112":1,"113":1,"114":1,"115":12,"116":1,"117":13,"118":1,"119":2,"120":15,"121":9,"122":15,"123":15,"124":1,"125":1,"126":1,"127":1,"128":1,"129":1}
const START_LEVEL := {"common":1,"rare":3,"epic":6,"legendary":9}

const COPY_COSTS := {
	"common": {2:2,3:4,4:10,5:20,6:50,7:100,8:200,9:400,10:800,11:1000,12:1500,13:2500,14:3500,15:5500,16:7500},
	"rare": {4:2,5:4,6:10,7:20,8:50,9:100,10:200,11:300,12:400,13:550,14:750,15:1000,16:1400},
	"epic": {7:2,8:4,9:10,10:20,11:30,12:50,13:70,14:100,15:130,16:180},
	"legendary": {10:2,11:4,12:6,13:9,14:12,15:14,16:20},
}

const GOLD_COSTS := {
	"common": {2:5,3:20,4:50,5:150,6:400,7:1000,8:2000,9:4000,10:8000,11:15000,12:25000,13:40000,14:60000,15:90000,16:120000},
	"rare": {4:50,5:150,6:400,7:1000,8:2000,9:4000,10:8000,11:15000,12:25000,13:40000,14:60000,15:90000,16:120000},
	"epic": {7:400,8:2000,9:4000,10:8000,11:15000,12:25000,13:40000,14:60000,15:90000,16:120000},
	"legendary": {10:5000,11:15000,12:25000,13:40000,14:60000,15:90000,16:120000},
}


static func rarity_of(name: String) -> String:
	return String(RARITY.get(name, "common"))

static func start_level(name: String) -> int:
	return int(START_LEVEL.get(rarity_of(name), 1))

static func copies_needed(name: String, target_level: int) -> int:
	return int(COPY_COSTS.get(rarity_of(name), {}).get(target_level, 0))

static func gold_needed(name: String, target_level: int) -> int:
	return int(GOLD_COSTS.get(rarity_of(name), {}).get(target_level, 0))

static func rarity_cn(name: String) -> String:
	match rarity_of(name):
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传奇"
	return "普通"

static func rarity_color(name: String) -> Color:
	match rarity_of(name):
		"common": return Color(0.74, 0.78, 0.84)
		"rare": return Color(0.96, 0.62, 0.22)
		"epic": return Color(0.72, 0.38, 0.95)
		"legendary": return Color(1.0, 0.80, 0.28)
	return Color(0.74, 0.78, 0.84)

static func rarity_of_id(id: int) -> String:
	return String(RARITY_BY_ID.get(str(id), "common"))

static func start_level_by_id(id: int) -> int:
	return int(START_LEVEL.get(rarity_of_id(id), 1))

static func copies_needed_by_id(id: int, target_level: int) -> int:
	return int(COPY_COSTS.get(rarity_of_id(id), {}).get(target_level, 0))

static func gold_needed_by_id(id: int, target_level: int) -> int:
	return int(GOLD_COSTS.get(rarity_of_id(id), {}).get(target_level, 0))

static func rarity_cn_by_id(id: int) -> String:
	return rarity_cn_by_id_impl(rarity_of_id(id))

static func rarity_cn_by_id_impl(r: String) -> String:
	match r:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传奇"
	return "普通"

static func rarity_color_by_id(id: int) -> Color:
	match rarity_of_id(id):
		"common": return Color(0.74, 0.78, 0.84)
		"rare": return Color(0.96, 0.62, 0.22)
		"epic": return Color(0.72, 0.38, 0.95)
		"legendary": return Color(1.0, 0.80, 0.28)
	return Color(0.74, 0.78, 0.84)

const LATE_NEW_CARD_ARENA := 3

static func arena_unlock_by_id(id: int) -> int:
	var v: int = int(ARENA_UNLOCK.get(str(id), 1))
	# 后期新增、但旧表误标为 1 阶的卡牌统一移到最低的、尚未配置新卡的竞技场（竞技场 3）
	if v == 1 and (id in [73, 74, 75, 84] or id >= 98):
		return LATE_NEW_CARD_ARENA
	return v

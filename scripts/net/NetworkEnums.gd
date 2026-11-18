# scripts/net/NetworkEnums.gd
class_name NetworkEnums
extends RefCounted

enum MessageType {
	CONNECT,            # 连接/创建/加入房间
	GAME_START,         # 游戏开始通知
	PLAYER_ACTION,      # 玩家操作 (放置卡牌)
	GAME_STATE_SYNC,    # 服务器 → 客户端同步游戏状态
	GAME_OVER,          # 游戏结束
	DISCONNECT,         # 玩家断开
	PING, PONG          # 心跳
}

enum Team { PLAYER = 0, ENEMY = 1 }

enum ActionType { PLACE_UNIT, USE_SPELL }

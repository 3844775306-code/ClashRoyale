# FCM 好友上线推送

## 需要你提供
1. Firebase 项目
2. Android 配置文件 `google-services.json`
3. Firebase 服务账号 JSON（只放 Supabase secrets，不要进 APK）

## Android 客户端
- 将 `google-services.json` 放到：
  - `android/build/google-services.json`
  - `android/build/build/google-services.json`（当前 Gradle 实际构建目录）
- 客户端会自动获取 FCM token，并写入 Supabase `push_token:<account_id>`。
- 未提供 Firebase 配置时，应用仍可用本地通知，不会崩溃。

## Supabase
```bash
supabase functions deploy friend-online-push
supabase secrets set FCM_SERVICE_ACCOUNT_JSON='<服务账号JSON>' PUSH_CRON_SECRET='<随机串>'
```
然后在 SQL Editor 执行 `cron.sql`（替换项目 ref、service role key），每分钟扫描一次好友上线。

## 触发逻辑
- 读取 `presence:` 在线状态
- 读取 `friends:<account_id>` 好友列表
- 读取 `push_token:<account_id>` FCM token
- 好友从离线变为在线时，通过 FCM HTTP v1 发通知
- `friend_online_state:<account_id>` 防止同一好友重复通知

## 说明
- 应用在前台时本地轮询也会发送「好友上线」通知。
- 应用被完全杀掉时依靠后端 cron + FCM 发送。

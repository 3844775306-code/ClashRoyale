// Supabase Edge Function: friend online FCM push
// Deploy: supabase functions deploy friend-online-push
// Required secrets: FCM_SERVICE_ACCOUNT_JSON (Firebase service account JSON)
// Schedule every minute: see cron.sql
//
// This function scans presence + friend lists + registered FCM tokens and sends
// one notification when a friend transitions offline -> online.
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-push-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const ONLINE_WINDOW = 45;
const BASE = Deno.env.get("SUPABASE_URL") ?? "";
const SR = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PUSH_SECRET = Deno.env.get("PUSH_CRON_SECRET") ?? "";
const FCM_SA = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";
const HEADERS = { apikey: SR, Authorization: `Bearer ${SR}`, "Content-Type": "application/json" };

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

function b64url(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function getMap(key: string): Promise<any> {
  const r = await fetch(`${BASE}/rest/v1/cr_data?key=eq.${encodeURIComponent(key)}&select=value`, { headers: HEADERS });
  if (!r.ok) return null;
  const arr = await r.json();
  return Array.isArray(arr) && arr.length > 0 ? arr[0].value : null;
}

async function putMap(key: string, value: unknown) {
  await fetch(`${BASE}/rest/v1/cr_data?on_conflict=key`, {
    method: "POST",
    headers: { ...HEADERS, Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify([{ key, value }]),
  });
}

async function listPrefix(prefix: string, limit = 500): Promise<any[]> {
  const r = await fetch(`${BASE}/rest/v1/cr_data?key=like.${encodeURIComponent(prefix)}*&select=key,value&limit=${limit}`, { headers: HEADERS });
  if (!r.ok) return [];
  const arr = await r.json();
  return Array.isArray(arr) ? arr : [];
}

let tokenCache: { token: string; exp: number } = { token: "", exp: 0 };

async function fcmAccessToken(): Promise<string> {
  if (!FCM_SA) throw new Error("FCM_SERVICE_ACCOUNT_JSON 未配置");
  if (tokenCache.token && Date.now() / 1000 < tokenCache.exp - 60) return tokenCache.token;
  const sa = JSON.parse(FCM_SA);
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const signInput = `${header}.${claims}`;
  const pem = String(sa.private_key ?? "")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signInput));
  const assertion = `${signInput}.${b64url(new Uint8Array(sig))}`;
  const tr = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const td = await tr.json();
  if (!tr.ok || !td.access_token) throw new Error(`FCM OAuth failed: ${JSON.stringify(td)}`);
  tokenCache = { token: td.access_token, exp: now + Number(td.expires_in ?? 3600) };
  return tokenCache.token;
}

async function sendFcm(token: string, title: string, body: string, data: Record<string, string>) {
  const sa = JSON.parse(FCM_SA);
  const access = await fcmAccessToken();
  const r = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: { priority: "high", notification: { channel_id: "clash_royale_messages" } },
      },
    }),
  });
  return { ok: r.ok, status: r.status, text: await r.text() };
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!BASE || !SR) return json({ ok: false, error: "Supabase 环境变量缺失" }, 500);
  const auth = req.headers.get("Authorization") ?? "";
  const secret = req.headers.get("x-push-secret") ?? "";
  const authorized = auth === `Bearer ${SR}` || (PUSH_SECRET !== "" && secret === PUSH_SECRET);
  if (!authorized) return json({ ok: false, error: "unauthorized" }, 401);
  if (!FCM_SA) return json({ ok: false, error: "FCM_SERVICE_ACCOUNT_JSON 未配置" }, 503);

  const now = Math.floor(Date.now() / 1000);
  const presenceRows = await listPrefix("presence:");
  const online = new Map<string, any>();
  for (const row of presenceRows) {
    const v = row.value ?? {};
    const pid = String(v.scoped_id ?? "");
    const seen = Number(v.last_seen ?? 0);
    if (pid && seen > 0 && now - seen <= ONLINE_WINDOW) online.set(pid, v);
  }

  const tokens = await listPrefix("push_token:");
  let pushed = 0;
  const errors: string[] = [];
  for (const row of tokens) {
    const accountId = String(row.key ?? "").replace("push_token:", "");
    const tv = row.value ?? {};
    const token = String(tv.token ?? "");
    if (!accountId || !token) continue;
    const friendCloud = await getMap(`friends:${accountId}`);
    const friends = Array.isArray(friendCloud?.friends) ? friendCloud.friends : [];
    if (friends.length === 0) continue;
    const stateKey = `friend_online_state:${accountId}`;
    const state = (await getMap(stateKey)) ?? {};
    let changed = false;
    for (const f of friends) {
      const fid = String(f?.id ?? "");
      if (!fid || fid === String(tv.scoped_id ?? "")) continue;
      const fv = online.get(fid);
      const wasOnline = !!state[fid];
      if (fv && !wasOnline) {
        const name = String(fv.name ?? f?.name ?? "好友");
        const res = await sendFcm(token, "好友上线", `${name} 上线了，快去找他玩吧`, {
          type: "friend_online", friend_id: fid, friend_name: name,
        });
        if (res.ok) pushed++;
        else errors.push(`${fid}:${res.status}:${res.text.slice(0, 120)}`);
        state[fid] = true;
        changed = true;
      } else if (!fv && wasOnline) {
        state[fid] = false;
        changed = true;
      }
    }
    if (changed) await putMap(stateKey, state);
  }
  return json({ ok: true, pushed, online: online.size, tokens: tokens.length, errors });
});

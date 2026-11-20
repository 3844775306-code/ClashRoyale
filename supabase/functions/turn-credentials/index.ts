const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, error: "Method not allowed" }, 405);
  const base = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
  if (!token) return json({ ok: false, error: "未登录" }, 401);
  if (!base || !anon) return json({ ok: false, error: "Supabase 环境变量缺失" }, 500);

  try {
    const ur = await fetch(`${base}/auth/v1/user`, {
      headers: { apikey: anon, Authorization: `Bearer ${token}` },
    });
    const user = await ur.json();
    if (!ur.ok || !user?.id) return json({ ok: false, error: "登录状态无效" }, 401);

    const keyId = Deno.env.get("CF_TURN_KEY_ID") ?? "";
    const apiToken = Deno.env.get("CF_TURN_API_TOKEN") ?? "";
    if (!keyId || !apiToken) {
      return json({ ok: false, error: "未配置 Cloudflare TURN Key" }, 500);
    }
    let ttl = Number((await req.json().catch(() => ({})))?.ttl ?? 3600);
    ttl = Math.max(300, Math.min(86400, ttl));

    const cr = await fetch(
      `https://rtc.live.cloudflare.com/v1/turn/keys/${encodeURIComponent(keyId)}/credentials/generate-ice-servers`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ ttl }),
      },
    );
    const data = await cr.json().catch(() => ({}));
    if (!cr.ok) {
      return json({ ok: false, error: String(data?.error ?? data?.message ?? "Cloudflare TURN 生成失败") }, 502);
    }
    return json({
      ok: true,
      iceServers: data?.iceServers ?? [],
      expires_at: Math.floor(Date.now() / 1000) + ttl,
    });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});

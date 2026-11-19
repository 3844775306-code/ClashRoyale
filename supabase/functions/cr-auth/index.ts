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
function normUsername(raw: unknown) {
  const u = String(raw ?? "").trim();
  return /^[\p{L}\p{N}_]{2,20}$/u.test(u) ? u : "";
}
async function sha256Hex(text: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function putMap(base: string, sr: string, key: string, value: unknown) {
  await fetch(`${base}/rest/v1/cr_data?on_conflict=key`, {
    method: "POST",
    headers: { apikey: sr, Authorization: `Bearer ${sr}`, "Content-Type": "application/json", Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify([{ key, value }]),
  });
}
async function getMap(base: string, sr: string, key: string) {
  const r = await fetch(`${base}/rest/v1/cr_data?key=eq.${encodeURIComponent(key)}&select=value`, { headers: { apikey: sr, Authorization: `Bearer ${sr}` } });
  const arr = await r.json();
  return Array.isArray(arr) && arr.length > 0 ? arr[0].value : null;
}
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const base = Deno.env.get("SUPABASE_URL") ?? "";
  const sr = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const adminHeaders = { apikey: sr, Authorization: `Bearer ${sr}`, "Content-Type": "application/json" };
  try {
    const body = await req.json();
    const action = String(body.action ?? "");
    if (action === "signup") {
      const username = normUsername(body.username);
      const password = String(body.password ?? "");
      if (!username) return json({ ok: false, error: "用户名需 2-20 位中英文、数字或下划线" }, 400);
      if (password.length < 6) return json({ ok: false, error: "密码至少 6 位" }, 400);
      const key = username.toLowerCase();
      const email = `u_${await sha256Hex(key)}@login.clashroyale.local`;
      const r = await fetch(`${base}/auth/v1/admin/users`, {
        method: "POST", headers: adminHeaders,
        body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { username, username_key: key } }),
      });
      const data = await r.json();
      if (!r.ok) return json({ ok: false, error: data.msg ?? data.message ?? "创建账号失败" }, 400);
      await putMap(base, sr, `username:${await sha256Hex(key)}`, { username, username_key: key, email, user_id: data.id ?? "" });
      return json({ ok: true, user_id: data.id ?? "", email });
    }
    if (action === "claim-bind-reward") {
      const auth = req.headers.get("Authorization") ?? "";
      const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
      if (!token) return json({ ok: false, error: "未登录" }, 401);
      const ur = await fetch(`${base}/auth/v1/user`, { headers: { apikey: sr, Authorization: `Bearer ${token}` } });
      const user = await ur.json();
      if (!ur.ok || !user.id) return json({ ok: false, error: "会话无效" }, 401);
      const email = String(user.email ?? "");
      if (email.endsWith("@login.clashroyale.local")) return json({ ok: false, error: "尚未绑定真实邮箱" }, 400);
      if (!user.email_confirmed_at) return json({ ok: false, error: "邮箱尚未确认" }, 400);
      const meta = user.user_metadata ?? {};
      if (meta.bind_reward_claimed) return json({ ok: true, already: true });
      const r = await fetch(`${base}/auth/v1/admin/users/${user.id}`, {
        method: "PUT", headers: adminHeaders,
        body: JSON.stringify({ user_metadata: { ...meta, email_bound: true, bind_reward_claimed: true, bound_email: email } }),
      });
      if (!r.ok) { const d = await r.json(); return json({ ok: false, error: d.msg ?? d.message ?? "绑定奖励失败" }, 400); }
      return json({ ok: true, already: false });
    }
    if (action === "resolve") {
      const key0 = normUsername(body.username);
      if (!key0) return json({ ok: false, error: "用户名格式错误" }, 400);
      const v = await getMap(base, sr, `username:${await sha256Hex(key0.toLowerCase())}`);
      return json({ ok: true, email: v?.email ?? `u_${await sha256Hex(key0.toLowerCase())}@login.clashroyale.local` });
    }
    if (action === "sync-email") {
      const auth = req.headers.get("Authorization") ?? "";
      const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
      const ur = await fetch(`${base}/auth/v1/user`, { headers: { apikey: sr, Authorization: `Bearer ${token}` } });
      const user = await ur.json();
      if (!ur.ok || !user.id) return json({ ok: false, error: "会话无效" }, 401);
      const meta = user.user_metadata ?? {};
      const uname = String(meta.username ?? "");
      if (uname) await putMap(base, sr, `username:${await sha256Hex(uname.toLowerCase())}`, { username: uname, username_key: uname.toLowerCase(), email: user.email, user_id: user.id });
      return json({ ok: true });
    }
    return json({ ok: false, error: "unknown action" }, 400);
  } catch (e) {
    return json({ ok: false, error: String(e) }, 500);
  }
});
